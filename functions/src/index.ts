// functions/src/index.ts
import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export referral system functions
export { 
  processReferral, 
  autoPromoteUser, 
  fixOrphanedUsers,
  ensureReferralCode,
  fixReferralCodeConsistency,
  bulkFixReferralConsistency,
  getMyReferralStats,
  registerUserProfile,
  checkPhone,
  createUserRegistry
} from './referral-system';

// Export admin system functions
export {
  assignAdminRole,
  revokeAdminRole,
  logAdminAction,
  flagSuspiciousReferrals,
  sendAdminAlert,
  validateAdminAccess,
  getAdminAuditLogs,
  moderateContent,
  bulkModerateUsers
} from './admin-system';

// Export notification system functions
export {
  processNotificationQueue,
  sendWelcomeNotification,
  sendReferralNotification,
  sendSocialNotification,
  sendCampaignNotification,
  sendEmergencyAlert
} from './notifications';

// Export automatic role promotion functions
export {
  automaticRolePromotion,
  triggerRolePromotionCheck
} from './automatic-role-promotion';