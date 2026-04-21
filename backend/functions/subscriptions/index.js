// backend/functions/subscriptions/index.js
// Subscription management — RevenueCat webhook + plan gating

const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const crypto = require('crypto');

const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const JWT_SECRET = process.env.JWT_SECRET;
const REVENUECAT_WEBHOOK_SECRET = process.env.REVENUECAT_WEBHOOK_SECRET;
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

const resp = (code, body) => ({
  statusCode: code,
  headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  body: JSON.stringify(body),
});
const err = (code, msg) => resp(code, { error: msg });

function requireAuth(event) {
  const h = event.headers?.Authorization || event.headers?.authorization || '';
  if (!h.startsWith('Bearer ')) return null;
  try { return jwt.verify(h.slice(7), JWT_SECRET); }
  catch { return null; }
}

// ── Plan Features ──────────────────────────────────────────────────────────────

const PLAN_FEATURES = {
  free: {
    maxProjects: 3,
    exportQualities: ['720p'],
    watermark: true,
    aiCaptionSecondsPerDay: 0,
    aiBackgroundRemoval: false,
    aiObjectTracking: false,
    aiEnhancement: false,
    maxEffects: 20,
    templates: 'free_only',
    cloudStorage: false,
  },
  pro: {
    maxProjects: null,      // unlimited
    exportQualities: ['720p', '1080p'],
    watermark: false,
    aiCaptionSecondsPerDay: 300,   // 5 min/day
    aiBackgroundRemoval: true,
    aiObjectTracking: false,
    aiEnhancement: false,
    maxEffects: 200,
    templates: 'free_and_some_premium',
    cloudStorage: true,
  },
  premium: {
    maxProjects: null,
    exportQualities: ['720p', '1080p', '4k'],
    watermark: false,
    aiCaptionSecondsPerDay: null,  // unlimited
    aiBackgroundRemoval: true,
    aiObjectTracking: true,
    aiEnhancement: true,
    maxEffects: null,
    templates: 'all',
    cloudStorage: true,
  },
};

// ── Handlers ──────────────────────────────────────────────────────────────────

async function getSubscription(userId) {
  const result = await db.query(
    `SELECT s.*, u.email FROM subscriptions s
     JOIN users u ON u.id = s.user_id
     WHERE s.user_id = $1
     ORDER BY s.created_at DESC LIMIT 1`,
    [userId]
  );
  if (!result.rows.length) return resp(200, { plan: 'free', features: PLAN_FEATURES.free });

  const sub = result.rows[0];
  const plan = sub.status === 'active' || sub.status === 'trial' ? sub.plan : 'free';
  return resp(200, {
    id: sub.id,
    plan,
    status: sub.status,
    provider: sub.provider,
    currentPeriodEnd: sub.current_period_end,
    cancelAtPeriodEnd: sub.cancel_at_period_end,
    trialEnd: sub.trial_end,
    features: PLAN_FEATURES[plan] || PLAN_FEATURES.free,
  });
}

async function checkFeatureAccess(userId, feature) {
  const subResult = await db.query(
    `SELECT s.plan, s.status FROM subscriptions s WHERE s.user_id = $1 ORDER BY s.created_at DESC LIMIT 1`,
    [userId]
  );
  const plan = (subResult.rows[0]?.status === 'active' ? subResult.rows[0]?.plan : 'free') || 'free';
  const features = PLAN_FEATURES[plan] || PLAN_FEATURES.free;
  const hasAccess = features[feature] === true || features[feature] === null || (Array.isArray(features[feature]) && features[feature].includes(feature));
  return resp(200, { plan, hasAccess, features });
}

// ── RevenueCat Webhook ────────────────────────────────────────────────────────

async function handleRevenueCatWebhook(event) {
  // Verify webhook signature
  const signature = event.headers?.['X-RevenueCat-Signature'] || event.headers?.['x-revenuecat-signature'];
  const body = event.body;

  if (REVENUECAT_WEBHOOK_SECRET) {
    const expected = crypto.createHmac('sha256', REVENUECAT_WEBHOOK_SECRET).update(body).digest('hex');
    if (signature !== expected) return err(401, 'Invalid webhook signature');
  }

  const payload = JSON.parse(body);
  const { event: rcEvent } = payload;

  if (!rcEvent) return resp(200, { received: true });

  const {
    type,
    app_user_id,   // our user ID
    product_id,
    period_type,
    purchased_at_ms,
    expiration_at_ms,
    environment,
  } = rcEvent;

  // Map product_id to plan
  const plan = _productToPlan(product_id);
  const userId = app_user_id;
  const periodStart = purchased_at_ms ? new Date(purchased_at_ms) : new Date();
  const periodEnd = expiration_at_ms ? new Date(expiration_at_ms) : null;

  console.log(`RevenueCat webhook: ${type} for user ${userId}, plan: ${plan}`);

  switch (type) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'PRODUCT_CHANGE':
      await _upsertSubscription(userId, plan, 'active', 'revenuecat', product_id, periodStart, periodEnd);
      await _updateUserPlan(userId, plan);
      break;

    case 'CANCELLATION':
      await db.query(
        "UPDATE subscriptions SET cancel_at_period_end = TRUE, status = 'cancelled' WHERE user_id = $1",
        [userId]
      );
      break;

    case 'EXPIRATION':
      await db.query(
        "UPDATE subscriptions SET status = 'expired' WHERE user_id = $1",
        [userId]
      );
      await _updateUserPlan(userId, 'free');
      break;

    case 'BILLING_ISSUE':
      await db.query(
        "UPDATE subscriptions SET status = 'expired' WHERE user_id = $1",
        [userId]
      );
      break;

    case 'TRIAL_STARTED':
      await _upsertSubscription(userId, plan, 'trial', 'revenuecat', product_id, periodStart, periodEnd);
      break;

    case 'TRIAL_CONVERTED':
      await _upsertSubscription(userId, plan, 'active', 'revenuecat', product_id, periodStart, periodEnd);
      await _updateUserPlan(userId, plan);
      break;

    case 'TRIAL_CANCELLED':
      await db.query(
        "UPDATE subscriptions SET status = 'cancelled' WHERE user_id = $1 AND status = 'trial'",
        [userId]
      );
      await _updateUserPlan(userId, 'free');
      break;
  }

  return resp(200, { received: true });
}

async function _upsertSubscription(userId, plan, status, provider, productId, periodStart, periodEnd) {
  // Check if subscription exists
  const existing = await db.query('SELECT id FROM subscriptions WHERE user_id = $1', [userId]);
  if (existing.rows.length) {
    await db.query(
      `UPDATE subscriptions SET
       plan = $1, status = $2, provider = $3, provider_subscription_id = $4,
       current_period_start = $5, current_period_end = $6, cancel_at_period_end = FALSE
       WHERE user_id = $7`,
      [plan, status, provider, productId, periodStart, periodEnd, userId]
    );
  } else {
    const { v4: uuidv4 } = require('uuid');
    await db.query(
      `INSERT INTO subscriptions (id, user_id, plan, status, provider, provider_subscription_id, current_period_start, current_period_end)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [uuidv4(), userId, plan, status, provider, productId, periodStart, periodEnd]
    );
  }
}

async function _updateUserPlan(userId, plan) {
  // Update the cached plan on user for faster queries
  await db.query('UPDATE users SET updated_at = NOW() WHERE id = $1', [userId]);
  console.log(`User ${userId} plan updated to ${plan}`);
}

function _productToPlan(productId) {
  if (!productId) return 'free';
  if (productId.includes('premium') || productId.includes('9.99')) return 'premium';
  if (productId.includes('pro') || productId.includes('4.99')) return 'pro';
  return 'free';
}

// ── Lambda Handler ─────────────────────────────────────────────────────────────

exports.handler = async (event) => {
  const { httpMethod, path } = event;

  // RevenueCat webhook — no auth required
  if (httpMethod === 'POST' && path === '/webhooks/revenuecat') {
    return handleRevenueCatWebhook(event);
  }

  // Protected routes
  const claims = requireAuth(event);
  if (!claims) return err(401, 'Unauthorized');

  if (httpMethod === 'GET' && path === '/subscription') return getSubscription(claims.sub);
  if (httpMethod === 'GET' && path.startsWith('/subscription/feature/')) {
    const feature = path.split('/').pop();
    return checkFeatureAccess(claims.sub, feature);
  }

  return err(404, 'Not found');
};

// Export for testing
exports.PLAN_FEATURES = PLAN_FEATURES;
