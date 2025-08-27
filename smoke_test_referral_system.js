#!/usr/bin/env node

/**
 * 🧪 TALOWA Referral System - 5-Minute Smoke Tests
 * 
 * This script tests the core referral functionality to ensure:
 * 1. Code reservation (idempotency)
 * 2. Apply referral (happy path)
 * 3. Duplicate apply (idempotency)
 * 4. Self-referral block
 * 5. Client write hardening
 */

const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

// Initialize Firebase Admin (requires service account key)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    // Or use service account: admin.credential.cert(require('./path/to/serviceAccountKey.json'))
  });
}

const auth = getAuth();
const db = getFirestore();

// Test configuration
const TEST_CONFIG = {
  projectId: process.env.FIREBASE_PROJECT_ID || 'your-project-id',
  region: 'us-central1', // Adjust to your functions region
  testUsers: {
    userA: {
      email: 'test-user-a@example.com',
      password: 'testpass123',
      uid: null,
      idToken: null,
      referralCode: null
    },
    userB: {
      email: 'test-user-b@example.com', 
      password: 'testpass123',
      uid: null,
      idToken: null
    }
  }
};

// Utility functions
async function createTestUser(userKey) {
  const user = TEST_CONFIG.testUsers[userKey];
  
  try {
    // Create user in Firebase Auth
    const userRecord = await auth.createUser({
      email: user.email,
      password: user.password,
      emailVerified: true
    });
    
    user.uid = userRecord.uid;
    
    // Create custom token for testing
    const customToken = await auth.createCustomToken(user.uid);
    
    console.log(`✅ Created test user ${userKey}: ${user.uid}`);
    return { uid: user.uid, customToken };
    
  } catch (error) {
    if (error.code === 'auth/email-already-exists') {
      // User exists, get UID
      const userRecord = await auth.getUserByEmail(user.email);
      user.uid = userRecord.uid;
      const customToken = await auth.createCustomToken(user.uid);
      console.log(`♻️  Using existing test user ${userKey}: ${user.uid}`);
      return { uid: user.uid, customToken };
    }
    throw error;
  }
}

async function callCloudFunction(functionName, data, idToken) {
  const fetch = require('node-fetch');
  
  const url = `https://${TEST_CONFIG.region}-${TEST_CONFIG.projectId}.cloudfunctions.net/${functionName}`;
  
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${idToken}`
    },
    body: JSON.stringify({ data })
  });
  
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`HTTP ${response.status}: ${errorText}`);
  }
  
  return await response.json();
}

async function cleanupTestData() {
  console.log('🧹 Cleaning up test data...');
  
  try {
    // Delete test users
    for (const [userKey, user] of Object.entries(TEST_CONFIG.testUsers)) {
      if (user.uid) {
        try {
          await auth.deleteUser(user.uid);
          console.log(`🗑️  Deleted test user ${userKey}`);
        } catch (error) {
          console.log(`⚠️  Could not delete user ${userKey}: ${error.message}`);
        }
      }
    }
    
    // Clean up Firestore test data
    const batch = db.batch();
    
    // Delete referral codes created during tests
    const codesQuery = await db.collection('referralCodes')
      .where('uid', 'in', Object.values(TEST_CONFIG.testUsers).map(u => u.uid).filter(Boolean))
      .get();
    
    codesQuery.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // Delete user documents
    Object.values(TEST_CONFIG.testUsers).forEach(user => {
      if (user.uid) {
        batch.delete(db.collection('users').doc(user.uid));
      }
    });
    
    await batch.commit();
    console.log('✅ Test data cleanup completed');
    
  } catch (error) {
    console.log(`⚠️  Cleanup error: ${error.message}`);
  }
}

// Test functions
async function test1_CodeReservation() {
  console.log('\n📋 Test 1: Code Reservation (Idempotency)');
  console.log('==========================================');
  
  const userA = TEST_CONFIG.testUsers.userA;
  
  try {
    // First call - should generate new code
    console.log('  📝 First reserveReferralCode call...');
    const result1 = await callCloudFunction('reserveReferralCode', {}, userA.idToken);
    
    if (!result1.result || !result1.result.code) {
      throw new Error('No code returned from first call');
    }
    
    const code1 = result1.result.code;
    userA.referralCode = code1;
    console.log(`  ✅ First call returned: ${code1}`);
    
    // Validate code format
    if (!/^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{7,8}$/.test(code1)) {
      throw new Error(`Invalid code format: ${code1}`);
    }
    
    // Second call - should return same code (idempotency)
    console.log('  🔄 Second reserveReferralCode call...');
    const result2 = await callCloudFunction('reserveReferralCode', {}, userA.idToken);
    
    const code2 = result2.result.code;
    console.log(`  ✅ Second call returned: ${code2}`);
    
    if (code1 !== code2) {
      throw new Error(`Idempotency failed: ${code1} !== ${code2}`);
    }
    
    // Verify Firestore state
    const codeDoc = await db.collection('referralCodes').doc(code1).get();
    if (!codeDoc.exists) {
      throw new Error(`Code document not found: ${code1}`);
    }
    
    const codeData = codeDoc.data();
    if (codeData.uid !== userA.uid || !codeData.active) {
      throw new Error(`Invalid code document data: ${JSON.stringify(codeData)}`);
    }
    
    const userDoc = await db.collection('users').doc(userA.uid).get();
    if (!userDoc.exists) {
      throw new Error(`User document not found: ${userA.uid}`);
    }
    
    const userData = userDoc.data();
    if (userData.referral?.code !== code1) {
      throw new Error(`User referral code mismatch: ${userData.referral?.code} !== ${code1}`);
    }
    
    console.log('  ✅ Test 1 PASSED: Code reservation is idempotent');
    
  } catch (error) {
    console.log(`  ❌ Test 1 FAILED: ${error.message}`);
    throw error;
  }
}

async function test2_ApplyReferral() {
  console.log('\n🎯 Test 2: Apply Referral (Happy Path)');
  console.log('=====================================');
  
  const userA = TEST_CONFIG.testUsers.userA;
  const userB = TEST_CONFIG.testUsers.userB;
  
  try {
    console.log(`  📝 Applying referral code ${userA.referralCode} for user B...`);
    
    const result = await callCloudFunction('applyReferralCode', {
      code: userA.referralCode
    }, userB.idToken);
    
    if (!result.result || result.result.referrerUid !== userA.uid) {
      throw new Error(`Invalid apply result: ${JSON.stringify(result)}`);
    }
    
    console.log(`  ✅ Apply successful, referrer: ${result.result.referrerUid}`);
    
    // Verify Firestore updates
    const userBDoc = await db.collection('users').doc(userB.uid).get();
    const userBData = userBDoc.data();
    
    if (userBData.referral?.referredBy !== userA.uid) {
      throw new Error(`User B referredBy not set: ${userBData.referral?.referredBy}`);
    }
    
    if (userBData.referral?.referredByCode !== userA.referralCode) {
      throw new Error(`User B referredByCode not set: ${userBData.referral?.referredByCode}`);
    }
    
    // Check referral relationship document
    const referralDoc = await db.collection('referrals').doc(userA.uid)
      .collection('direct').doc(userB.uid).get();
    
    if (!referralDoc.exists) {
      throw new Error('Referral relationship document not created');
    }
    
    const referralData = referralDoc.data();
    if (referralData.fromCode !== userA.referralCode) {
      throw new Error(`Referral fromCode mismatch: ${referralData.fromCode}`);
    }
    
    // Check referrer's direct count increment
    const userADoc = await db.collection('users').doc(userA.uid).get();
    const userAData = userADoc.data();
    
    if (userAData.referral?.directCount !== 1) {
      throw new Error(`User A directCount not incremented: ${userAData.referral?.directCount}`);
    }
    
    console.log('  ✅ Test 2 PASSED: Referral application works correctly');
    
  } catch (error) {
    console.log(`  ❌ Test 2 FAILED: ${error.message}`);
    throw error;
  }
}

async function test3_DuplicateApply() {
  console.log('\n🔄 Test 3: Duplicate Apply (Idempotency)');
  console.log('========================================');
  
  const userA = TEST_CONFIG.testUsers.userA;
  const userB = TEST_CONFIG.testUsers.userB;
  
  try {
    console.log(`  🔄 Applying same referral code again...`);
    
    const result = await callCloudFunction('applyReferralCode', {
      code: userA.referralCode
    }, userB.idToken);
    
    if (!result.result || result.result.referrerUid !== userA.uid) {
      throw new Error(`Duplicate apply failed: ${JSON.stringify(result)}`);
    }
    
    console.log(`  ✅ Duplicate apply successful (idempotent)`);
    
    // Verify no duplicate increment
    const userADoc = await db.collection('users').doc(userA.uid).get();
    const userAData = userADoc.data();
    
    if (userAData.referral?.directCount !== 1) {
      throw new Error(`DirectCount incorrectly incremented: ${userAData.referral?.directCount}`);
    }
    
    console.log('  ✅ Test 3 PASSED: Duplicate apply is idempotent');
    
  } catch (error) {
    console.log(`  ❌ Test 3 FAILED: ${error.message}`);
    throw error;
  }
}

async function test4_SelfReferralBlock() {
  console.log('\n🚫 Test 4: Self-Referral Block');
  console.log('==============================');
  
  const userA = TEST_CONFIG.testUsers.userA;
  
  try {
    console.log(`  🚫 Attempting self-referral...`);
    
    try {
      const result = await callCloudFunction('applyReferralCode', {
        code: userA.referralCode
      }, userA.idToken);
      
      // Should not reach here
      throw new Error(`Self-referral was not blocked: ${JSON.stringify(result)}`);
      
    } catch (error) {
      if (error.message.includes('SELF_REFERRAL_NOT_ALLOWED') || 
          error.message.includes('400') || 
          error.message.includes('403')) {
        console.log(`  ✅ Self-referral correctly blocked: ${error.message}`);
      } else {
        throw new Error(`Unexpected error: ${error.message}`);
      }
    }
    
    console.log('  ✅ Test 4 PASSED: Self-referrals are blocked');
    
  } catch (error) {
    console.log(`  ❌ Test 4 FAILED: ${error.message}`);
    throw error;
  }
}

async function test5_ClientWriteHardening() {
  console.log('\n🔐 Test 5: Client Write Hardening');
  console.log('=================================');
  
  const userA = TEST_CONFIG.testUsers.userA;
  
  try {
    console.log(`  🔐 Attempting direct client write to referral field...`);
    
    try {
      await db.collection('users').doc(userA.uid).set({
        referral: {
          referredBy: 'fake-uid',
          directCount: 999
        }
      }, { merge: true });
      
      // Should not reach here
      throw new Error('Client write was not blocked by security rules');
      
    } catch (error) {
      if (error.code === 'permission-denied' || error.message.includes('PERMISSION_DENIED')) {
        console.log(`  ✅ Client write correctly blocked: ${error.message}`);
      } else {
        throw new Error(`Unexpected error: ${error.message}`);
      }
    }
    
    console.log('  ✅ Test 5 PASSED: Client writes to referral fields are blocked');
    
  } catch (error) {
    console.log(`  ❌ Test 5 FAILED: ${error.message}`);
    throw error;
  }
}

// Main test runner
async function runSmokeTests() {
  console.log('🧪 TALOWA Referral System - 5-Minute Smoke Tests');
  console.log('=================================================');
  console.log(`Project: ${TEST_CONFIG.projectId}`);
  console.log(`Region: ${TEST_CONFIG.region}`);
  console.log('');
  
  let testsPassed = 0;
  let testsFailed = 0;
  
  try {
    // Setup test users
    console.log('🔧 Setting up test users...');
    const userAData = await createTestUser('userA');
    const userBData = await createTestUser('userB');
    
    // Get ID tokens (in real scenario, you'd use Firebase Auth SDK)
    // For this test, we'll use custom tokens
    TEST_CONFIG.testUsers.userA.idToken = userAData.customToken;
    TEST_CONFIG.testUsers.userB.idToken = userBData.customToken;
    
    console.log('✅ Test users ready\n');
    
    // Run tests
    const tests = [
      test1_CodeReservation,
      test2_ApplyReferral,
      test3_DuplicateApply,
      test4_SelfReferralBlock,
      test5_ClientWriteHardening
    ];
    
    for (const test of tests) {
      try {
        await test();
        testsPassed++;
      } catch (error) {
        testsFailed++;
        console.log(`\n💥 Test failed: ${error.message}\n`);
      }
    }
    
  } catch (error) {
    console.log(`\n💥 Setup failed: ${error.message}\n`);
    testsFailed++;
  } finally {
    // Cleanup
    await cleanupTestData();
  }
  
  // Results
  console.log('\n📊 Test Results');
  console.log('===============');
  console.log(`✅ Passed: ${testsPassed}`);
  console.log(`❌ Failed: ${testsFailed}`);
  console.log(`📈 Success Rate: ${Math.round((testsPassed / (testsPassed + testsFailed)) * 100)}%`);
  
  if (testsFailed === 0) {
    console.log('\n🎉 All tests passed! Referral system is working correctly.');
    process.exit(0);
  } else {
    console.log('\n⚠️  Some tests failed. Please check the implementation.');
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  runSmokeTests().catch(error => {
    console.error('💥 Smoke tests crashed:', error);
    process.exit(1);
  });
}

module.exports = {
  runSmokeTests,
  TEST_CONFIG
};