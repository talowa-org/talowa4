// Test script for Talowa referral system Cloud Functions
// Run with: node test_cloud_functions.js

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./talowa-firebase-adminsdk-key.json'); // You'll need to download this
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'talowa'
});

const functions = admin.functions();

async function testCloudFunctions() {
  console.log('🧪 Testing Talowa Cloud Functions...\n');

  try {
    // Test 1: Process Referral
    console.log('1️⃣ Testing processReferral function...');
    const processReferralResult = await functions.httpsCallable('processReferral')({
      userId: 'test-user-123'
    });
    console.log('✅ processReferral result:', processReferralResult.data);
    console.log('');

    // Test 2: Auto Promote User
    console.log('2️⃣ Testing autoPromoteUser function...');
    const autoPromoteResult = await functions.httpsCallable('autoPromoteUser')({
      userId: 'test-user-123'
    });
    console.log('✅ autoPromoteUser result:', autoPromoteResult.data);
    console.log('');

    // Test 3: Fix Orphaned Users
    console.log('3️⃣ Testing fixOrphanedUsers function...');
    const fixOrphansResult = await functions.httpsCallable('fixOrphanedUsers')();
    console.log('✅ fixOrphanedUsers result:', fixOrphansResult.data);
    console.log('');

    console.log('🎉 All Cloud Functions tests completed successfully!');

  } catch (error) {
    console.error('❌ Error testing Cloud Functions:', error);
  }
}

// Run the tests
testCloudFunctions();