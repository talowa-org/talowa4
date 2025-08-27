import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

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