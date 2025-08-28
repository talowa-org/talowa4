#!/usr/bin/env node

/**
 * Quick Referral Code Consistency Check
 * 
 * This script quickly checks for referral code inconsistencies
 * without making any changes to the database.
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';

// Initialize Firebase Admin
let serviceAccount;
try {
  serviceAccount = JSON.parse(readFileSync('./serviceAccountKey.json', 'utf8'));
} catch (e) {
  console.error('❌ Service account key not found. Please ensure serviceAccountKey.json exists.');
  process.exit(1);
}

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function quickConsistencyCheck() {
  console.log('🔍 Quick Referral Code Consistency Check');
  console.log('========================================\n');
  
  let totalUsers = 0;
  let consistentUsers = 0;
  let inconsistentUsers = 0;
  const issues = [];
  
  try {
    console.log('📊 Scanning users collection...\n');
    
    const usersSnapshot = await db.collection('users').get();
    
    for (const userDoc of usersSnapshot.docs) {
      totalUsers++;
      const userData = userDoc.data();
      const uid = userDoc.id;
      const phoneNumber = userData.phoneNumber || userData.phone || userData.phoneE164;
      const userReferralCode = userData.referralCode;
      const fullName = userData.fullName || 'Unknown';
      
      if (!phoneNumber) {
        console.log(`⚠️  ${fullName} (${uid}): No phone number`);
        continue;
      }
      
      try {
        // Check user_registry collection
        const registryDoc = await db.collection('user_registry').doc(phoneNumber).get();
        
        if (registryDoc.exists) {
          const registryData = registryDoc.data();
          const registryReferralCode = registryData.referralCode;
          
          if (userReferralCode === registryReferralCode) {
            consistentUsers++;
            console.log(`✅ ${fullName}: ${userReferralCode || 'No code'}`);
          } else {
            inconsistentUsers++;
            issues.push({
              name: fullName,
              phone: phoneNumber,
              userCode: userReferralCode,
              registryCode: registryReferralCode
            });
            console.log(`❌ ${fullName}: MISMATCH`);
            console.log(`   users: "${userReferralCode}"`);
            console.log(`   registry: "${registryReferralCode}"`);
          }
        } else {
          console.log(`⚠️  ${fullName}: No registry entry`);
        }
      } catch (error) {
        console.log(`⚠️  ${fullName}: Error checking - ${error.message}`);
      }
    }
    
    console.log('\n📊 RESULTS SUMMARY');
    console.log('==================');
    console.log(`Total users scanned: ${totalUsers}`);
    console.log(`Consistent codes: ${consistentUsers}`);
    console.log(`Inconsistent codes: ${inconsistentUsers}`);
    
    if (inconsistentUsers === 0) {
      console.log('\n🎉 All referral codes are consistent!');
      console.log('No action needed.');
    } else {
      console.log(`\n⚠️  Found ${inconsistentUsers} users with inconsistent referral codes:`);
      issues.forEach(issue => {
        console.log(`\n• ${issue.name} (${issue.phone})`);
        console.log(`  users collection: "${issue.userCode}"`);
        console.log(`  user_registry: "${issue.registryCode}"`);
      });
      
      console.log('\n🔧 RECOMMENDED ACTION:');
      console.log('Run the full consistency fix script:');
      console.log('  fix_referral_consistency.bat');
      console.log('  or');
      console.log('  node fix_referral_data_consistency.js');
    }
    
  } catch (error) {
    console.error('💥 Error during consistency check:', error);
    process.exit(1);
  }
}

// Run the check
quickConsistencyCheck();