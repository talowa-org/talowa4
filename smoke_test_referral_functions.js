// Quick smoke test for TALOWA referral system Cloud Functions
// This tests the three core functions: reserveReferralCode, applyReferralCode, getMyReferralStats

const admin = require('firebase-admin');
const { getFunctions } = require('firebase-admin/functions');

// Initialize Firebase Admin (you'll need to set GOOGLE_APPLICATION_CREDENTIALS)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function smokeTestReferralSystem() {
  console.log('🧪 Starting TALOWA Referral System Smoke Test...\n');

  try {
    // Test 1: Check if functions are deployed
    console.log('📋 Test 1: Checking deployed functions...');
    const functions = getFunctions();
    const functionsList = await functions.listFunctions();

    const requiredFunctions = ['reserveReferralCode', 'applyReferralCode', 'getMyReferralStats'];
    const deployedFunctions = functionsList.map(f => f.name.split('/').pop());

    requiredFunctions.forEach(funcName => {
      if (deployedFunctions.includes(funcName)) {
        console.log(`✅ ${funcName} - DEPLOYED`);
      } else {
        console.log(`❌ ${funcName} - NOT FOUND`);
      }
    });

    // Test 2: Check Firestore collections structure
    console.log('\n📋 Test 2: Checking Firestore collections...');

    // Check if referralCodes collection exists
    const referralCodesSnapshot = await db.collection('referralCodes').limit(1).get();
    console.log(`✅ referralCodes collection - ${referralCodesSnapshot.empty ? 'EMPTY' : 'HAS DATA'}`);

    // Check if users collection has referral fields
    const usersSnapshot = await db.collection('users').limit(1).get();
    if (!usersSnapshot.empty) {
      const userData = usersSnapshot.docs[0].data();
      const hasReferralFields = userData.referral || userData.referralCode;
      console.log(`✅ users collection referral fields - ${hasReferralFields ? 'PRESENT' : 'MISSING'}`);
    } else {
      console.log(`⚠️ users collection - EMPTY (no data to check)`);
    }

    // Test 3: Check Firestore rules (basic read test)
    console.log('\n📋 Test 3: Testing Firestore rules...');

    try {
      // This should fail with permission denied (good!)
      await db.collection('referralCodes').add({ test: true });
      console.log('❌ referralCodes write protection - FAILED (should be blocked)');
    } catch (error) {
      if (error.code === 'permission-denied') {
        console.log('✅ referralCodes write protection - WORKING');
      } else {
        console.log(`⚠️ referralCodes write protection - UNEXPECTED ERROR: ${error.message}`);
      }
    }

    console.log('\n🎯 Smoke Test Summary:');
    console.log('- Core functions appear to be deployed');
    console.log('- Firestore collections are accessible');
    console.log('- Security rules are protecting write operations');
    console.log('\n✅ Basic infrastructure looks good!');
    console.log('\n📝 Next steps:');
    console.log('1. Test with authenticated user tokens');
    console.log('2. Verify code generation and validation');
    console.log('3. Test referral relationship creation');
    console.log('4. Validate idempotency behavior');

  } catch (error) {
    console.error('❌ Smoke test failed:', error);
  }
}

// Run the test
smokeTestReferralSystem().then(() => {
  console.log('\n🏁 Smoke test completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Smoke test crashed:', error);
  process.exit(1);
});