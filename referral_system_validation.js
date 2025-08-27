#!/usr/bin/env node

/**
 * TALOWA Referral System Validation Script
 * 
 * Tests the 5-minute smoke test scenarios from the specification:
 * 1. Code reservation (idempotency)
 * 2. Apply referral (happy path)
 * 3. Duplicate apply (idempotency)
 * 4. Self-referral block
 * 5. Client write hardening
 */

const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = getAuth();

// Test configuration
const TEST_CONFIG = {
  projectId: process.env.FIREBASE_PROJECT_ID || 'talowa-app',
  region: 'us-central1',
  testUsers: {
    userA: {
      email: 'test-user-a@talowa.test',
      phone: '+919876543210',
      uid: null,
      token: null,
      referralCode: null
    },
    userB: {
      email: 'test-user-b@talowa.test', 
      phone: '+919876543211',
      uid: null,
      token: null
    }
  }
};

class ReferralSystemValidator {
  constructor() {
    this.results = {
      passed: 0,
      failed: 0,
      tests: []
    };
  }

  async log(message, type = 'info') {
    const timestamp = new Date().toISOString();
    const prefix = type === 'pass' ? '✅' : type === 'fail' ? '❌' : type === 'warn' ? '⚠️' : 'ℹ️';
    console.log(`${prefix} [${timestamp}] ${message}`);
  }

  async test(name, testFn) {
    try {
      await this.log(`Starting test: ${name}`);
      await testFn();
      this.results.passed++;
      this.results.tests.push({ name, status: 'PASS' });
      await this.log(`Test passed: ${name}`, 'pass');
    } catch (error) {
      this.results.failed++;
      this.results.tests.push({ name, status: 'FAIL', error: error.message });
      await this.log(`Test failed: ${name} - ${error.message}`, 'fail');
    }
  }

  async createTestUser(userKey) {
    const user = TEST_CONFIG.testUsers[userKey];
    
    try {
      // Try to get existing user first
      const existingUser = await auth.getUserByEmail(user.email);
      user.uid = existingUser.uid;
      await this.log(`Using existing test user: ${userKey} (${user.uid})`);
    } catch (error) {
      // Create new user
      const userRecord = await auth.createUser({
        email: user.email,
        phoneNumber: user.phone,
        emailVerified: true,
        disabled: false
      });
      user.uid = userRecord.uid;
      await this.log(`Created test user: ${userKey} (${user.uid})`);
    }

    // Generate custom token
    user.token = await auth.createCustomToken(user.uid);
    return user;
  }

  async callCloudFunction(functionName, data = {}, userToken = null) {
    const { getFunctions } = require('firebase-admin/functions');
    const functions = getFunctions();
    
    // Simulate authenticated call
    const context = {
      auth: userToken ? { uid: userToken.uid } : null
    };
    
    // This is a simplified simulation - in real testing you'd use the Firebase SDK
    // to make actual HTTP calls to the deployed functions
    throw new Error('Cloud Function testing requires Firebase SDK client setup');
  }

  async testCodeReservationIdempotency() {
    const userA = await this.createTestUser('userA');
    
    // Call reserveReferralCode twice
    const result1 = await this.callCloudFunction('reserveReferralCode', {}, userA);
    const result2 = await this.callCloudFunction('reserveReferralCode', {}, userA);
    
    if (result1.code !== result2.code) {
      throw new Error('Code reservation not idempotent - got different codes');
    }
    
    // Verify in Firestore
    const codeDoc = await db.collection('referralCodes').doc(result1.code).get();
    if (!codeDoc.exists || codeDoc.data().uid !== userA.uid) {
      throw new Error('Code not properly stored in Firestore');
    }
    
    const userDoc = await db.collection('users').doc(userA.uid).get();
    if (!userDoc.exists || userDoc.data().referral?.code !== result1.code) {
      throw new Error('Code not properly stored in user document');
    }
    
    userA.referralCode = result1.code;
  }

  async testApplyReferralHappyPath() {
    const userA = TEST_CONFIG.testUsers.userA;
    const userB = await this.createTestUser('userB');
    
    if (!userA.referralCode) {
      throw new Error('User A must have a referral code first');
    }
    
    // Apply referral code
    const result = await this.callCloudFunction('applyReferralCode', {
      code: userA.referralCode
    }, userB);
    
    if (result.referrerUid !== userA.uid) {
      throw new Error('Incorrect referrer UID returned');
    }
    
    // Verify Firestore updates
    const userBDoc = await db.collection('users').doc(userB.uid).get();
    if (userBDoc.data().referral?.referredBy !== userA.uid) {
      throw new Error('User B referredBy not set correctly');
    }
    
    const referralDoc = await db.collection('referrals').doc(userA.uid)
      .collection('direct').doc(userB.uid).get();
    if (!referralDoc.exists) {
      throw new Error('Direct referral document not created');
    }
    
    const userADoc = await db.collection('users').doc(userA.uid).get();
    const directCount = userADoc.data().referral?.directCount || 0;
    if (directCount < 1) {
      throw new Error('User A direct count not incremented');
    }
  }

  async testDuplicateApplyIdempotency() {
    const userA = TEST_CONFIG.testUsers.userA;
    const userB = TEST_CONFIG.testUsers.userB;
    
    // Get initial state
    const initialUserADoc = await db.collection('users').doc(userA.uid).get();
    const initialDirectCount = initialUserADoc.data().referral?.directCount || 0;
    
    // Apply referral code again
    const result = await this.callCloudFunction('applyReferralCode', {
      code: userA.referralCode
    }, userB);
    
    if (result.referrerUid !== userA.uid) {
      throw new Error('Incorrect referrer UID on duplicate apply');
    }
    
    // Verify no duplicate increments
    const finalUserADoc = await db.collection('users').doc(userA.uid).get();
    const finalDirectCount = finalUserADoc.data().referral?.directCount || 0;
    
    if (finalDirectCount !== initialDirectCount) {
      throw new Error('Direct count incremented on duplicate apply');
    }
  }

  async testSelfReferralBlock() {
    const userA = TEST_CONFIG.testUsers.userA;
    
    try {
      await this.callCloudFunction('applyReferralCode', {
        code: userA.referralCode
      }, userA);
      
      throw new Error('Self-referral should have been blocked');
    } catch (error) {
      if (!error.message.includes('self-referral') && !error.message.includes('permission')) {
        throw new Error(`Expected self-referral error, got: ${error.message}`);
      }
    }
  }

  async testClientWriteHardening() {
    const userA = TEST_CONFIG.testUsers.userA;
    
    try {
      // Try to write referral data directly
      await db.collection('users').doc(userA.uid).set({
        referral: {
          referredBy: 'fake-uid'
        }
      }, { merge: true });
      
      throw new Error('Client write to referral field should have been blocked');
    } catch (error) {
      if (error.code !== 'permission-denied') {
        throw new Error(`Expected permission-denied, got: ${error.code}`);
      }
    }
    
    try {
      // Try to write to referralCodes collection
      await db.collection('referralCodes').doc('TALFAKE123').set({
        uid: userA.uid,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      throw new Error('Client write to referralCodes should have been blocked');
    } catch (error) {
      if (error.code !== 'permission-denied') {
        throw new Error(`Expected permission-denied, got: ${error.code}`);
      }
    }
  }

  async cleanup() {
    await this.log('Cleaning up test users...');
    
    for (const [key, user] of Object.entries(TEST_CONFIG.testUsers)) {
      if (user.uid) {
        try {
          await auth.deleteUser(user.uid);
          await this.log(`Deleted test user: ${key}`);
        } catch (error) {
          await this.log(`Failed to delete test user ${key}: ${error.message}`, 'warn');
        }
      }
    }
  }

  async run() {
    await this.log('🚀 Starting TALOWA Referral System Validation');
    await this.log(`Project: ${TEST_CONFIG.projectId}`);
    await this.log(`Region: ${TEST_CONFIG.region}`);
    
    try {
      await this.test('Code Reservation Idempotency', () => this.testCodeReservationIdempotency());
      await this.test('Apply Referral Happy Path', () => this.testApplyReferralHappyPath());
      await this.test('Duplicate Apply Idempotency', () => this.testDuplicateApplyIdempotency());
      await this.test('Self-Referral Block', () => this.testSelfReferralBlock());
      await this.test('Client Write Hardening', () => this.testClientWriteHardening());
      
    } finally {
      await this.cleanup();
    }
    
    // Print results
    console.log('\n📊 Test Results:');
    console.log(`✅ Passed: ${this.results.passed}`);
    console.log(`❌ Failed: ${this.results.failed}`);
    console.log(`📋 Total: ${this.results.tests.length}`);
    
    if (this.results.failed > 0) {
      console.log('\n❌ Failed Tests:');
      this.results.tests
        .filter(t => t.status === 'FAIL')
        .forEach(t => console.log(`  - ${t.name}: ${t.error}`));
    }
    
    const success = this.results.failed === 0;
    console.log(`\n🎯 Overall Result: ${success ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED'}`);
    
    return success;
  }
}

// Run validation if called directly
if (require.main === module) {
  const validator = new ReferralSystemValidator();
  validator.run().then(success => {
    process.exit(success ? 0 : 1);
  }).catch(error => {
    console.error('💥 Validation crashed:', error);
    process.exit(1);
  });
}

module.exports = ReferralSystemValidator;