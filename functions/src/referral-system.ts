/**
 * Talowa Referral System Cloud Functions
 * Adapted from BSS webapp referral system
 * Handles automatic referral chain updates and role promotions
 */

import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Talowa Role Thresholds (simplified from BSS's 9 levels to 3 levels)
const TALOWA_ROLE_THRESHOLDS = [
  { level: 3, name: "Leader", direct: 0, team: 50 },
  { level: 2, name: "Volunteer", direct: 5, team: 0 },
  { level: 1, name: "Member", direct: 0, team: 0 },
];

/**
 * Process referral chain when a new user is created
 * Adapted from BSS processReferral function
 */
export const processReferral = onDocumentCreated("users/{userId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.log("No data associated with the event");
    return;
  }

  const newUserDocRef = snapshot.ref;
  const newUser = snapshot.data();
  let referredByCode = newUser.referredBy;

  logger.log(`🔍 NEW USER REGISTRATION DEBUG:`);
  logger.log(`   User: ${newUser.fullName} (${snapshot.id})`);
  logger.log(`   Phone: ${newUser.phoneNumber}`);
  logger.log(`   Original referredBy: "${referredByCode}"`);
  logger.log(`   Is referredBy empty/null? ${!referredByCode}`);

  // Handle orphan users - assign to admin if no referrer
  if (!referredByCode) {
    logger.log(`❌ User ${newUser.fullName} was not referred. Assigning to admin.`);
    const adminReferralCode = "TALADMIN";

    // Update the new user's document with the admin's referral code
    await newUserDocRef.update({ referredBy: adminReferralCode });
    referredByCode = adminReferralCode;
    logger.log(`✅ Assigned user ${newUser.fullName} to admin with code ${adminReferralCode}`);
  } else {
    logger.log(`✅ User ${newUser.fullName} has valid referral code: "${referredByCode}"`);
  }

  // Process referral chain for all users (including those assigned to admin)
  if (referredByCode) {
    logger.log(`Processing referral chain for ${newUser.fullName}. Referred by code: ${referredByCode}`);

    const usersRef = db.collection("users");
    let currentReferrerCode = referredByCode;
    let isDirectReferral = true;
    const batch = db.batch();

    try {
      // Traverse up the referral chain
      while (currentReferrerCode) {
        const referrerQuery = usersRef.where("referralCode", "==", currentReferrerCode).limit(1);
        const referrerSnapshot = await referrerQuery.get();

        if (referrerSnapshot.empty) {
          logger.warn(`Referrer with code ${currentReferrerCode} not found. Stopping chain.`);
          break;
        }

        const referrerDoc = referrerSnapshot.docs[0];
        const referrerDocRef = referrerDoc.ref;
        const referrerData = referrerDoc.data();

        logger.log(`Found referrer: ${referrerData.fullName} (${referrerDoc.id})`);

        if (isDirectReferral) {
          // First person in chain gets both direct and team referral credit
          batch.update(referrerDocRef, {
            directReferrals: admin.firestore.FieldValue.increment(1),
            teamReferrals: admin.firestore.FieldValue.increment(1),
            teamSize: admin.firestore.FieldValue.increment(1), // Keep both for compatibility
            lastStatsUpdate: admin.firestore.FieldValue.serverTimestamp(),
          });
          logger.log(`Credited direct referral to ${referrerData.fullName} (${currentReferrerCode})`);
          isDirectReferral = false;
        } else {
          // Upline members only get team referral credit
          batch.update(referrerDocRef, {
            teamReferrals: admin.firestore.FieldValue.increment(1),
            teamSize: admin.firestore.FieldValue.increment(1), // Keep both for compatibility
            lastStatsUpdate: admin.firestore.FieldValue.serverTimestamp(),
          });
          logger.log(`Credited team referral to ${referrerData.fullName} (${currentReferrerCode})`);
        }

        // Stop if we reach admin (admin has no upline)
        if (currentReferrerCode === "TALADMIN") {
          logger.log("Reached TALADMIN code. Stopping chain traversal after crediting admin.");
          break;
        }

        // Move to next person up the chain
        currentReferrerCode = referrerData.referredBy;
      }

      // Commit all updates in a single batch
      await batch.commit();
      logger.log("Successfully credited referrals up the chain.");

    } catch (error) {
      logger.error("Error processing referral chain:", error);
    }
  }
});

/**
 * Auto-promote users when their referral stats are updated
 * Adapted from BSS autoPromoteUser function
 */
export const autoPromoteUser = onDocumentUpdated("users/{userId}", async (event) => {
  const change = event.data;
  if (!change) return;

  const userData = change.after.data();
  const beforeData = change.before.data();

  // Check if referral counts have actually changed to prevent infinite loops
  if (
    userData.directReferrals === beforeData.directReferrals &&
    userData.teamReferrals === beforeData.teamReferrals
  ) {
    return;
  }

  // Skip admin users from promotions
  if (userData.currentRoleLevel === 0 || userData.role === 'Admin') {
    return;
  }

  const { directReferrals, teamReferrals, currentRoleLevel } = userData;

  let newRole = { level: 1, name: "Member" }; // Default role

  // Find the highest eligible role
  for (const role of TALOWA_ROLE_THRESHOLDS) {
    const meetsDirect = directReferrals >= role.direct;
    const meetsTeam = teamReferrals >= role.team;

    // Check if user meets requirements for this role
    if (meetsDirect && meetsTeam) {
      newRole = role;
      break; // Found the highest eligible role
    }
  }

  // If the user's role has changed, update their document
  if (newRole.level > currentRoleLevel) {
    logger.log(`Promoting user ${event.params.userId} from level ${currentRoleLevel} to ${newRole.level} (${newRole.name}).`);
    
    await change.after.ref.update({
      currentRoleLevel: newRole.level,
      role: newRole.name,
      lastRoleUpdate: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send promotion notification
    try {
      await sendPromotionNotification(event.params.userId, userData.fullName, newRole.name);
    } catch (error) {
      logger.warn('Failed to send promotion notification:', error);
      // Don't throw - promotion should still succeed even if notification fails
    }
  }
});

/**
 * Send promotion notification to user
 */
async function sendPromotionNotification(userId: string, userName: string, newRole: string): Promise<void> {
  try {
    // Add notification to user's notifications subcollection
    await db
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add({
        type: 'promotion',
        title: 'Congratulations! 🎉',
        message: `You have been promoted to ${newRole}!`,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    logger.log(`📧 Promotion notification sent to ${userName} for ${newRole}`);
  } catch (error) {
    logger.error('Failed to send promotion notification:', error);
    throw error;
  }
}

/**
 * Fix orphaned users (assign them to admin)
 * HTTP function for admin use
 */
export const fixOrphanedUsers = onDocumentCreated("admin/fix-orphans", async (event) => {
  try {
    logger.log('🔧 Starting orphan user fix...');

    // Find users with no referrer
    const orphanQuery = await db
      .collection('users')
      .where('referredBy', '==', null)
      .get();

    if (orphanQuery.empty) {
      logger.log('✅ No orphaned users found');
      return;
    }

    const batch = db.batch();
    let updateCount = 0;

    for (const doc of orphanQuery.docs) {
      const userData = doc.data();
      
      // Skip admin users
      if (userData.role === 'Admin' || userData.referralCode === 'TALADMIN') {
        continue;
      }

      // Assign to admin
      batch.update(doc.ref, {
        referredBy: 'TALADMIN',
        lastStatsUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      updateCount++;
      logger.log(`   Assigning ${userData.fullName} to admin`);
    }

    if (updateCount > 0) {
      await batch.commit();
      logger.log(`✅ Fixed ${updateCount} orphaned users`);
    }

  } catch (error) {
    logger.error('❌ Error fixing orphaned users:', error);
  }
});