import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { createHash } from 'crypto';

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Referral code generation utilities
const BASE36_CHARS = '23456789ABCDEFGHJKMNPQRSTUVWXYZ'; // Crockford Base32 without ambiguous chars
const REFERRAL_PREFIX = 'TAL';

function generateReferralCode() {
  let code = REFERRAL_PREFIX;
  // Generate 7-8 base36 chars as per spec
  const length = Math.random() < 0.5 ? 7 : 8;
  for (let i = 0; i < length; i++) {
    code += BASE36_CHARS[Math.floor(Math.random() * BASE36_CHARS.length)];
  }
  return code;
}

function isValidReferralCodeFormat(code) {
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
 *
 * data = {
 *   e164, fullName, aliasEmail, pinHashHex,
 *   state, district, mandal, village,
 *   referralCode, simulatePayment: true|false
 * }
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
    if (phoneSnap.exists && phoneSnap.data().uid !== uid) {
      throw new Error('PHONE_ALREADY_CLAIMED');
    }
    tx.set(phoneRef, { uid, claimedAt: FieldValue.serverTimestamp() }, { merge: true });

    // Upsert user doc
    const now = FieldValue.serverTimestamp();
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
  return { exists: true, uid: snap.data().uid };
});

/**
 * createUserRegistry (callable)
 * 
 * data = {
 *   e164, fullName, aliasEmail, pinHashHex,
 *   state, district, mandal, village,
 *   referralCode, simulatePayment (bool),  // set true for web dev
 *   useCollection: "phones" | "registry" | "user_registry"   // defaults to "user_registry"
 * }
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

  const regCol = ['phones','registry','user_registry'].includes(useCollection) ? useCollection : 'user_registry';
  const regRef = db.collection(regCol).doc(e164);
  const userRef = db.collection('users').doc(uid);

  await db.runTransaction(async (tx) => {
    // Claim phone/registry atomically
    const regSnap = await tx.get(regRef);
    if (regSnap.exists && regSnap.data().uid !== uid) {
      throw new Error('PHONE_ALREADY_CLAIMED');
    }
    tx.set(regRef, {
      uid,
      claimedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    // Upsert user
    const now = FieldValue.serverTimestamp();
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
 * reserveReferralCode (callable)
 * 
 * Generates and reserves a unique referral code for the authenticated user.
 * Idempotent: returns existing code if user already has one.
 * 
 * Returns: { code: string }
 */
export const reserveReferralCode = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new Error('UNAUTHENTICATED');

  const userRef = db.collection('users').doc(uid);
  
  try {
    // Check if user already has a referral code
    const userDoc = await userRef.get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      const existingCode = userData.referral?.code || userData.referralCode;
      
      if (existingCode && isValidReferralCodeFormat(existingCode)) {
        logger.info(`User ${uid} already has referral code: ${existingCode}`);
        return { code: existingCode };
      }
    }

    // Generate new code with collision detection
    let attempts = 0;
    const maxAttempts = 10;
    
    while (attempts < maxAttempts) {
      const code = generateReferralCode();
      const codeRef = db.collection('referralCodes').doc(code);
      
      try {
        await db.runTransaction(async (tx) => {
          // Check if code already exists
          const codeDoc = await tx.get(codeRef);
          if (codeDoc.exists) {
            throw new Error('CODE_COLLISION');
          }
          
          // Reserve the code
          tx.set(codeRef, {
            uid,
            reservedAt: FieldValue.serverTimestamp(),
            active: true
          });
          
          // Update user document
          tx.set(userRef, {
            referral: {
              code,
              createdAt: FieldValue.serverTimestamp()
            }
          }, { merge: true });
        });
        
        logger.info(`Reserved referral code ${code} for user ${uid}`);
        return { code };
        
      } catch (error) {
        if (error.message === 'CODE_COLLISION') {
          attempts++;
          continue;
        }
        throw error;
      }
    }
    
    throw new Error('FAILED_TO_GENERATE_UNIQUE_CODE');
    
  } catch (error) {
    logger.error(`Failed to reserve referral code for user ${uid}:`, error);
    throw new Error(`REFERRAL_CODE_RESERVATION_FAILED: ${error.message}`);
  }
});

/**
 * applyReferralCode (callable)
 * 
 * Applies a referral code during registration, linking the new user to the referrer.
 * Idempotent: returns success if the same mapping already exists.
 * 
 * data: { code: string }
 * Returns: { referrerUid: string }
 */
export const applyReferralCode = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new Error('UNAUTHENTICATED');

  const { code } = req.data || {};
  if (!code || !isValidReferralCodeFormat(code)) {
    throw new Error('INVALID_REFERRAL_CODE_FORMAT');
  }

  const normalizedCode = code.toUpperCase().trim();
  
  try {
    const userRef = db.collection('users').doc(uid);
    const codeRef = db.collection('referralCodes').doc(normalizedCode);
    
    // Check if user already has a referral relationship
    const userDoc = await userRef.get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      const existingReferredBy = userData.referral?.referredBy;
      
      if (existingReferredBy) {
        // Already has a referrer - check if it's the same
        const existingCode = userData.referral?.referredByCode;
        if (existingCode === normalizedCode) {
          logger.info(`User ${uid} already referred by code ${normalizedCode}`);
          return { referrerUid: existingReferredBy };
        } else {
          throw new Error('USER_ALREADY_HAS_REFERRER');
        }
      }
    }
    
    // Apply referral code in transaction
    const result = await db.runTransaction(async (tx) => {
      // Look up referral code
      const codeDoc = await tx.get(codeRef);
      if (!codeDoc.exists) {
        throw new Error('REFERRAL_CODE_NOT_FOUND');
      }
      
      const codeData = codeDoc.data();
      if (!codeData.active) {
        throw new Error('REFERRAL_CODE_INACTIVE');
      }
      
      const referrerUid = codeData.uid;
      
      // Prevent self-referrals
      if (referrerUid === uid) {
        throw new Error('SELF_REFERRAL_NOT_ALLOWED');
      }
      
      const referrerRef = db.collection('users').doc(referrerUid);
      const referralRef = db.collection('referrals').doc(referrerUid)
                           .collection('direct').doc(uid);
      
      // Update referee (current user)
      tx.set(userRef, {
        referral: {
          referredBy: referrerUid,
          referredByCode: normalizedCode
        }
      }, { merge: true });
      
      // Create referral relationship record
      tx.set(referralRef, {
        createdAt: FieldValue.serverTimestamp(),
        fromCode: normalizedCode,
        status: 'completed'
      });
      
      // Increment referrer's direct count
      tx.set(referrerRef, {
        referral: {
          directCount: FieldValue.increment(1)
        }
      }, { merge: true });
      
      return { referrerUid };
    });
    
    logger.info(`Applied referral code ${normalizedCode} for user ${uid}, referrer: ${result.referrerUid}`);
    return result;
    
  } catch (error) {
    logger.error(`Failed to apply referral code ${normalizedCode} for user ${uid}:`, error);
    throw new Error(`REFERRAL_APPLICATION_FAILED: ${error.message}`);
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
    
    const userData = userDoc.data();
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
    
  } catch (error) {
    logger.error(`Failed to get referral stats for user ${uid}:`, error);
    throw new Error(`REFERRAL_STATS_FAILED: ${error.message}`);
  }
});