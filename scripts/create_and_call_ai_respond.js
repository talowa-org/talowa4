#!/usr/bin/env node
/**
 * Creates/signs-in a Firebase Auth user via REST and calls aiRespond.
 * Env: FIREBASE_API_KEY (required), EMAIL, PASSWORD (or pass via flags)
 * Flags: --email, --password, --query, --lang
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

function postJson(url, body) {
  const payload = JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        method: 'POST',
        hostname: url.hostname,
        path: url.pathname + (url.search || ''),
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            const json = data ? JSON.parse(data) : {};
            resolve({ status: res.statusCode, headers: res.headers, body: json, raw: data });
          } catch (e) {
            resolve({ status: res.statusCode, headers: res.headers, body: null, raw: data });
          }
        });
      }
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function signIn(apiKey, email, password) {
  const u = new URL(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`);
  return postJson(u, { email, password, returnSecureToken: true });
}

async function signUp(apiKey, email, password) {
  const u = new URL(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`);
  return postJson(u, { email, password, returnSecureToken: true });
}

async function callFunction(idToken, query, lang) {
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
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
      }
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

(async () => {
  const args = parseArgs();
  const apiKey = process.env.FIREBASE_API_KEY;
  const email = args.email || process.env.EMAIL || process.env.FIREBASE_AUTH_EMAIL;
  const password = args.password || process.env.PASSWORD || process.env.FIREBASE_AUTH_PASSWORD;
  const query = args.query || 'Hello';
  const lang = args.lang || 'en';

  if (!apiKey || !email || !password) {
    console.error('Missing FIREBASE_API_KEY, email, or password');
    process.exit(1);
  }

  // 1) Try sign-in
  let res = await signIn(apiKey, email, password);
  let usedEmail = email;

  if (res.status === 400 && res.body?.error?.message === 'INVALID_EMAIL') {
    // Try sanitized email (remove leading '+')
    const sanitized = email.replace(/^\+/, '');
    if (sanitized !== email) {
      console.warn(`Email invalid. Retrying with sanitized email: ${sanitized}`);
      usedEmail = sanitized;
      res = await signIn(apiKey, usedEmail, password);
    }
  }

  // If sign-in still fails (user not found or invalid credentials), attempt sign-up then sign-in
  if (
    res.status === 400 && (
      res.body?.error?.message === 'EMAIL_NOT_FOUND' ||
      res.body?.error?.message === 'INVALID_LOGIN_CREDENTIALS' ||
      res.body?.error?.message === 'USER_NOT_FOUND'
    )
  ) {
    const su = await signUp(apiKey, usedEmail, password);
    if (su.status !== 200) {
      console.error('Sign-up failed:', su.raw || su.body);
      process.exit(1);
    }
    // Some backends allow using su.body.idToken directly; we will sign-in to be consistent
    res = await signIn(apiKey, usedEmail, password);
  }

  if (res.status !== 200) {
    console.error('Sign-in failed:', res.raw || res.body);
    process.exit(1);
  }

  const idToken = res.body.idToken;
  if (!idToken) {
    console.error('No idToken returned. Response:', res.raw || res.body);
    process.exit(1);
  }

  const cf = await callFunction(idToken, query, lang);
  console.log('Status:', cf.status);
  console.log('Headers:', cf.headers);
  console.log('Body:', cf.body);
  process.exit(cf.status === 200 ? 0 : 1);
})();

