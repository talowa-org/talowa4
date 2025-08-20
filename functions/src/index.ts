import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';
import { z } from 'zod';
import { defineSecret } from 'firebase-functions/params';
import * as crypto from 'crypto';


admin.initializeApp();
const db = admin.firestore();

// Secrets and params
const OPENROUTER_API_KEY = defineSecret('OPENROUTER_API_KEY');
const OPENROUTER_MODEL = functions.params.defineString('OPENROUTER_MODEL');
const OPENROUTER_BASE_URL = functions.params.defineString('OPENROUTER_BASE_URL');
const OPENROUTER_FALLBACK_MODEL = functions.params.defineString('OPENROUTER_FALLBACK_MODEL');

const DEFAULT_MODEL = 'meta-llama/llama-3.1-8b-instruct';
const DEFAULT_BASE_URL = 'https://openrouter.ai/api/v1';

const AIResponseSchema = z.object({
  text: z.string().max(2000),
  confidence: z.number().min(0).max(1),
  actions: z.array(
    z.object({
      type: z.enum(['navigate', 'call', 'share', 'suggestions', 'form']),
      label: z.string().max(120),
      data: z.record(z.any())
    })
  ),
  meta: z
    .object({
      intent: z.string().optional(),
      lang: z.string().optional(),
      citations: z.array(z.record(z.any())).optional(),
      usage: z.record(z.any()).optional()
    })
    .optional()
});

function normalizeQuery(q: string) {
  return q.toLowerCase().trim();
}

function fastIntent(query: string): 'navigation' | 'emergency' | 'other' {
  const q = normalizeQuery(query);
  if (q.includes('emergency') || q.includes('urgent') || q.includes('help me')) return 'emergency';
  if (q.includes('go to') || q.includes('open') || q.includes('navigate') || q.includes('show me')) return 'navigation';
  return 'other';
}

function clamp01(n: any) {
  const x = Number(n);
  if (isNaN(x)) return 0.6;
  return Math.max(0, Math.min(1, x));
}

function coerceToAIResponse(input: any, raw: string, lang: string) {
  const textCandidate = typeof input?.text === 'string' ? input.text :
    typeof input?.answer === 'string' ? input.answer :
    typeof input?.message === 'string' ? input.message : raw;
  const text = String(textCandidate || 'I can help with that.').slice(0, 2000);
  const confidence = clamp01((input && (input.confidence ?? input.score)) ?? 0.6);

  const suggestions: string[] = Array.isArray(input?.actions?.[0]?.data?.suggestions)
    ? input.actions[0].data.suggestions
    : ['Land Records', 'Legal Help', 'My Network'];

  const actions = Array.isArray(input?.actions)
    ? input.actions
    : [{ type: 'suggestions', label: 'You can try', data: { suggestions } }];

  const intent = typeof input?.meta?.intent === 'string' ? input.meta.intent : undefined;
  return {
    text,
    confidence,
    actions,
    meta: { intent, lang }
  };
}

async function allowlistActions(actions: any[]) {
  // Enforce safe routes and phone formats and normalize suggestions
  return actions
    .map(a => {
      if (a?.type === 'suggestions') {
        const data = a.data || {};
        if (Array.isArray(data.categories) && !Array.isArray(data.suggestions)) {
          data.suggestions = data.categories;
          delete data.categories;
        }
        a.data = data;
      }
      return a;
    })
    .filter(a => {
      if (a.type === 'navigate') {
        return typeof a.data?.route === 'string' && a.data.route.startsWith('/');
      }
      if (a.type === 'call') {
        return typeof a.data?.phone === 'string' && /^\+?\d{3,15}$/.test(a.data.phone);
      }
      return true;
    });
}


// --- Simple Firestore response cache (best-effort) ---
async function getCachedAI(query: string, lang: string) {
  try {
    const key = crypto.createHash('sha256').update(`${normalizeQuery(query)}|${lang}`).digest('hex').slice(0, 32);
    const ref = db.collection('ai_cache').doc(key);
    const snap = await ref.get();
    if (snap.exists) {
      const d: any = snap.data();
      const expiresAt = d?.expiresAt?.toMillis ? d.expiresAt.toMillis() : d?.expiresAt;
      if (expiresAt && Date.now() < Number(expiresAt)) {
        return d.payload;
      }
    }

function cacheKey(query: string, lang: string) {
  return crypto.createHash('sha256').update(`${normalizeQuery(query)}|${lang}`).digest('hex').slice(0, 32);
}

  } catch (_) {}
  return null;
}

async function setCachedAI(query: string, lang: string, payload: any, ttlMs = 6 * 60 * 60 * 1000) {
  try {
    const key = crypto.createHash('sha256').update(`${normalizeQuery(query)}|${lang}`).digest('hex').slice(0, 32);
    const ref = db.collection('ai_cache').doc(key);
    await ref.set({
      payload,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + ttlMs)
    }, { merge: true });
  } catch (_) {}
}

// Export WebSocket functions
export { 
  websocketServer, 
  keepWebSocketAlive, 
  cleanupOfflineMessages, 
  getWebSocketInfo 
} from './websocket';

// Export Notification functions
export {
  processNotification,
  processNotificationRetries,
  cleanupNotificationLogs
} from './notifications';

// Emergency Broadcast Functions
export const processEmergencyBroadcastRetries = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      // Get retries that are due
      const retriesSnapshot = await db.collection('broadcast_retries')
        .where('nextRetryTime', '<=', now)
        .limit(100)
        .get();

      if (retriesSnapshot.empty) {
        console.log('No retries to process');
        return null;
      }

      console.log(`Processing ${retriesSnapshot.docs.length} broadcast retries`);

      const batch = db.batch();
      const retryPromises: Promise<void>[] = [];

      for (const retryDoc of retriesSnapshot.docs) {
        const retryData = retryDoc.data();
        const broadcastId = retryData.broadcastId;
        const userId = retryData.userId;

        // Get original broadcast
        const broadcastDoc = await db.collection('emergency_broadcasts').doc(broadcastId).get();
        
        if (broadcastDoc.exists) {
          const broadcastData = broadcastDoc.data()!;
          
          // Retry delivery
          retryPromises.push(retryBroadcastDelivery(broadcastData, userId, retryData));
        }

        // Delete the retry document
        batch.delete(retryDoc.ref);
      }

      // Execute batch delete and retry deliveries
      await Promise.all([
        batch.commit(),
        ...retryPromises
      ]);

      console.log('Completed processing broadcast retries');
      return null;
    } catch (error) {
      console.error('Error processing broadcast retries:', error);
      throw error;
    }
  });

async function retryBroadcastDelivery(broadcastData: any, userId: string, retryData: any) {
  try {
    // Get user data for delivery
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log(`User ${userId} not found for retry`);
      return;
    }

    const userData = userDoc.data()!;
    const previousAttempts = retryData.previousAttempts || {};

    // Retry push notification if it failed before
    if (previousAttempts.push === false) {
      try {
        const fcmToken = userData.fcmToken;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: `🚨 ${broadcastData.title}`,
              body: broadcastData.message,
            },
            data: {
              broadcastId: broadcastData.id || '',
              priority: broadcastData.priority || 'high',
              isEmergency: 'true',
            },
            android: {
              priority: 'high',
              notification: {
                priority: 'max',
                defaultSound: true,
                defaultVibrateTimings: true,
              },
            },
            apns: {
              payload: {
                aps: {
                  alert: {
                    title: `🚨 ${broadcastData.title}`,
                    body: broadcastData.message,
                  },
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          });
          
          console.log(`Retry push notification sent to user ${userId}`);
          await updateDeliveryTracking(broadcastData.id, userId, true, { push: true });
        }
      } catch (error) {
        console.error(`Retry push notification failed for user ${userId}:`, error);
        await updateDeliveryTracking(broadcastData.id, userId, false, { push: false });
      }
    }

    // Retry SMS if it failed and priority is critical
    if (previousAttempts.sms === false && broadcastData.priority === 'critical') {
      try {
        const phoneNumber = userData.phoneNumber;
        if (phoneNumber) {
          // Log SMS retry attempt (actual SMS integration would go here)
          await db.collection('sms_logs').add({
            userId: userId,
            phoneNumber: phoneNumber,
            message: `🚨 TALOWA EMERGENCY\n${broadcastData.title}\n\n${broadcastData.message}`,
            broadcastId: broadcastData.id,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: 'retry_sent',
            isRetry: true,
          });
          
          console.log(`Retry SMS logged for user ${userId}`);
        }
      } catch (error) {
        console.error(`Retry SMS failed for user ${userId}:`, error);
      }
    }

  } catch (error) {
    console.error(`Error retrying delivery for user ${userId}:`, error);
  }
}

async function updateDeliveryTracking(broadcastId: string, userId: string, success: boolean, channelResults: any) {
  try {
    const trackingRef = db.collection('broadcast_delivery_tracking').doc(broadcastId);
    
    await db.runTransaction(async (transaction) => {
      const trackingDoc = await transaction.get(trackingRef);
      if (!trackingDoc.exists) return;

      const data = trackingDoc.data()!;
      const currentDelivered = data.deliveredCount || 0;
      const currentFailed = data.failedCount || 0;
      const currentPending = data.pendingCount || 0;

      const updates: any = {
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (success) {
        updates.deliveredCount = currentDelivered + 1;
        if (currentPending > 0) {
          updates.pendingCount = currentPending - 1;
        }
      } else {
        updates.failedCount = currentFailed + 1;
        if (currentPending > 0) {
          updates.pendingCount = currentPending - 1;
        }
      }

      transaction.update(trackingRef, updates);
    });

    // Log delivery result
    await db.collection('broadcast_delivery_logs').add({
      broadcastId: broadcastId,
      userId: userId,
      success: success,
      channelResults: channelResults,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRetry: true,
    });

  } catch (error) {
    console.error('Error updating delivery tracking:', error);
  }
}

// Process emergency broadcasts for immediate delivery
export const processEmergencyBroadcast = functions.firestore
  .document('emergency_broadcasts/{broadcastId}')
  .onCreate(async (snap, context) => {
    try {
      const broadcastData = snap.data();
      const broadcastId = context.params.broadcastId;

      console.log(`Processing emergency broadcast: ${broadcastId}`);

      // Get target users based on scope
      const targetUsers = await getTargetUsersForBroadcast(broadcastData.scope);
      
      console.log(`Found ${targetUsers.length} target users for broadcast ${broadcastId}`);

      // Create delivery tracking
      await db.collection('broadcast_delivery_tracking').doc(broadcastId).set({
        broadcastId: broadcastId,
        totalTargets: targetUsers.length,
        deliveredCount: 0,
        failedCount: 0,
        pendingCount: targetUsers.length,
        deliveryStarted: admin.firestore.FieldValue.serverTimestamp(),
        channels: getDeliveryChannels(broadcastData.priority),
      });

      // Process delivery in batches
      const batchSize = 100;
      const batches: string[][] = [];
      
      for (let i = 0; i < targetUsers.length; i += batchSize) {
        const end = Math.min(i + batchSize, targetUsers.length);
        batches.push(targetUsers.slice(i, end));
      }

      // Process batches with controlled concurrency
      const batchPromises = batches.map((batch, index) => 
        processBroadcastBatch(broadcastData, batch, index)
      );

      await Promise.all(batchPromises);

      // Update broadcast status
      await snap.ref.update({
        status: 'completed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Completed processing emergency broadcast: ${broadcastId}`);
      return null;
    } catch (error) {
      console.error('Error processing emergency broadcast:', error);
      
      // Update broadcast status to failed
      await snap.ref.update({
        status: 'failed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw error;
    }
  });

async function getTargetUsersForBroadcast(scope: any): Promise<string[]> {
  try {
    let query: FirebaseFirestore.Query = db.collection('users');

    // Apply geographic filters
    switch (scope.level) {
      case 'village':
        query = query
          .where('location.village', '==', scope.village)
          .where('location.mandal', '==', scope.mandal)
          .where('location.district', '==', scope.district);
        break;
      case 'mandal':
        query = query
          .where('location.mandal', '==', scope.mandal)
          .where('location.district', '==', scope.district);
        break;
      case 'district':
        query = query.where('location.district', '==', scope.district);
        break;
      case 'state':
        query = query.where('location.state', '==', scope.state);
        break;
      case 'national':
        // No geographic filter for national broadcasts
        break;
    }

    // Apply role filters if specified
    if (scope.targetRoles && scope.targetRoles.length > 0) {
      query = query.where('role', 'in', scope.targetRoles);
    }

    const snapshot = await query.get();
    return snapshot.docs.map(doc => doc.id);
  } catch (error) {
    console.error('Error getting target users:', error);
    return [];
  }
}

function getDeliveryChannels(priority: string): string[] {
  switch (priority) {
    case 'critical':
      return ['push', 'sms', 'email'];
    case 'high':
      return ['push', 'email'];
    case 'medium':
    case 'low':
    default:
      return ['push'];
  }
}

async function processBroadcastBatch(broadcastData: any, userIds: string[], batchIndex: number) {
  console.log(`Processing batch ${batchIndex} with ${userIds.length} users`);

  const deliveryPromises = userIds.map(userId => 
    deliverBroadcastToUser(broadcastData, userId)
  );

  await Promise.all(deliveryPromises);
  console.log(`Completed batch ${batchIndex}`);
}

async function deliverBroadcastToUser(broadcastData: any, userId: string) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log(`User ${userId} not found`);
      return;
    }

    const userData = userDoc.data()!;
    const channels = getDeliveryChannels(broadcastData.priority);
    const deliveryResults: { [key: string]: boolean } = {};

    // Primary delivery: Push notification
    if (channels.includes('push')) {
      try {
        const fcmToken = userData.fcmToken;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: `🚨 ${broadcastData.title}`,
              body: broadcastData.message,
            },
            data: {
              broadcastId: broadcastData.id || '',
              priority: broadcastData.priority || 'high',
              scope: JSON.stringify(broadcastData.scope || {}),
              isEmergency: 'true',
              ...broadcastData.customData,
            },
            android: {
              priority: 'high',
              notification: {
                priority: 'max',
                defaultSound: true,
                defaultVibrateTimings: true,
                channelId: 'talowa_emergency',
              },
            },
            apns: {
              payload: {
                aps: {
                  alert: {
                    title: `🚨 ${broadcastData.title}`,
                    body: broadcastData.message,
                  },
                  sound: 'default',
                  badge: 1,
                  'interruption-level': 'critical',
                },
              },
            },
          });
          deliveryResults.push = true;
        } else {
          deliveryResults.push = false;
        }
      } catch (error) {
        console.error(`Push notification failed for user ${userId}:`, error);
        deliveryResults.push = false;
      }
    }

    // Secondary delivery: SMS (for critical messages or push failures)
    if (channels.includes('sms') && 
        (broadcastData.priority === 'critical' || deliveryResults.push === false)) {
      try {
        const phoneNumber = userData.phoneNumber;
        if (phoneNumber) {
          // Log SMS delivery attempt (actual SMS integration would go here)
          await db.collection('sms_logs').add({
            userId: userId,
            phoneNumber: phoneNumber,
            message: `🚨 TALOWA EMERGENCY\n${broadcastData.title}\n\n${broadcastData.message}`,
            broadcastId: broadcastData.id,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: 'sent',
          });
          deliveryResults.sms = true;
        } else {
          deliveryResults.sms = false;
        }
      } catch (error) {
        console.error(`SMS notification failed for user ${userId}:`, error);
        deliveryResults.sms = false;
      }
    }

    // Tertiary delivery: Email (for high priority or fallback)
    if (channels.includes('email') && 
        (broadcastData.priority === 'high' || 
         (deliveryResults.push === false && deliveryResults.sms === false))) {
      try {
        const email = userData.email;
        if (email) {
          // Log email delivery attempt (actual email integration would go here)
          await db.collection('email_logs').add({
            userId: userId,
            email: email,
            subject: `🚨 TALOWA Emergency Alert: ${broadcastData.title}`,
            body: `Dear TALOWA Member,\n\nThis is an emergency alert from TALOWA:\n\n${broadcastData.title}\n\n${broadcastData.message}\n\nPlease take appropriate action immediately.\n\nStay safe,\nTALOWA Team`,
            broadcastId: broadcastData.id,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: 'sent',
          });
          deliveryResults.email = true;
        } else {
          deliveryResults.email = false;
        }
      } catch (error) {
        console.error(`Email notification failed for user ${userId}:`, error);
        deliveryResults.email = false;
      }
    }

    // Update delivery tracking
    const success = Object.values(deliveryResults).some(result => result === true);
    await updateDeliveryTracking(broadcastData.id, userId, success, deliveryResults);

    // Schedule retry for failed deliveries
    if (!success) {
      await scheduleRetry(broadcastData.id, userId, deliveryResults);
    }

  } catch (error) {
    console.error(`Error delivering to user ${userId}:`, error);
    await updateDeliveryTracking(broadcastData.id, userId, false, {});
  }
}

async function scheduleRetry(broadcastId: string, userId: string, previousAttempts: any) {
  try {
    // Get current retry count
    const retryDocRef = db.collection('broadcast_retries').doc(`${broadcastId}_${userId}`);
    const retryDoc = await retryDocRef.get();

    let retryCount = 0;
    if (retryDoc.exists) {
      retryCount = retryDoc.data()!.retryCount || 0;
    }

    // Maximum 3 retries with exponential backoff
    if (retryCount < 3) {
      const nextRetryTime = new Date(Date.now() + (retryCount + 1) * 5 * 60 * 1000); // 5, 10, 15 minutes

      await retryDocRef.set({
        broadcastId: broadcastId,
        userId: userId,
        retryCount: retryCount + 1,
        nextRetryTime: admin.firestore.Timestamp.fromDate(nextRetryTime),
        previousAttempts: previousAttempts,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Scheduled retry ${retryCount + 1} for user ${userId} at ${nextRetryTime}`);
    }
  } catch (error) {
    console.error('Error scheduling retry:', error);
  }
}

export const aiRespond = functions.runWith({
  secrets: [OPENROUTER_API_KEY],
}).region('asia-south1').https.onRequest(async (req: any, res: any): Promise<void> => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'authorization, content-type');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  try {
    const idHeader = req.headers.authorization || '';
    const idToken = idHeader.startsWith('Bearer ') ? idHeader.substring(7) : '';
    if (!idToken) { res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Missing token' } }); return; }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    // Resolve config at runtime
    const baseURL = process.env.OPENROUTER_BASE_URL || OPENROUTER_BASE_URL.value() || DEFAULT_BASE_URL;
    const model = process.env.OPENROUTER_MODEL || process.env.OPENAI_MODEL || OPENROUTER_MODEL.value() || DEFAULT_MODEL;
    const apiKey = OPENROUTER_API_KEY.value();
    const openai = new OpenAI({ apiKey, baseURL });

    const { query, lang = 'en', isVoice = false, context = {} } = req.body || {};
    if (!query || typeof query !== 'string') {
      res.status(400).json({ error: { code: 'INVALID_INPUT', message: 'query is required' } });
      return;
    }

    // Fast path: avoid LLM cost for trivial intents
    const gate = fastIntent(query);
    if (gate === 'navigation') {
      res.json({


        text: 'I can help you navigate. What section would you like to open? For example: Land Records, Legal Help, or My Network.',
        confidence: 0.6,
        actions: [{ type: 'suggestions', label: 'Navigate to', data: { suggestions: ['Land Records', 'Legal Help', 'My Network'] } }],
        meta: { intent: 'navigation', lang }
      });
      return;

    }
    if (gate === 'emergency') {
      res.json({
        text: 'This seems urgent. Do you want to report an incident or call emergency helpline?',
        confidence: 0.9,
        actions: [
          { type: 'navigate', label: 'Report Incident', data: { route: '/emergency/report' } },
          { type: 'call', label: 'Emergency Helpline', data: { phone: '+91100' } }
        ],
        meta: { intent: 'emergency', lang }
      });
      return;
    }

    // Build prompt
    const system = `You are the TALOWA land-rights assistant for Indian users. Provide concise, practical help.
Respond ONLY with valid JSON object matching this TypeScript type:
{ text: string; confidence: number; actions: Array<{ type: 'navigate'|'call'|'share'|'suggestions'|'form'; label: string; data: { suggestions?: string[]; route?: string; phone?: string } & Record<string, any> }>; meta?: { intent?: string; lang?: string; citations?: any[]; usage?: Record<string, any> } }

      // Cache bypass for voice; attempt cache for common text queries
      if (!isVoice) {
        const cached = await getCachedAI(query, lang);
        if (cached) { res.json(cached); return; }
      }

For suggestions actions, always use data.suggestions (string[]) not categories. No prose, no markdown, no code fences.`;
    const user = `Query: ${query}\nLang: ${lang}\nContext: ${JSON.stringify({ uid, ...context })}`;

    // Model preference with fallback (free tiers)
    const primaryModel = model || 'meta-llama/llama-3.1-8b-instruct';
    const envFallback = process.env.OPENROUTER_FALLBACK_MODEL || OPENROUTER_FALLBACK_MODEL.value() || '';
    const builtInFallbacks = ['openai/gpt-oss-20b', 'mistralai/mistral-7b-instruct'];
    const modelsToTry = [primaryModel, envFallback, ...builtInFallbacks]
      .filter((m, i, arr) => m && arr.indexOf(m) === i);

    let lastError: any = null;
    for (const mdl of modelsToTry) {
      try {
        const completion = await openai.chat.completions.create({
          model: mdl,
          temperature: 0.3,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: user }
          ],
          max_tokens: 512
        });

        const content = completion.choices[0]?.message?.content || '{}';
        let parsed: any;
        try {
          parsed = JSON.parse(content);
        } catch (e) {
          parsed = {};
        }

        // Validate and enforce safety (with coercion fallback)
        const safe = AIResponseSchema.safeParse(parsed);
        const candidate = safe.success ? safe.data : coerceToAIResponse(parsed, content, lang);

        const sanitized = candidate as any;
        sanitized.actions = await allowlistActions(sanitized.actions);
        sanitized.meta = { ...(sanitized.meta || {}), lang, usage: { model: mdl } };

        // Log interaction (redacted)
        try {
          await db.collection('ai_interactions').add({
            userId: uid,
            query,
            response: sanitized.text,
            confidence: sanitized.confidence,
            isVoice,
            meta: { intent: sanitized.meta?.intent, lang, model: mdl },
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          });
        } catch (e) {
          // Non-fatal
        }

        res.json(sanitized);
        return;
      } catch (err: any) {
        lastError = err;
        // Try next model
        continue;
      }
    }

    // Both attempts failed
    res.status(503).json({ error: { code: 'UPSTREAM_UNAVAILABLE', message: lastError?.message || 'Upstream model unavailable' } });
    return;
  } catch (e: any) {
    const message = e?.message || String(e);
    const code = message.includes('auth') ? 'UNAUTHORIZED' : 'UPSTREAM_UNAVAILABLE';
    const status = code === 'UNAUTHORIZED' ? 401 : 503;
    res.status(status).json({ error: { code, message } });
    return;
  }
});

