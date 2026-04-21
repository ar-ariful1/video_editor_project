// backend/functions/auth/index.js
// Firebase Auth integration + JWT session management

const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');

// ── Setup ─────────────────────────────────────────────────────────────────────

const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES = '7d';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const response = (statusCode, body) => ({
  statusCode,
  headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  body: JSON.stringify(body),
});

const error = (statusCode, message) => response(statusCode, { error: message });

async function verifyFirebaseToken(idToken) {
  return admin.auth().verifyIdToken(idToken);
}

function signJWT(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES });
}

async function findOrCreateUser(firebaseUser) {
  const { uid, email, name, picture, firebase } = firebaseUser;
  const provider = firebase?.sign_in_provider?.replace('.com', '') || 'email';

  let result = await db.query(
    'SELECT u.*, s.plan, s.status as sub_status FROM users u LEFT JOIN subscriptions s ON s.id = u.subscription_id WHERE u.firebase_uid = $1',
    [uid]
  );

  if (result.rows.length > 0) {
    // Update last login
    await db.query('UPDATE users SET last_login_at = NOW() WHERE firebase_uid = $1', [uid]);
    return result.rows[0];
  }

  // New user — create with free subscription
  const client = await db.connect();
  try {
    await client.query('BEGIN');

    const userId = uuidv4();
    const subId = uuidv4();

    // Create free subscription
    await client.query(
      'INSERT INTO subscriptions (id, user_id, plan, status) VALUES ($1, $2, $3, $4)',
      [subId, userId, 'free', 'active']
    );

    // Create user
    const insertResult = await client.query(
      `INSERT INTO users (id, email, display_name, avatar_url, auth_provider, firebase_uid, subscription_id, last_login_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       RETURNING *`,
      [userId, email, name || email?.split('@')[0], picture, provider, uid, subId]
    );

    await client.query('COMMIT');

    return { ...insertResult.rows[0], plan: 'free', sub_status: 'active' };
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

// ── Handlers ──────────────────────────────────────────────────────────────────

async function handleFirebaseAuth(body) {
  const { firebase_token } = body;
  if (!firebase_token) return error(400, 'firebase_token required');

  try {
    const decoded = await verifyFirebaseToken(firebase_token);
    const user = await findOrCreateUser(decoded);

    if (user.is_banned) return error(403, 'Account suspended');

    const token = signJWT({
      sub: user.id,
      email: user.email,
      plan: user.plan || 'free',
      role: 'user',
    });

    return response(200, {
      token,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.display_name,
        avatarUrl: user.avatar_url,
        plan: user.plan || 'free',
        storageUsedBytes: user.storage_used_bytes,
        onboardingCompleted: user.onboarding_completed,
      },
    });
  } catch (e) {
    console.error('Firebase auth error:', e);
    if (e.code === 'auth/id-token-expired') return error(401, 'Token expired');
    if (e.code === 'auth/argument-error') return error(401, 'Invalid token');
    return error(500, 'Authentication failed');
  }
}

async function handleGetProfile(userId) {
  const result = await db.query(
    `SELECT u.*, s.plan, s.status as sub_status, s.current_period_end
     FROM users u
     LEFT JOIN subscriptions s ON s.id = u.subscription_id
     WHERE u.id = $1`,
    [userId]
  );
  if (!result.rows.length) return error(404, 'User not found');
  const u = result.rows[0];
  return response(200, {
    id: u.id, email: u.email, displayName: u.display_name,
    avatarUrl: u.avatar_url, plan: u.plan || 'free',
    storageUsedBytes: u.storage_used_bytes,
    subscriptionEnd: u.current_period_end,
    exportCountToday: u.export_count_today,
    aiCaptionSecondsToday: u.ai_caption_seconds_today,
    locale: u.locale, timezone: u.timezone,
  });
}

async function handleUpdateProfile(userId, body) {
  const { displayName, avatarUrl, locale, timezone, preferredResolution } = body;
  await db.query(
    `UPDATE users SET display_name = COALESCE($1, display_name),
     avatar_url = COALESCE($2, avatar_url),
     locale = COALESCE($3, locale),
     timezone = COALESCE($4, timezone),
     preferred_resolution = COALESCE($5, preferred_resolution)
     WHERE id = $6`,
    [displayName, avatarUrl, locale, timezone, preferredResolution, userId]
  );
  return handleGetProfile(userId);
}

async function handleCompleteOnboarding(userId) {
  await db.query('UPDATE users SET onboarding_completed = TRUE WHERE id = $1', [userId]);
  return response(200, { success: true });
}

async function handleRefreshToken(userId) {
  const result = await db.query(
    'SELECT u.*, s.plan FROM users u LEFT JOIN subscriptions s ON s.id = u.subscription_id WHERE u.id = $1',
    [userId]
  );
  if (!result.rows.length) return error(404, 'User not found');
  const u = result.rows[0];
  if (u.is_banned) return error(403, 'Account suspended');
  const token = signJWT({ sub: u.id, email: u.email, plan: u.plan || 'free', role: 'user' });
  return response(200, { token });
}

// ── JWT Middleware ─────────────────────────────────────────────────────────────

function requireAuth(event) {
  const authHeader = event.headers?.Authorization || event.headers?.authorization;
  if (!authHeader?.startsWith('Bearer ')) return null;
  try {
    return jwt.verify(authHeader.slice(7), JWT_SECRET);
  } catch {
    return null;
  }
}

// ── Lambda Handler ─────────────────────────────────────────────────────────────

exports.handler = async (event) => {
  const { path, httpMethod } = event;
  const body = event.body ? JSON.parse(event.body) : {};

  // Public routes
  if (httpMethod === 'POST' && path === '/auth/firebase') return handleFirebaseAuth(body);

  // Protected routes
  const claims = requireAuth(event);
  if (!claims) return error(401, 'Unauthorized');

  if (httpMethod === 'GET'  && path === '/auth/profile') return handleGetProfile(claims.sub);
  if (httpMethod === 'PUT'  && path === '/auth/profile') return handleUpdateProfile(claims.sub, body);
  if (httpMethod === 'POST' && path === '/auth/refresh') return handleRefreshToken(claims.sub);
  if (httpMethod === 'POST' && path === '/auth/onboarding/complete') return handleCompleteOnboarding(claims.sub);

  return error(404, 'Not found');
};
