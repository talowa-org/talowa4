#!/usr/bin/env node
/**
 * Call aiRespond Cloud Function.
 * Usage:
 *   node scripts/call_ai_respond.js \
 *     --query "How do I access land records?" \
 *     --lang en \
 *     --idToken "<FIREBASE_ID_TOKEN>"
 *
 * Or sign in via email/password to get a token (requires env vars):
 *   set FIREBASE_API_KEY=... (or export on macOS/Linux)
 *   set FIREBASE_AUTH_EMAIL=...
 *   set FIREBASE_AUTH_PASSWORD=...
 *   node scripts/call_ai_respond.js --query "..." --lang en
 */

const https = require('https');

const CF_URL = process.env.CF_URL || 'https://asia-south1-talowa.cloudfunctions.net/aiRespond';

function parseArgs() {
  const args = process.argv.slice(2);
  const out = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      const key = args[i].slice(2);
      const val = args[i + 1] && !args[i + 1].startsWith('--') ? args[i + 1] : true;
      out[key] = val;
      if (val !== true) i++;
    }
  }
  return out;
}

async function getIdTokenViaPassword() {
  const apiKey = process.env.FIREBASE_API_KEY;
  const email = process.env.FIREBASE_AUTH_EMAIL;
  const password = process.env.FIREBASE_AUTH_PASSWORD;
  if (!apiKey || !email || !password) return null;
  const body = JSON.stringify({ email, password, returnSecureToken: true });
  const url = new URL(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`);
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        method: 'POST',
        hostname: url.hostname,
        path: url.pathname + url.search,
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            if (json.idToken) return resolve(json.idToken);
            return reject(new Error(`Auth error: ${res.statusCode} ${data}`));
          } catch (e) {
            reject(e);
          }
        });
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function callFunction({ query, lang, idToken }) {
  const payload = JSON.stringify({ query, lang });
  const url = new URL(CF_URL);
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        method: 'POST',
        hostname: url.hostname,
        path: url.pathname,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
          Authorization: `Bearer ${idToken}`,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          resolve({ status: res.statusCode, headers: res.headers, body: data });
        });
      }
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

(async () => {
  const args = parseArgs();
  const query = args.query || 'Hello there!';
  const lang = args.lang || 'en';
  let idToken = args.idToken;

  if (!idToken) {
    try {
      idToken = await getIdTokenViaPassword();
    } catch (e) {
      console.error('Failed to get token via password:', e.message);
      process.exit(1);
    }
  }

  if (!idToken) {
    console.error('Missing idToken. Pass --idToken or set FIREBASE_API_KEY/FIREBASE_AUTH_EMAIL/FIREBASE_AUTH_PASSWORD env vars.');
    process.exit(1);
  }

  try {
    const res = await callFunction({ query, lang, idToken });
    console.log('Status:', res.status);
    console.log('Headers:', res.headers);
    console.log('Body:', res.body);
  } catch (e) {
    console.error('Error calling function:', e);
    process.exit(1);
  }
})();

