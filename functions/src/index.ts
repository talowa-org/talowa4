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

// Export existing functions (if any)
// Add your production-ready functions here