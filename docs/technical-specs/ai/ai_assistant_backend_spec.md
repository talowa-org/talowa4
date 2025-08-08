# TALOWA AI Assistant Backend (GPT‑5) — Technical Spec

## Overview
This document specifies the server API and client integration to power the TALOWA AI Assistant using OpenAI GPT‑5. It adds a robust, scalable, and cost‑controlled backend with optional RAG (retrieval‑augmented generation) and strict safety.

- Provider: OpenAI GPT‑5 (configurable via env)
- Transport: HTTPS (Firebase Cloud Functions HTTP or HTTPS service behind CDN)
- Auth: Firebase ID token (Bearer) required on every call
- Latency target: p50 < 2s, p95 < 6s (non‑RAG)
- Cost controls: intent gating, caching, truncation, safety filters

## Endpoints

### 1) POST /ai/respond
Primary endpoint that turns a user query (typed or voice transcript) into a structured AIResponse with actions.

Headers:
- Authorization: Bearer <Firebase ID token>
- Content-Type: application/json

Request body:
```json
{
  "query": "Show my land records",
  "lang": "en" ,
  "isVoice": false,
  "context": {
    "userId": "<uid>",
    "role": "member",
    "state": "Telangana",
    "district": "Hyderabad"
  },
  "client": {
    "platform": "web|android|ios",
    "appVersion": "x.y.z"
  }
}
```

Response body (success):
```json
{
  "text": "I can help you view your land records. Let me take you there.",
  "confidence": 0.92,
  "actions": [
    { "type": "navigate", "label": "View Land Records", "data": { "route": "/land/records" } }
  ],
  "meta": {
    "intent": "viewLandRecords",
    "lang": "en",
    "citations": [
      {"title": "Patta Records Guide", "url": "https://...", "snippet": "..."}
    ],
    "usage": { "promptTokens": 123, "completionTokens": 256 }
  }
}
```

Response body (error):
```json
{
  "error": {
    "code": "UPSTREAM_UNAVAILABLE|INVALID_INPUT|UNAUTHORIZED|RATE_LIMIT|SAFETY_BLOCK",
    "message": "Human-readable message",
    "details": {"hint": "Try again later"}
  }
}
```

### 2) POST /ai/suggestions (optional; can be in‑process on /respond)
Returns contextual starter prompts for the user.

Request: same headers; body `{ "lang": "en" }` optional.
Response: `{ "suggestions": ["Show my land records", "Get legal help", ...] }`

## Authentication & Authorization
- Client passes Firebase ID token in Authorization header.
- Server verifies token using Admin SDK; extracts uid and attaches to request context.
- Access controls:
  - Only authenticated users allowed.
  - When logging to Firestore, store uid and restrict reads to the owner (existing rules for ai_interactions are compatible).

## Request Flow (Server)
1. Verify Firebase token; reject if invalid.
2. Normalize input (trim, lowercase copy for routing; keep original for LLM).
3. Fast intent gate (cheap keyword/regex/matcher) to:
   - Route trivial app navigation/emergency answers without LLM (low latency, zero cost).
   - Allow/deny LLM usage by category and plan/role (future‑proof).
4. Optional RAG:
   - If query is legal/procedural, perform retrieval (vector search) over curated KB.
   - Build grounded prompt with short, cited snippets.
5. Call GPT‑5 with function‑calling (JSON mode) to produce AIResponse schema.
6. Safety pass (PII filters, allowlist for actions, length limits).
7. Persist interaction log (redacted) to `ai_interactions`.
8. Return response JSON.

## GPT‑5 Call — Prompt & Parameters
- Model: `gpt-5` (configurable)
- Mode: JSON output constrained to AIResponse schema (see below)
- Temperature: 0.3 (factual); Top‑p: 0.9; Max tokens: 512 (server‑side capped)
- System prompt (template):
  - Role: TALOWA land‑rights assistant for Indian users.
  - Voice: Clear, respectful, concise; cite when using KB.
  - Policies: Do not fabricate legal specifics; prefer “I don’t know” + point to human/legal support if uncertain.
  - Output strictly conforms to `AIResponse` JSON schema.

## AIResponse Schema (Server‑side JSON)
```json
{
  "type": "object",
  "required": ["text", "confidence", "actions"],
  "properties": {
    "text": {"type": "string", "maxLength": 2000},
    "confidence": {"type": "number", "minimum": 0, "maximum": 1},
    "actions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type", "label", "data"],
        "properties": {
          "type": {"type": "string", "enum": ["navigate", "call", "share", "suggestions", "form"]},
          "label": {"type": "string", "maxLength": 120},
          "data": {"type": "object"}
        }
      }
    },
    "meta": {
      "type": "object",
      "properties": {
        "intent": {"type": "string"},
        "lang": {"type": "string"},
        "citations": {"type": "array", "items": {"type": "object"}},
        "usage": {"type": "object"}
      }
    }
  }
}
```

Action data examples:
- navigate: `{ "route": "/land/records", "params": {"tab": "mine"} }`
- call: `{ "phone": "+91100" }`
- share: `{ "text": "...", "targets": ["whatsapp", "sms"] }`
- suggestions: `{ "suggestions": ["A", "B", "C"] }`
- form: `{ "id": "patta_application_intro", "fields": [ ... ] }`

## Safety & Guardrails
- Pre‑filter bad/unsafe inputs; post‑filter outputs.
- Strict allowlist for routes and phone numbers for actions; never execute arbitrary URLs.
- Redact PII before logging (phone, addresses unless user‑owned and necessary).
- Refuse unsafe legal advice; provide general guidance and connect to legal support.

## Cost Optimization
- Intent gate to avoid LLM for navigation/emergency/basic FAQs.
- Cache recent Q→A for 5–15 minutes (keyed by normalized query + role + locale).
- Truncate long histories; summarize server‑side when needed.
- Use smaller contexts for repeated intents; narrow RAG top‑k (e.g., 3–5 snippets).
- Backoff/retry only on idempotent upstream errors; circuit‑break on spikes.

## Observability
- Log (redacted) to `ai_interactions`: uid, query hash, intent, latency, llm_used, tokens, error flags.
- Metrics: success rate, SAFETY_BLOCK rate, average latency, token usage per intent class.
- Feature flags: enable_llm, enable_rag, max_tokens, allowed_actions, cache_ttl.

## Firebase Function Skeleton (TypeScript)
```ts
// POST /ai/respond
export const aiRespond = onRequest({ cors: true }, async (req, res) => {
  try {
    const idToken = req.headers.authorization?.split('Bearer ')[1];
    const decoded = await admin.auth().verifyIdToken(idToken || '');
    const uid = decoded.uid;

    const { query, lang, isVoice, context, client } = req.body || {};
    // 1) validate input
    // 2) fast intent gate
    // 3) optional RAG
    // 4) call GPT‑5 with JSON schema
    // 5) safety + allowlist
    // 6) log to ai_interactions

    return res.json({ text: "...", confidence: 0.9, actions: [], meta: { intent: "general", lang: lang || "en" } });
  } catch (e: any) {
    const code = e.code === 'auth/invalid-token' ? 'UNAUTHORIZED' : 'UPSTREAM_UNAVAILABLE';
    return res.status(code === 'UNAUTHORIZED' ? 401 : 503).json({ error: { code, message: String(e.message || 'Error') } });
  }
});
```

## Client Integration Plan
- Add config:
  - `AI_BACKEND_URL` (env / Remote Config)
  - Feature flags: `enable_llm`, `enable_rag`, `llm_timeout_ms`
- Modify `AIAssistantService.processQuery`:
  - If intent ∈ {navigation, emergency} → use local fast path (existing behavior)
  - Else → POST /ai/respond
- Timeouts: 6–8s; show friendly loading + cancel option.
- Retry: none for user‑triggered calls; show “Try again” on transient failures.

Pseudo‑flow:
```dart
final normalized = _normalizeQuery(query);
final localIntent = await _analyzeIntent(normalized);
if (_localFastPath(localIntent)) {
  return _generateResponse(localIntent, normalized);
}
final resp = await http.post(Uri.parse('$base/ai/respond'), headers: {...}, body: jsonEncode({...}));
if (resp.ok) return AIResponse.fromJson(jsonDecode(resp.body));
return _fallbackGeneralResponse();
```

## Configuration & Secrets
- Store OpenAI key as Functions config/secret manager; never in client.
- Environment variables:
  - `OPENAI_API_KEY`, `OPENAI_MODEL=gpt-5`
  - `ENABLE_RAG=true|false`
  - `CACHE_TTL_SECONDS=300`
  - `MAX_TOKENS=512`

## Rollout
1. Deploy backend to staging (Functions region: asia-south1).
2. Enable behind feature flag for internal users only.
3. Monitor latency, error rates, token usage.
4. Gradual enablement to 5%, 25%, 100% of users.

## Testing
- Unit tests: intent gate, schema validation, allowlist enforcement.
- Integration tests: end‑to‑end /ai/respond happy path + failure modes.
- Load tests: RPS baselines, backoff/circuit breaker validation.

## Future Extensions
- Multilingual detection and translation pipeline (hi‑IN, te‑IN).
- Deeper RAG with state‑specific legal content; human‑in‑loop escalation.
- Conversation memory summaries per user with consent controls.

