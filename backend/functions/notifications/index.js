// backend/functions/notifications/index.js
// Push notification sender — FCM via Firebase Admin SDK

const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const JWT_SECRET = process.env.JWT_SECRET;

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

const resp = (code, body) => ({
  statusCode: code,
  headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  body: JSON.stringify(body),
});

// ── Register FCM Token ─────────────────────────────────────────────────────────
async function registerToken(userId, token, platform) {
  await db.query(
    `INSERT INTO fcm_tokens (user_id, token, platform, updated_at)
     VALUES ($1, $2, $3, NOW())
     ON CONFLICT (user_id, token) DO UPDATE SET platform = $3, updated_at = NOW()`,
    [userId, token, platform]
  );
  return resp(200, { registered: true });
}

// ── Send to single user ────────────────────────────────────────────────────────
async function sendToUser(userId, notification) {
  const { title, body, data = {}, type = 'general' } = notification;

  // Get all FCM tokens for this user
  const result = await db.query('SELECT token FROM fcm_tokens WHERE user_id = $1', [userId]);
  if (!result.rows.length) return resp(200, { sent: 0 });

  const tokens = result.rows.map(r => r.token);
  const message = {
    notification: { title, body },
    data: { ...data, type, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
    tokens,
    android: {
      priority: 'high',
      notification: { channel_id: 'video_editor_main', color: '#7c6ef7' },
    },
    apns: {
      payload: { aps: { badge: 1, sound: 'default' } },
    },
  };

  const response = await admin.messaging().sendEachForMulticast(message);

  // Clean up invalid tokens
  const invalidTokens = [];
  response.responses.forEach((r, i) => {
    if (!r.success && (r.error?.code === 'messaging/registration-token-not-registered' || r.error?.code === 'messaging/invalid-registration-token')) {
      invalidTokens.push(tokens[i]);
    }
  });
  if (invalidTokens.length) {
    await db.query('DELETE FROM fcm_tokens WHERE token = ANY($1)', [invalidTokens]);
  }

  return resp(200, { sent: response.successCount, failed: response.failureCount });
}

// ── Broadcast to all users ─────────────────────────────────────────────────────
async function broadcastNotification(notification, filter = {}) {
  const { title, body, data = {}, type = 'general' } = notification;
  const { plan, minPlan } = filter;

  let tokenQuery = 'SELECT ft.token FROM fcm_tokens ft JOIN users u ON u.id = ft.user_id';
  const params = [];

  if (minPlan || plan) {
    tokenQuery += ' JOIN subscriptions s ON s.id = u.subscription_id';
    if (plan) {
      params.push(plan);
      tokenQuery += ` WHERE s.plan = $${params.length}`;
    }
  }

  const result = await db.query(tokenQuery, params);
  if (!result.rows.length) return resp(200, { sent: 0 });

  // Send in batches of 500 (FCM limit)
  const tokens = result.rows.map(r => r.token);
  const batchSize = 500;
  let totalSent = 0;

  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);
    const message = {
      notification: { title, body },
      data: { ...data, type },
      tokens: batch,
      android: { priority: 'high' },
      apns: { payload: { aps: { badge: 1 } } },
    };
    const response = await admin.messaging().sendEachForMulticast(message);
    totalSent += response.successCount;
  }

  // Log notification in DB
  await db.query(
    'INSERT INTO notifications (type, title, body, data) VALUES ($1, $2, $3, $4)',
    [type, title, body, JSON.stringify(data)]
  );

  return resp(200, { sent: totalSent, total_tokens: tokens.length });
}

// ── Template drop notification ─────────────────────────────────────────────────
async function notifyTemplateDrop(templateIds) {
  return broadcastNotification({
    title: '🎨 New Templates Just Dropped!',
    body: `${templateIds.length} fresh templates are ready to use.`,
    data: { template_ids: JSON.stringify(templateIds) },
    type: 'template_drop',
  });
}

// ── Export complete notification ───────────────────────────────────────────────
async function notifyExportComplete(userId, projectTitle, exportUrl) {
  return sendToUser(userId, {
    title: '✅ Export Complete!',
    body: `"${projectTitle}" is ready to download.`,
    data: { export_url: exportUrl },
    type: 'export_complete',
  });
}

// ── Lambda handler ─────────────────────────────────────────────────────────────
exports.handler = async (event) => {
  const { httpMethod, path } = event;
  const body = event.body ? JSON.parse(event.body) : {};

  // Internal service calls (export complete, etc.) — no JWT required
  if (httpMethod === 'POST' && path === '/notifications/internal/export-complete') {
    return notifyExportComplete(body.user_id, body.project_title, body.export_url);
  }
  if (httpMethod === 'POST' && path === '/notifications/internal/template-drop') {
    return notifyTemplateDrop(body.template_ids || []);
  }
  if (httpMethod === 'POST' && path === '/notifications/internal/broadcast') {
    return broadcastNotification(body.notification, body.filter);
  }

  // User-facing routes — require auth
  const h = event.headers?.Authorization || event.headers?.authorization || '';
  let claims;
  try { claims = jwt.verify(h.replace('Bearer ', ''), JWT_SECRET); }
  catch { return resp(401, { error: 'Unauthorized' }); }

  if (httpMethod === 'POST' && path === '/notifications/register-token') {
    return registerToken(claims.sub, body.token, body.platform || 'android');
  }

  return resp(404, { error: 'Not found' });
};

// Create fcm_tokens table (add to migrations)
// CREATE TABLE IF NOT EXISTS fcm_tokens (
//   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
//   user_id UUID REFERENCES users(id) ON DELETE CASCADE,
//   token TEXT NOT NULL,
//   platform VARCHAR(10) DEFAULT 'android',
//   updated_at TIMESTAMPTZ DEFAULT NOW(),
//   UNIQUE(user_id, token)
// );
