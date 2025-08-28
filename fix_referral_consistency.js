/**
 * Fix Referral Code Consistency Script
 * 
 * This script fixes the referral code mismatch issue where users have
 * different referral codes in the 'users' and 'user_registry' collections.
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

async function fixReferralCodeConsistency() {
  console.log('🔧 Starting referral code consistency fix...');
  
  let fixedCount = 0;
  let errorCount = 0;
  let totalChecked = 0;

  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.docs.length} users to check`);

    for (const userDoc of usersSnapshot.docs) {
      totalChecked++;
      const uid = userDoc.id;
      const userData = userDoc.data();
      
      try {
        const phoneE164 = userData.phoneE164 || userData.phone;
        const userReferralCode = userData.referral?.code || userData.referralCode;

        if (!phoneE164) {
          console.log(`⚠️  User ${uid} has no phone number, skipping`);
          continue;
        }

        // Get user_registry document
        const registryDoc = await db.collection('user_registry').doc(phoneE164).get();
        
        if (!registryDoc.exists) {
          console.log(`⚠️  No registry found for ${phoneE164}, skipping`);
          continue;
        }

        const registryData = registryDoc.data();
        const registryReferralCode = registryData.referralCode;

        // Check if codes match
        if (userReferralCode === registryReferralCode) {
          console.log(`✅ User ${uid} codes already match: ${userReferralCode}`);
          continue;
        }

        console.log(`🔍 Mismatch found for ${uid}:`);
        console.log(`   Users collection: ${userReferralCode}`);
        console.log(`   Registry collection: ${registryReferralCode}`);

        // Determine which code to use as source of truth
        let correctCode = null;

        if (userReferralCode && isValidTALCode(userReferralCode)) {
          correctCode = userReferralCode;
          console.log(`   Using users collection code: ${correctCode}`);
        } else if (registryReferralCode && isValidTALCode(registryReferralCode)) {
          correctCode = registryReferralCode;
          console.log(`   Using registry collection code: ${correctCode}`);
        } else {
          console.log(`   Neither code is valid, generating new one`);
          correctCode = generateTALCode();
        }

        // Update both collections to use the correct code
        const batch = db.batch();

        // Update users collection
        batch.update(userDoc.ref, { referralCode: correctCode });

        // Update user_registry collection
        batch.update(registryDoc.ref, { referralCode: correctCode });

        // Reserve the code in referralCodes collection
        const codeRef = db.collection('referralCodes').doc(correctCode);
        batch.set(codeRef, {
          uid: uid,
          active: true,
          createdAt: new Date(),
          fixedAt: new Date(),
        }, { merge: true });

        await batch.commit();

        console.log(`✅ Fixed ${uid} with code: ${correctCode}`);
        fixedCount++;

      } catch (error) {
        console.error(`❌ Error fixing user ${uid}:`, error);
        errorCount++;
      }
    }

    console.log('\n📊 CONSISTENCY FIX SUMMARY:');
    console.log(`   Total users checked: ${totalChecked}`);
    console.log(`   Users fixed: ${fixedCount}`);
    console.log(`   Errors: ${errorCount}`);
    console.log(`   Success rate: ${((fixedCount / totalChecked) * 100).toFixed(1)}%`);

  } catch (error) {
    console.error('❌ Fatal error during consistency fix:', error);
  }
}

function isValidTALCode(code) {
  if (!code || typeof code !== 'string') return false;
  const normalized = code.toUpperCase().trim();
  return /^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{7,8}$/.test(normalized);
}

function generateTALCode() {
  const chars = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  let code = 'TAL';
  const length = Math.random() < 0.5 ? 7 : 8;
  
  for (let i = 0; i < length; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  
  return code;
}

// Run the fix
fixReferralCodeConsistency()
  .then(() => {
    console.log('🎉 Referral code consistency fix completed!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('💥 Fix failed:', error);
    process.exit(1);
  });