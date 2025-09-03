// functions/src/admin-system.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const auth = admin.auth();

// Admin role hierarchy
const ADMIN_ROLES = {
  SUPER_ADMIN: 'super_admin',
  MODERATOR: 'moderator', 
  REGIONAL_ADMIN: 'regional_admin',
  AUDITOR: 'auditor'
} as const;

type AdminRole = typeof ADMIN_ROLES[keyof typeof ADMIN_ROLES];

// Role permissions mapping
const ROLE_PERMISSIONS = {
  [ADMIN_ROLES.SUPER_ADMIN]: ['*'], // All permissions
  [ADMIN_ROLES.MODERATOR]: ['moderate_content', 'ban_users', 'view_reports'],
  [ADMIN_ROLES.REGIONAL_ADMIN]: ['moderate_content', 'view_regional_data', 'manage_regional_users'],
  [ADMIN_ROLES.AUDITOR]: ['view_logs', 'view_analytics', 'export_data']
};

/**
 * Assign admin role to a user (only super_admin can do this)
 */
export const assignAdminRole = functions.https.onCall(async (data, context) => {
  try {
    // Verify caller is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    // Verify caller has super_admin role
    const callerClaims = context.auth.token;
    if (callerClaims.role !== ADMIN_ROLES.SUPER_ADMIN) {
      throw new functions.https.HttpsError('permission-denied', 'Only super_admin can assign roles');
    }

    const { targetUid, role, region } = data;

    // Validate inputs
    if (!targetUid || !role) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid and role are required');
    }

    if (!Object.values(ADMIN_ROLES).includes(role)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid role specified');
    }

    // Set custom claims
    const customClaims: any = { role };
    if (region && role === ADMIN_ROLES.REGIONAL_ADMIN) {
      customClaims.region = region;
    }

    await auth.setCustomUserClaims(targetUid, customClaims);

    // Update user document
    await db.collection('users').doc(targetUid).update({
      role,
      adminRole: role,
      region: region || null,
      roleAssignedAt: admin.firestore.FieldValue.serverTimestamp(),
      roleAssignedBy: context.auth.uid
    });

    // Log the action
    await logAdminAction({
      adminUid: context.auth.uid,
      action: 'assign_role',
      targetUid,
      details: { role, region },
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, message: `Role ${role} assigned successfully` };

  } catch (error) {
    console.error('Error assigning admin role:', error);
    throw error;
  }
});

/**
 * Revoke admin role from a user (only super_admin can do this)
 */
export const revokeAdminRole = functions.https.onCall(async (data, context) => {
  try {
    // Verify caller is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    // Verify caller has super_admin role
    const callerClaims = context.auth.token;
    if (callerClaims.role !== ADMIN_ROLES.SUPER_ADMIN) {
      throw new functions.https.HttpsError('permission-denied', 'Only super_admin can revoke roles');
    }

    const { targetUid } = data;

    if (!targetUid) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid is required');
    }

    // Cannot revoke own role
    if (targetUid === context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot revoke your own role');
    }

    // Remove custom claims
    await auth.setCustomUserClaims(targetUid, { role: null, region: null });

    // Update user document
    await db.collection('users').doc(targetUid).update({
      role: 'member',
      adminRole: admin.firestore.FieldValue.delete(),
      region: admin.firestore.FieldValue.delete(),
      roleRevokedAt: admin.firestore.FieldValue.serverTimestamp(),
      roleRevokedBy: context.auth.uid
    });

    // Log the action
    await logAdminAction({
      adminUid: context.auth.uid,
      action: 'revoke_role',
      targetUid,
      details: {},
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, message: 'Admin role revoked successfully' };

  } catch (error) {
    console.error('Error revoking admin role:', error);
    throw error;
  }
});

/**
 * Log admin actions for audit trail
 */
export const logAdminAction = async (actionData: {
  adminUid: string;
  action: string;
  targetUid?: string;
  details: any;
  timestamp: any;
}) => {
  try {
    await db.collection('transparency_logs').add({
      ...actionData,
      id: db.collection('transparency_logs').doc().id,
      immutable: true // Mark as immutable for audit purposes
    });
  } catch (error) {
    console.error('Error logging admin action:', error);
    throw error;
  }
};

/**
 * Flag suspicious referral activities
 */
export const flagSuspiciousReferrals = functions.https.onCall(async (data, context) => {
  try {
    // Verify caller is authenticated and has appropriate role
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    const callerRole = context.auth.token.role;
    if (!callerRole || !['super_admin', 'moderator', 'auditor'].includes(callerRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions');
    }

    // Get all users and analyze referral patterns
    const usersSnapshot = await db.collection('users').get();
    const suspiciousActivities = [];

    const userMap = new Map();
    usersSnapshot.docs.forEach(doc => {
      userMap.set(doc.id, { id: doc.id, ...doc.data() });
    });

    // Check for suspicious patterns
    for (const [uid, user] of userMap) {
      const referralStats = user.referralStats || {};
      const directReferrals = referralStats.directReferrals || 0;
      const teamSize = referralStats.teamSize || 0;
      
      // Flag users with unusually high referral rates
      if (directReferrals > 50 || teamSize > 200) {
        suspiciousActivities.push({
          uid,
          phoneNumber: user.phoneNumber,
          type: 'high_referral_count',
          details: { directReferrals, teamSize },
          flaggedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      // Flag users with suspicious referral patterns (e.g., all referrals in short time)
      if (user.createdAt && directReferrals > 10) {
        const accountAge = Date.now() - user.createdAt.toDate().getTime();
        const daysOld = accountAge / (1000 * 60 * 60 * 24);
        
        if (daysOld < 7 && directReferrals > 20) {
          suspiciousActivities.push({
            uid,
            phoneNumber: user.phoneNumber,
            type: 'rapid_referral_growth',
            details: { directReferrals, accountAgeDays: Math.round(daysOld) },
            flaggedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      }
    }

    // Store flagged activities
    const batch = db.batch();
    suspiciousActivities.forEach(activity => {
      const docRef = db.collection('flagged_activities').doc();
      batch.set(docRef, activity);
    });
    await batch.commit();

    // Log the action
    await logAdminAction({
      adminUid: context.auth.uid,
      action: 'flag_suspicious_referrals',
      details: { flaggedCount: suspiciousActivities.length },
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    // Send alert if suspicious activities found
    if (suspiciousActivities.length > 0) {
      await sendAdminAlert({
        type: 'suspicious_referrals',
        message: `${suspiciousActivities.length} suspicious referral activities detected`,
        details: suspiciousActivities.slice(0, 5) // Send first 5 for preview
      });
    }

    return { 
      success: true, 
      flaggedCount: suspiciousActivities.length,
      activities: suspiciousActivities 
    };

  } catch (error) {
    console.error('Error flagging suspicious referrals:', error);
    throw error;
  }
});

/**
 * Send admin alerts via FCM and email
 */
export const sendAdminAlert = async (alertData: {
  type: string;
  message: string;
  details?: any;
}) => {
  try {
    // Get all super_admin users
    const adminUsersSnapshot = await db.collection('users')
      .where('role', '==', 'super_admin')
      .get();

    const notifications = [];
    
    for (const doc of adminUsersSnapshot.docs) {
      const adminUser = doc.data();
      
      // Send FCM notification if user has FCM token
      if (adminUser.fcmToken) {
        const message = {
          token: adminUser.fcmToken,
          notification: {
            title: 'TALOWA Admin Alert',
            body: alertData.message
          },
          data: {
            type: alertData.type,
            details: JSON.stringify(alertData.details || {})
          }
        };
        
        notifications.push(admin.messaging().send(message));
      }
    }

    // Send all notifications
    await Promise.allSettled(notifications);

    // Store alert in database
    await db.collection('admin_alerts').add({
      ...alertData,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      recipients: adminUsersSnapshot.docs.map(doc => doc.id)
    });

  } catch (error) {
    console.error('Error sending admin alert:', error);
    throw error;
  }
};

/**
 * Validate admin access for sensitive operations
 */
export const validateAdminAccess = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    const { action, pin } = data;
    const userUid = context.auth.uid;
    const userRole = context.auth.token.role;

    // Check if user has admin role
    if (!userRole || !Object.values(ADMIN_ROLES).includes(userRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Not an admin user');
    }

    // For sensitive actions, require PIN verification
    const sensitiveActions = ['ban_user', 'delete_user', 'export_data', 'assign_role', 'revoke_role'];
    
    if (sensitiveActions.includes(action)) {
      if (!pin) {
        throw new functions.https.HttpsError('invalid-argument', 'PIN required for sensitive actions');
      }

      // Verify PIN against stored hash
      const adminDoc = await db.collection('admin_config').doc('credentials').get();
      if (!adminDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Admin configuration not found');
      }

      // For now, we'll use the existing PIN system
      // In production, this should be replaced with proper MFA
      const adminData = adminDoc.data()!;
      const crypto = require('crypto');
      const inputPinHash = crypto.createHash('sha256').update(`talowa_admin_${pin}`).digest('hex');
      
      if (inputPinHash !== adminData.pinHash) {
        throw new functions.https.HttpsError('permission-denied', 'Invalid PIN');
      }
    }

    // Log the access validation
    await logAdminAction({
      adminUid: userUid,
      action: 'validate_access',
      details: { requestedAction: action },
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { 
      success: true, 
      role: userRole,
      permissions: ROLE_PERMISSIONS[userRole as AdminRole] || []
    };

  } catch (error) {
    console.error('Error validating admin access:', error);
    throw error;
  }
});

/**
 * Get admin audit logs
 */
export const getAdminAuditLogs = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    const userRole = context.auth.token.role;
    if (!userRole || !['super_admin', 'auditor'].includes(userRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions to view audit logs');
    }

    const { limit = 100, startAfter } = data;

    let query = db.collection('transparency_logs')
      .orderBy('timestamp', 'desc')
      .limit(limit);

    if (startAfter) {
      query = query.startAfter(startAfter);
    }

    const snapshot = await query.get();
    const logs = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    return { success: true, logs };

  } catch (error) {
    console.error('Error getting audit logs:', error);
    throw error;
  }
});

/**
 * Moderate content (ban/unban users, remove content)
 */
export const moderateContent = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    const userRole = context.auth.token.role;
    if (!userRole || !['super_admin', 'moderator'].includes(userRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions for moderation');
    }

    const { action, targetUid, reason, duration } = data;

    if (!action || !targetUid) {
      throw new functions.https.HttpsError('invalid-argument', 'action and targetUid are required');
    }

    const batch = db.batch();
    const moderationRef = db.collection('moderation_actions').doc();

    // Perform moderation action
    switch (action) {
      case 'ban_user':
        // Update user status
        const userRef = db.collection('users').doc(targetUid);
        batch.update(userRef, {
          status: 'banned',
          bannedAt: admin.firestore.FieldValue.serverTimestamp(),
          bannedBy: context.auth.uid,
          banReason: reason,
          banDuration: duration
        });

        // Disable Firebase Auth account
        await auth.updateUser(targetUid, { disabled: true });
        break;

      case 'unban_user':
        const unbanUserRef = db.collection('users').doc(targetUid);
        batch.update(unbanUserRef, {
          status: 'active',
          unbannedAt: admin.firestore.FieldValue.serverTimestamp(),
          unbannedBy: context.auth.uid,
          banReason: admin.firestore.FieldValue.delete(),
          banDuration: admin.firestore.FieldValue.delete()
        });

        // Re-enable Firebase Auth account
        await auth.updateUser(targetUid, { disabled: false });
        break;

      default:
        throw new functions.https.HttpsError('invalid-argument', 'Invalid moderation action');
    }

    // Log moderation action
    batch.set(moderationRef, {
      action,
      targetUid,
      moderatorUid: context.auth.uid,
      reason,
      duration,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      immutable: true
    });

    await batch.commit();

    // Log to transparency logs
    await logAdminAction({
      adminUid: context.auth.uid,
      action: `moderate_${action}`,
      targetUid,
      details: { reason, duration },
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, message: `User ${action} completed successfully` };

  } catch (error) {
    console.error('Error moderating content:', error);
    throw error;
  }
});

/**
 * Bulk moderate multiple users
 */
export const bulkModerateUsers = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    const userRole = context.auth.token.role;
    if (userRole !== 'super_admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only super_admin can perform bulk moderation');
    }

    const { action, targetUids, reason } = data;

    if (!action || !targetUids || !Array.isArray(targetUids)) {
      throw new functions.https.HttpsError('invalid-argument', 'action and targetUids array are required');
    }

    const results = [];
    
    // Process in batches of 10 to avoid timeout
    for (let i = 0; i < targetUids.length; i += 10) {
      const batch = targetUids.slice(i, i + 10);
      
      const batchPromises = batch.map(async (targetUid) => {
        try {
          // Perform moderation action directly
          const batch = db.batch();
          const moderationRef = db.collection('moderation_actions').doc();

          // Perform moderation action
          switch (action) {
            case 'ban_user':
              // Update user status
              const userRef = db.collection('users').doc(targetUid);
              batch.update(userRef, {
                status: 'banned',
                bannedAt: admin.firestore.FieldValue.serverTimestamp(),
                bannedBy: context.auth!.uid,
                banReason: reason
              });

              // Disable Firebase Auth account
              await auth.updateUser(targetUid, { disabled: true });
              break;

            case 'unban_user':
              const unbanUserRef = db.collection('users').doc(targetUid);
              batch.update(unbanUserRef, {
                status: 'active',
                unbannedAt: admin.firestore.FieldValue.serverTimestamp(),
                unbannedBy: context.auth!.uid,
                banReason: admin.firestore.FieldValue.delete()
              });

              // Re-enable Firebase Auth account
              await auth.updateUser(targetUid, { disabled: false });
              break;
          }

          // Log moderation action
          batch.set(moderationRef, {
            action,
            targetUid,
            moderatorUid: context.auth!.uid,
            reason,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            immutable: true
          });

          await batch.commit();

          return { uid: targetUid, success: true };
        } catch (error) {
          return { uid: targetUid, success: false, error: (error as Error).message };
        }
      });

      const batchResults = await Promise.allSettled(batchPromises);
      results.push(...batchResults.map(result => 
        result.status === 'fulfilled' ? result.value : { success: false, error: result.reason }
      ));
    }

    // Log bulk action
    await logAdminAction({
      adminUid: context.auth.uid,
      action: `bulk_moderate_${action}`,
      details: { 
        targetCount: targetUids.length,
        successCount: results.filter(r => r.success).length,
        reason 
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { 
      success: true, 
      results,
      totalProcessed: targetUids.length,
      successCount: results.filter(r => r.success).length
    };

  } catch (error) {
    console.error('Error in bulk moderation:', error);
    throw error;
  }
});