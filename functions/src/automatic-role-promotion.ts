/**
 * Automatic Role Promotion System
 * Triggers immediately when achievement threshold reaches 100%
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

const db = admin.firestore();

// TALOWA Role Thresholds for automatic promotion
const ROLE_THRESHOLDS = [
  { level: 9, name: "State Coordinator", direct: 1000, team: 3000000 },
  { level: 8, name: "Zonal Regional Coordinator", direct: 500, team: 1500000 },
  { level: 7, name: "District Coordinator", direct: 320, team: 500000 },
  { level: 6, name: "Constituency Coordinator", direct: 160, team: 50000 },
  { level: 5, name: "Mandal Coordinator", direct: 80, team: 6000 },
  { level: 4, name: "Area Coordinator", direct: 40, team: 700 },
  { level: 3, name: "Team Leader", direct: 20, team: 100 },
  { level: 2, name: "Volunteer", direct: 10, team: 10 },
  { level: 1, name: "Member", direct: 0, team: 0 },
];

/**
 * Real-time automatic role promotion trigger
 * Fires whenever a user document is updated
 */
export const automaticRolePromotion = onDocumentWritten(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    const afterData = event.data?.after?.data();

    // Skip if document was deleted or is admin
    if (!afterData || afterData.role === 'Admin') {
      return;
    }

    logger.log(`🔄 Checking automatic promotion for user ${userId}`);

    try {
      await processAutomaticPromotion(userId, afterData);
    } catch (error) {
      logger.error(`❌ Failed automatic promotion for user ${userId}:`, error);
    }
  }
);

/**
 * Process automatic promotion for a user
 */
async function processAutomaticPromotion(userId: string, userData: any): Promise<void> {
  const currentRoleLevel = userData.currentRoleLevel || 1;
  const directReferrals = userData.directReferrals || 0;
  const teamReferrals = userData.teamReferrals || userData.teamSize || 0;

  // Find the highest eligible role
  let newRole = null;
  for (const role of ROLE_THRESHOLDS) {
    const meetsDirect = directReferrals >= role.direct;
    const meetsTeam = teamReferrals >= role.team;

    if (meetsDirect && meetsTeam && role.level > currentRoleLevel) {
      newRole = role;
      break;
    }
  }

  // Execute promotion immediately if eligible
  if (newRole) {
    await executeRolePromotion(userId, userData, newRole);
  }
}

/**
 * Execute the role promotion immediately
 */
async function executeRolePromotion(userId: string, userData: any, newRole: any): Promise<void> {
  const userRef = db.collection('users').doc(userId);
  
  logger.log(`🎉 PROMOTING USER ${userId} to ${newRole.name}`);

  // Update user role immediately
  await userRef.update({
    currentRoleLevel: newRole.level,
    role: newRole.name,
    lastRoleUpdate: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Send immediate notification
  await db
    .collection('users')
    .doc(userId)
    .collection('notifications')
    .add({
      type: 'automatic_promotion',
      title: '🎉 Automatic Promotion!',
      message: `Congratulations! You have been automatically promoted to ${newRole.name}!`,
      read: false,
      priority: 'high',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  logger.log(`✅ Successfully promoted user ${userId} to ${newRole.name}`);
}

/**
 * Manual trigger for checking promotions
 */
export const triggerRolePromotionCheck = onCall(async (request) => {
  const { userId } = request.data;
  
  if (!userId) {
    throw new Error('userId is required');
  }

  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw new Error('User not found');
  }

  await processAutomaticPromotion(userId, userDoc.data()!);
  return { success: true, message: 'Promotion check completed' };
});