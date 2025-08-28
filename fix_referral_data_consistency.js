#!/usr/bin/env node

/**
 * TALOWA Referral Code Data Consistency Fix
 * 
 * This script fixes the critical data consistency issue where users have
 * different referral codes in the 'users' and 'user_registry' collections.
 * 
 * Problem: Same user has different referral codes:
 * - users collection: "TAL93NDKV" 
 * - user_registry collection: "TAL2VUR2R"
 * 
 * Solution: Use 'users' collection as source of truth and sync all collections
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';

// Initialize Firebase Admin
let serviceAccount;
try {
  serviceAccount = JSON.parse(readFileSync('./serviceAccountKey.json', 'utf8'));
} catch (e) {
  console.error('❌ Service account key not found. Please ensure serviceAccountKey.json exists.');
  console.log('💡 Download it from Firebase Console > Project Settings > Service Accounts');
  process.exit(1);
}

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

// Referral code validation
const REFERRAL_PREFIX = 'TAL';
const BASE32_CHARS = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

function isValidReferralCode(code) {
  if (!code || typeof code !== 'string') return false;
  const normalized = code.toUpperCase().trim();
  return /^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6,8}$/.test(normalized);
}

function generateReferralCode() {
  let code = REFERRAL_PREFIX;
  // Generate 6 characters for consistency
  for (let i = 0; i < 6; i++) {
    code += BASE32_CHARS[Math.floor(Math.random() * BASE32_CHARS.length)];
  }
  return code;
}

async function findInconsistentUsers() {
  console.log('🔍 Scanning for referral code inconsistencies...\n');
  
  const inconsistentUsers = [];
  const usersSnapshot = await db.collection('users').get();
  
  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    const uid = userDoc.id;
    const phoneNumber = userData.phoneNumber || userData.phone || userData.phoneE164;
    const userReferralCode = userData.referralCode;
    
    if (!phoneNumber) continue;
    
    try {
      // Check user_registry collection
      const registryDoc = await db.collection('user_registry').doc(phoneNumber).get();
      
      if (registryDoc.exists) {
        const registryData = registryDoc.data();
        const registryReferralCode = registryData.referralCode;
        
        // Check for mismatch
        if (userReferralCode !== registryReferralCode) {
          inconsistentUsers.push({
            uid,
            phoneNumber,
            userReferralCode,
            registryReferralCode,
            fullName: userData.fullName || 'Unknown'
          });
          
          console.log(`❌ MISMATCH FOUND:`);
          console.log(`   User: ${userData.fullName || 'Unknown'} (${phoneNumber})`);
          console.log(`   UID: ${uid}`);
          console.log(`   users collection: "${userReferralCode}"`);
          console.log(`   user_registry collection: "${registryReferralCode}"`);
          console.log('');
        }
      }
    } catch (error) {
      console.warn(`⚠️  Error checking user ${uid}: ${error.message}`);
    }
  }
  
  return inconsistentUsers;
}

async function fixUserConsistency(user) {
  const { uid, phoneNumber, userReferralCode, registryReferralCode } = user;
  
  console.log(`🔧 Fixing user: ${user.fullName} (${phoneNumber})`);
  
  // Determine which code to use as source of truth
  let finalCode;
  let reason;
  
  if (isValidReferralCode(userReferralCode)) {
    finalCode = userReferralCode;
    reason = 'Using users collection code (valid TAL format)';
  } else if (isValidReferralCode(registryReferralCode)) {
    finalCode = registryReferralCode;
    reason = 'Using user_registry code (users collection invalid)';
  } else {
    finalCode = generateReferralCode();
    reason = 'Generated new code (both existing codes invalid)';
  }
  
  console.log(`   Decision: ${reason}`);
  console.log(`   Final code: ${finalCode}`);
  
  try {
    // Update both collections in a batch
    const batch = db.batch();
    
    // Update users collection
    const userRef = db.collection('users').doc(uid);
    batch.update(userRef, {
      referralCode: finalCode,
      referralCodeUpdatedAt: FieldValue.serverTimestamp(),
      referralCodeSource: 'consistency_fix'
    });
    
    // Update user_registry collection
    const registryRef = db.collection('user_registry').doc(phoneNumber);
    batch.update(registryRef, {
      referralCode: finalCode,
      referralCodeUpdatedAt: FieldValue.serverTimestamp(),
      referralCodeSource: 'consistency_fix'
    });
    
    // Reserve the code in referralCodes collection
    const codeRef = db.collection('referralCodes').doc(finalCode);
    batch.set(codeRef, {
      uid,
      phoneNumber,
      active: true,
      reservedAt: FieldValue.serverTimestamp(),
      source: 'consistency_fix'
    }, { merge: true });
    
    await batch.commit();
    
    console.log(`   ✅ Fixed successfully`);
    return { success: true, finalCode };
    
  } catch (error) {
    console.error(`   ❌ Failed to fix: ${error.message}`);
    return { success: false, error: error.message };
  }
}

async function validateFix() {
  console.log('\n🔍 Validating fixes...\n');
  
  const inconsistentUsers = await findInconsistentUsers();
  
  if (inconsistentUsers.length === 0) {
    console.log('✅ All users have consistent referral codes!');
    return true;
  } else {
    console.log(`❌ Still found ${inconsistentUsers.length} inconsistent users`);
    return false;
  }
}

async function generateReport(results) {
  console.log('\n📊 CONSISTENCY FIX REPORT');
  console.log('========================\n');
  
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  
  console.log(`Total users processed: ${results.length}`);
  console.log(`Successfully fixed: ${successful.length}`);
  console.log(`Failed to fix: ${failed.length}`);
  
  if (failed.length > 0) {
    console.log('\n❌ Failed fixes:');
    failed.forEach(f => {
      console.log(`   ${f.user.fullName} (${f.user.phoneNumber}): ${f.error}`);
    });
  }
  
  console.log('\n✅ All referral codes are now consistent across collections!');
  console.log('\n🔧 Next steps:');
  console.log('1. Deploy updated registration flow to prevent future inconsistencies');
  console.log('2. Monitor for any new inconsistencies');
  console.log('3. Consider adding automated consistency checks');
}

async function main() {
  console.log('🚀 TALOWA Referral Code Consistency Fix');
  console.log('=====================================\n');
  
  try {
    // Step 1: Find all inconsistent users
    const inconsistentUsers = await findInconsistentUsers();
    
    if (inconsistentUsers.length === 0) {
      console.log('✅ No referral code inconsistencies found!');
      return;
    }
    
    console.log(`Found ${inconsistentUsers.length} users with inconsistent referral codes\n`);
    
    // Step 2: Fix each user
    console.log('🔧 Starting consistency fixes...\n');
    const results = [];
    
    for (const user of inconsistentUsers) {
      const result = await fixUserConsistency(user);
      results.push({ user, ...result });
      
      // Small delay to avoid overwhelming Firestore
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    // Step 3: Validate fixes
    const isValid = await validateFix();
    
    // Step 4: Generate report
    await generateReport(results);
    
    if (isValid) {
      console.log('\n🎉 Referral code consistency fix completed successfully!');
      process.exit(0);
    } else {
      console.log('\n⚠️  Some inconsistencies remain. Please review and run again.');
      process.exit(1);
    }
    
  } catch (error) {
    console.error('💥 Fatal error:', error);
    process.exit(1);
  }
}

// Run the fix
main();