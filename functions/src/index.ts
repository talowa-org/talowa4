import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';
import { z } from 'zod';

admin.initializeApp();
const db = admin.firestore();

const openaiApiKey = process.env.OPENAI_API_KEY || functions.params.defineString('OPENAI_API_KEY').value();
const model = process.env.OPENAI_MODEL || 'gpt-5';
const openai = new OpenAI({ apiKey: openaiApiKey });

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

async function allowlistActions(actions: any[]) {
  // Enforce safe routes and phone formats
  return actions.filter(a => {
    if (a.type === 'navigate') {
      return typeof a.data?.route === 'string' && a.data.route.startsWith('/');
    }
    if (a.type === 'call') {
      return typeof a.data?.phone === 'string' && /^\+?\d{3,15}$/.test(a.data.phone);
    }
    return true;
  });
}

export const aiRespond = functions.region('asia-south1').https.onRequest(async (req, res): Promise<void> => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'authorization, content-type');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  try {
    const idHeader = req.headers.authorization || '';
    const idToken = idHeader.startsWith('Bearer ') ? idHeader.substring(7) : '';
    if (!idToken) { res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Missing token' } }); return; }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const { query, lang = 'en', isVoice = false, context = {}, client = {} } = req.body || {};
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
    const system = `You are the TALOWA land-rights assistant for Indian users. Provide concise, practical help. If unsure, say so and suggest human/legal support. Output STRICT JSON matching AIResponse schema.`;
    const user = `Query: ${query}\nLang: ${lang}\nContext: ${JSON.stringify({ uid, ...context })}`;

    // Call GPT-5
    const completion = await openai.chat.completions.create({
      model,
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
    } catch {
      res.status(502).json({ error: { code: 'UPSTREAM_UNAVAILABLE', message: 'Invalid JSON from model' } });
      return;
    }

    // Validate and enforce safety
    const safe = AIResponseSchema.safeParse(parsed);
    if (!safe.success) {
      res.status(502).json({ error: { code: 'UPSTREAM_UNAVAILABLE', message: 'Schema validation failed', details: safe.error.flatten() } });
      return;
    }

    const sanitized = safe.data;
    sanitized.actions = await allowlistActions(sanitized.actions);

    // Log interaction (redacted)
    try {
      await db.collection('ai_interactions').add({
        userId: uid,
        query,
        response: sanitized.text,
        confidence: sanitized.confidence,
        isVoice,
        meta: { intent: sanitized.meta?.intent, lang },
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (e) {
      // Non-fatal
    }

    res.json(sanitized);
    return;
  } catch (e: any) {
    const message = e?.message || String(e);
    const code = message.includes('auth') ? 'UNAUTHORIZED' : 'UPSTREAM_UNAVAILABLE';
    const status = code === 'UNAUTHORIZED' ? 401 : 503;
    res.status(status).json({ error: { code, message } });
    return;
  }
});

