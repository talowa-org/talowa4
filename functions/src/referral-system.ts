/**
 * Talowa Referral System Cloud Functions
 * Adapted from BSS webapp referral system
 * Handles automatic referral chain updates and role promotions
 */

import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Talowa Role Thresholds (Complete 9-level hierarchy)
const TALOWA_ROLE_THRESHOLDS = [
  { level: 9, name: "State Coordinator", direct: 1000, team: 3000000 },
  { level: 8, name: "Zonal Coordinator", direct: 500, team: 1000000 },
  { level: 7, name: "District Coordinator", direct: 320, team: 500000 },
  { level: 6, name: "Constituency Coordinator", direct: 160, team: 50000 },
  { level: 5, name: "Mandal Coordinator", direct: 80, team: 6000 },
  { level: 4, name: "Area Coordinator", direct: 40, team: 700 },
  { level: 3, name: "Team Leader", direct: 20, team: 100 },
  { level: 2, name: "Active Member", direct: 10, team: 10 },
  { level: 1, name: "Member", direct: 0, team: 0 },
];

/**
 * Process referral chain for a user (callable function)
 * Adapted from BSS processReferral function
 */
export const processReferral = onCall(async (request) => {
  const { userId } = request.data;
  if (!userId) {
    throw new Error('userId is required');
  }

  const newUserDocRef = db.collection('users').doc(userId);
  const userDoc = await newUserDocRef.get();
  
  if (!userDoc.exists) {
    throw new Error('User not found');
  }

  const newUser = userDoc.data()!;
  let referredByCode = newUser.referredBy;

  logger.log(`🔍 PROCESSING REFERRAL DEBUG:`);
  logger.log(`   User: ${newUser.fullName} (${userId})`);
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
      throw error;
    }
  }

  return { success: true, message: 'Referral processed successfully' };
});

/**
 * Auto-promote users based on their referral stats (callable function)
 * Adapted from BSS autoPromoteUser function
 */
export const autoPromoteUser = onCall(async (request) => {
  const { userId } = request.data;
  if (!userId) {
    throw new Error('userId is required');
  }

  const userDocRef = db.collection('users').doc(userId);
  const userDoc = await userDocRef.get();
  
  if (!userDoc.exists) {
    throw new Error('User not found');
  }

  const userData = userDoc.data()!;

  // Skip admin users from promotions
  if (userData.currentRoleLevel === 0 || userData.role === 'Admin') {
    return { success: false, message: 'Admin users cannot be promoted' };
  }

  const { directReferrals, teamReferrals, currentRoleLevel } = userData;

  let newRole = { level: 1, name: "Member" }; // Default role

  // Find the highest eligible role (thresholds are in descending order)
  for (const role of TALOWA_ROLE_THRESHOLDS) {
    const meetsDirect = directReferrals >= role.direct;
    const meetsTeam = teamReferrals >= role.team;

    // Check if user meets requirements for this role and it's higher than current
    if (meetsDirect && meetsTeam && role.level > currentRoleLevel) {
      newRole = role;
      break; // Found the highest eligible role
    }
  }

  // If the user's role has changed, update their document
  if (newRole.level > currentRoleLevel) {
    logger.log(`Promoting user ${userId} from level ${currentRoleLevel} to ${newRole.level} (${newRole.name}).`);
    
    await userDocRef.update({
      currentRoleLevel: newRole.level,
      role: newRole.name,
      lastRoleUpdate: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send promotion notification
    try {
      await sendPromotionNotification(userId, userData.fullName, newRole.name);
    } catch (error) {
      logger.warn('Failed to send promotion notification:', error);
      // Don't throw - promotion should still succeed even if notification fails
    }

    return { success: true, message: `Promoted to ${newRole.name}`, newRole: newRole.name };
  }

  return { success: false, message: 'No promotion needed', currentRole: userData.role };
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
 * Callable function for admin use
 */
export const fixOrphanedUsers = onCall(async (request) => {
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
      return { success: true, message: `Fixed ${updateCount} orphaned users` };
    }

    return { success: true, message: 'No orphaned users found' };

  } catch (error) {
    logger.error('❌ Error fixing orphaned users:', error);
    throw error;
  }
});

// Referral code generation utilities - using inline generation

function isValidReferralCodeFormat(code: string): boolean {
  if (!code || typeof code !== 'string') return false;
  const normalized = code.toUpperCase().trim();
  return /^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{7,8}$/.test(normalized);
}

/**
 * registerUserProfile (callable)
 *
 * - Idempotently creates/updates users/{uid}
 * - Atomically claims phones/{e164} -> { uid }
 * - Optionally simulates payment (membershipPaid=true)
 */
export const registerUserProfile = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new Error('UNAUTHENTICATED');

  const {
    e164, fullName, aliasEmail, pinHashHex,
    state, district, mandal, village,
    referralCode, simulatePayment = true
  } = req.data || {};

  if (!e164 || !pinHashHex) throw new Error('INVALID_ARGUMENT');

  const userRef = db.collection('users').doc(uid);
  const phoneRef = db.collection('phones').doc(e164);

  await db.runTransaction(async (tx) => {
    // Claim phone
    const phoneSnap = await tx.get(phoneRef);
    if (phoneSnap.exists && phoneSnap.data()?.uid !== uid) {
      throw new Error('PHONE_ALREADY_CLAIMED');
    }
    tx.set(phoneRef, { uid, claimedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

    // Upsert user doc
    const now = admin.firestore.FieldValue.serverTimestamp();
    const userData = {
      uid,
      phoneE164: e164,
      aliasEmail: aliasEmail || null,
      fullName: fullName || null,
      state: state || null,
      district: district || null,
      mandal: mandal || null,
      village: village || null,
      role: 'member',
      active: true,
      createdAt: now,
      updatedAt: now,
      referralChain: {
        referralCode: referralCode || null,
        referredBy: null
      },
      directReferrals: {
        count: 0
      },
      security: {
        pinHash: pinHashHex  // hash only
      },
      payment: simulatePayment ? {
        amount: 100,
        currency: 'INR',
        provider: 'web_simulation',
        reference: `web_sim_${Date.now()}`,
        status: 'success',
        paidAt: now
      } : {
        status: 'pending'
      },
      membershipPaid: !!simulatePayment
    };
    tx.set(userRef, userData, { merge: true });
  });

  logger.info(`User ${uid} registered with ${e164}`);
  return { ok: true };
});

/**
 * checkPhone (callable)
 * Returns { exists: boolean, uid?: string }
 */
export const checkPhone = onCall(async (req) => {
  const e164 = req.data?.e164;
  if (!e164) throw new Error('INVALID_ARGUMENT');
  const snap = await db.collection('phones').doc(e164).get();
  if (!snap.exists) return { exists: false };
  return { exists: true, uid: snap.data()?.uid };
});

/**
 * createUserRegistry (callable)
 */
export const createUserRegistry = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new Error('UNAUTHENTICATED');

  const {
    e164, fullName, aliasEmail, pinHashHex,
    state, district, mandal, village,
    referralCode, simulatePayment = true,
    useCollection = 'user_registry'
  } = req.data || {};

  if (!e164 || !pinHashHex) throw new Error('INVALID_ARGUMENT');

  const regCol = ['phones', 'registry', 'user_registry'].includes(useCollection) ? useCollection : 'user_registry';
  const regRef = db.collection(regCol).doc(e164);
  const userRef = db.collection('users').doc(uid);

  await db.runTransaction(async (tx) => {
    // Claim phone/registry atomically
    const regSnap = await tx.get(regRef);
    if (regSnap.exists && regSnap.data()?.uid !== uid) {
      throw new Error('PHONE_ALREADY_CLAIMED');
    }
    tx.set(regRef, {
      uid,
      claimedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // Upsert user
    const now = admin.firestore.FieldValue.serverTimestamp();
    tx.set(userRef, {
      uid,
      phoneE164: e164,
      aliasEmail: aliasEmail ?? null,
      fullName: fullName ?? null,
      state: state ?? null,
      district: district ?? null,
      mandal: mandal ?? null,
      village: village ?? null,
      role: 'member',
      active: true,
      membershipPaid: !!simulatePayment,
      payment: simulatePayment ? {
        amount: 100,
        currency: 'INR',
        provider: 'web_simulation',
        reference: `web_sim_${Date.now()}`,
        status: 'success',
        paidAt: now
      } : { status: 'pending' },
      referralChain: {
        referralCode: referralCode ?? null,
        referredBy: null
      },
      directReferrals: { count: 0 },
      security: { pinHash: pinHashHex },
      updatedAt: now,
      createdAt: now
    }, { merge: true });
  });

  logger.info(`Registry created for ${e164} by uid=${uid} in ${useCollection}`);
  return { ok: true, registry: useCollection };
});

/**
 * ensureReferralCode (callable)
 * 
 * SINGLE SOURCE OF TRUTH for referral code generation.
 * Generates referral code and writes to BOTH users and user_registry collections.
 * Uses user_registry as primary source, users as mirror.
 * 
 * Returns: { code: string }
 */
export const ensureReferralCode = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new Error('UNAUTHENTICATED');

  try {
    // Step 1: Find user's phone number from users collection
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw new Error('USER_NOT_FOUND');
    }

    const userData = userDoc.data()!;
    const phoneE164 = userData.phoneE164 || userData.phone;
    
    if (!phoneE164) {
      throw new Error('PHONE_NOT_FOUND_IN_USER_PROFILE');
    }

    // Step 2: Check user_registry (PRIMARY SOURCE) for existing referral code
    const registryRef = db.collection('user_registry').doc(phoneE164);
    const registryDoc = await registryRef.get();
    
    if (registryDoc.exists) {
      const registryData = registryDoc.data()!;
      const existingCode = registryData.referralCode;
      
      if (existingCode && isValidReferralCodeFormat(existingCode)) {
        logger.info(`User ${uid} already has referral code in registry: ${existingCode}`);
        
        // Ensure users collection mirrors the same code
        const userReferralCode = userData.referralCode;
        if (userReferralCode !== existingCode) {
          await userRef.update({ referralCode: existingCode });
          logger.info(`Synced users collection with registry code: ${existingCode}`);
        }
        
        return { code: existingCode };
      }
    }

    // Step 3: Generate new referral code (SINGLE GENERATION POINT)
    let code: string = '';
    let exists = true;
    let attempts = 0;
    const maxAttempts = 10;

    while (exists && attempts < maxAttempts) {
      code = "TAL" + Math.random().toString(36).substring(2, 8).toUpperCase();
      const codeSnap = await db.collection('referralCodes').doc(code).get();
      exists = codeSnap.exists;
      attempts++;
    }

    if (attempts >= maxAttempts || !code) {
      throw new Error('FAILED_TO_GENERATE_UNIQUE_CODE');
    }

    // Step 4: Atomic write to ALL collections (CONSISTENCY GUARANTEE)
    await db.runTransaction(async (tx) => {
      // Reserve the code
      tx.set(db.collection('referralCodes').doc(code), {
        uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Write to user_registry (PRIMARY SOURCE)
      tx.set(registryRef, { 
        referralCode: code 
      }, { merge: true });

      // Mirror to users collection
      tx.set(userRef, { 
        referralCode: code 
      }, { merge: true });
    });

    logger.info(`Generated and reserved referral code ${code} for user ${uid}`);
    return { code };

  } catch (error: any) {
    logger.error(`Failed to ensure referral code for user ${uid}:`, error);
    throw new Error(`REFERRAL_CODE_GENERATION_FAILED: ${error.message}`);
  }
});

/**
 * fixReferralCodeConsistency (callable)
 * 
 * Fixes referral code mismatches for a single user.
 * Uses user_registry as source of truth, mirrors to users collection.
 * 
 * Returns: { fixed: boolean, message: string }
 */
export const fixReferralCodeConsistency = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new Error('UNAUTHENTICATED');

  try {
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new Error('USER_NOT_FOUND');
    }

    const userData = userDoc.data()!;
    const phoneE164 = userData.phoneE164 || userData.phone;
    
    if (!phoneE164) {
      throw new Error('PHONE_NOT_FOUND');
    }

    const registryRef = db.collection('user_registry').doc(phoneE164);
    const registryDoc = await registryRef.get();

    if (!registryDoc.exists) {
      logger.warn(`User registry not found for ${phoneE164}`);
      return { fixed: false, message: 'User registry not found' };
    }

    const registryData = registryDoc.data()!;
    const registryReferralCode = registryData.referralCode;
    const userReferralCode = userData.referralCode;

    // Check if codes match
    if (userReferralCode === registryReferralCode && registryReferralCode) {
      return { fixed: false, message: 'Referral codes already match' };
    }

    // Use user_registry as source of truth
    if (registryReferralCode && isValidReferralCodeFormat(registryReferralCode)) {
      // Registry has valid code, mirror to users
      await userRef.update({ referralCode: registryReferralCode });
      logger.info(`Fixed consistency for ${uid}: mirrored registry code ${registryReferralCode} to users`);
      return { 
        fixed: true, 
        message: `Synced user referral code to ${registryReferralCode}` 
      };
    } else if (userReferralCode && isValidReferralCodeFormat(userReferralCode)) {
      // Users has valid code, update registry
      await registryRef.update({ referralCode: userReferralCode });
      logger.info(`Fixed consistency for ${uid}: updated registry with users code ${userReferralCode}`);
      return { 
        fixed: true, 
        message: `Updated registry referral code to ${userReferralCode}` 
      };
    } else {
      // Neither has valid code, generate new one
      let code: string;
      let exists = true;
      let attempts = 0;

      while (exists && attempts < 10) {
        code = "TAL" + Math.random().toString(36).substring(2, 8).toUpperCase();
        const codeSnap = await db.collection('referralCodes').doc(code).get();
        exists = codeSnap.exists;
        attempts++;
      }

      if (attempts >= 10) {
        throw new Error('FAILED_TO_GENERATE_UNIQUE_CODE');
      }

      // Atomic update to both collections
      await db.runTransaction(async (tx) => {
        tx.set(db.collection('referralCodes').doc(code!), {
          uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        tx.update(registryRef, { referralCode: code! });
        tx.update(userRef, { referralCode: code! });
      });

      logger.info(`Generated new referral code for ${uid}: ${code!}`);
      return { 
        fixed: true, 
        message: `Generated new referral code: ${code!}` 
      };
    }

  } catch (error: any) {
    logger.error(`Failed to fix referral code consistency for user ${uid}:`, error);
    throw new Error(`CONSISTENCY_FIX_FAILED: ${error.message}`);
  }
});

/**
 * bulkFixReferralConsistency (callable)
 * 
 * ADMIN ONLY: Fixes referral code mismatches for ALL users.
 * Uses user_registry as source of truth.
 * 
 * Returns: { fixed: number, errors: number, total: number }
 */
export const bulkFixReferralConsistency = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new Error('UNAUTHENTICATED');

  // Check if user is admin (you can implement your own admin check)
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists || userDoc.data()?.role !== 'admin') {
    throw new Error('ADMIN_REQUIRED');
  }

  try {
    logger.info('Starting bulk referral code consistency fix...');
    
    let fixedCount = 0;
    let errorCount = 0;
    let totalCount = 0;

    // Get all users
    const usersSnapshot = await db.collection('users').get();
    totalCount = usersSnapshot.docs.length;

    for (const userDoc of usersSnapshot.docs) {
      try {
        const userData = userDoc.data();
        const userUid = userDoc.id;
        const phoneE164 = userData.phoneE164 || userData.phone;
        
        if (!phoneE164) {
          logger.warn(`User ${userUid} has no phone number, skipping`);
          continue;
        }

        const registryDoc = await db.collection('user_registry').doc(phoneE164).get();
        
        if (!registryDoc.exists) {
          logger.warn(`No registry found for ${phoneE164}, skipping`);
          continue;
        }

        const registryData = registryDoc.data()!;
        const registryCode = registryData.referralCode;
        const userCode = userData.referralCode;

        // Skip if already consistent
        if (registryCode === userCode && registryCode) {
          continue;
        }

        // Fix the mismatch
        if (registryCode && isValidReferralCodeFormat(registryCode)) {
          // Use registry as source of truth
          await userDoc.ref.update({ referralCode: registryCode });
          logger.info(`Fixed ${userUid}: synced to registry code ${registryCode}`);
          fixedCount++;
        } else if (userCode && isValidReferralCodeFormat(userCode)) {
          // Use user code as fallback
          await registryDoc.ref.update({ referralCode: userCode });
          logger.info(`Fixed ${userUid}: updated registry with user code ${userCode}`);
          fixedCount++;
        } else {
          // Generate new code for both
          let newCode: string;
          let exists = true;
          let attempts = 0;

          while (exists && attempts < 10) {
            newCode = "TAL" + Math.random().toString(36).substring(2, 8).toUpperCase();
            const codeSnap = await db.collection('referralCodes').doc(newCode).get();
            exists = codeSnap.exists;
            attempts++;
          }

          if (attempts < 10) {
            await db.runTransaction(async (tx) => {
              tx.set(db.collection('referralCodes').doc(newCode!), {
                uid: userUid,
                createdAt: admin.firestore.FieldValue.serverTimestamp()
              });
              tx.update(userDoc.ref, { referralCode: newCode! });
              tx.update(registryDoc.ref, { referralCode: newCode! });
            });
            logger.info(`Generated new code for ${userUid}: ${newCode!}`);
            fixedCount++;
          } else {
            logger.error(`Failed to generate unique code for ${userUid}`);
            errorCount++;
          }
        }

      } catch (error) {
        logger.error(`Error fixing user ${userDoc.id}:`, error);
        errorCount++;
      }
    }

    logger.info(`Bulk fix completed: ${fixedCount} fixed, ${errorCount} errors, ${totalCount} total`);
    
    return {
      fixed: fixedCount,
      errors: errorCount,
      total: totalCount,
      message: `Fixed ${fixedCount} users, ${errorCount} errors out of ${totalCount} total`
    };

  } catch (error: any) {
    logger.error('Bulk fix failed:', error);
    throw new Error(`BULK_FIX_FAILED: ${error.message}`);
  }
});

/**
 * getMyReferralStats (callable)
 * 
 * Returns the user's referral statistics and recent referrals.
 * 
 * Returns: { 
 *   code: string, 
 *   directCount: number, 
 *   recentReferrals: Array<{uid, createdAt, fromCode}> 
 * }
 */
export const getMyReferralStats = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new Error('UNAUTHENTICATED');

  try {
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new Error('USER_NOT_FOUND');
    }

    const userData = userDoc.data()!;
    const referralData = userData.referral || {};

    const code = referralData.code || null;
    const directCount = referralData.directCount || 0;

    // Get recent referrals (last 20)
    const referralsQuery = db.collection('referrals').doc(uid)
      .collection('direct')
      .orderBy('createdAt', 'desc')
      .limit(20);

    const referralsSnapshot = await referralsQuery.get();
    const recentReferrals = referralsSnapshot.docs.map(doc => ({
      uid: doc.id,
      ...doc.data()
    }));

    logger.info(`Retrieved referral stats for user ${uid}: ${directCount} direct referrals`);

    return {
      code,
      directCount,
      recentReferrals
    };

  } catch (error: any) {
    logger.error(`Failed to get referral stats for user ${uid}:`, error);
    throw new Error(`REFERRAL_STATS_FAILED: ${error.message}`);
  }
});