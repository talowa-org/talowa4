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

export const aiRespond = functions.runWith({
  secrets: [OPENROUTER_API_KEY],
}).region('asia-south1').https.onRequest(async (req, res): Promise<void> => {
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

