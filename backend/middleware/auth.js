// backend/middleware/auth.js
// JWT validation + file size enforcement + security headers

const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const JWT_SECRET = process.env.JWT_SECRET;

// ── Security headers ──────────────────────────────────────────────────────────
const SECURITY_HEADERS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Requested-With',
  'X-Content-Type-Options':       'nosniff',
  'X-Frame-Options':              'DENY',
  'X-XSS-Protection':             '1; mode=block',
  'Referrer-Policy':              'strict-origin-when-cross-origin',
  'Cache-Control':                'no-store',
};

const resp = (code, body, extra = {}) => ({
  statusCode: code,
  headers: { ...SECURITY_HEADERS, 'Content-Type': 'application/json', ...extra },
  body: JSON.stringify(body),
});

// ── JWT verification ──────────────────────────────────────────────────────────
function verifyToken(event) {
  const h = event.headers?.Authorization || event.headers?.authorization || '';
  if (!h.startsWith('Bearer ')) return null;
  try {
    return jwt.verify(h.slice(7), JWT_SECRET);
  } catch (e) {
    if (e.name === 'TokenExpiredError') return { expired: true };
    return null;
  }
}

// ── File size limits ──────────────────────────────────────────────────────────
const FILE_SIZE_LIMITS = {
  video: 500 * 1024 * 1024,  // 500 MB
  image:  20 * 1024 * 1024,  //  20 MB
  audio:  50 * 1024 * 1024,  //  50 MB
  font:    5 * 1024 * 1024,  //   5 MB
};

function checkFileSize(contentLength, fileType = 'video') {
  const limit = FILE_SIZE_LIMITS[fileType] || FILE_SIZE_LIMITS.video;
  const size  = parseInt(contentLength || '0');
  if (size > limit) {
    return {
      ok: false,
      error: `File too large. Maximum ${Math.round(limit / 1024 / 1024)}MB allowed for ${fileType}s.`,
      limitMB: Math.round(limit / 1024 / 1024),
    };
  }
  return { ok: true };
}

// ── User plan cache (avoid DB hit every request) ──────────────────────────────
const _planCache = new Map();
const PLAN_CACHE_TTL = 60_000; // 1 minute

async function getUserPlan(userId) {
  const cached = _planCache.get(userId);
  if (cached && Date.now() - cached.ts < PLAN_CACHE_TTL) return cached.plan;

  try {
    const row = await db.query(
      `SELECT COALESCE(s.plan,'free') as plan
       FROM users u LEFT JOIN subscriptions s ON s.id = u.subscription_id
       WHERE u.id = $1 LIMIT 1`,
      [userId]
    );
    const plan = row.rows[0]?.plan || 'free';
    _planCache.set(userId, { plan, ts: Date.now() });
    return plan;
  } catch (_) {
    return 'free';
  }
}

// ── Feature gate check ────────────────────────────────────────────────────────
const PLAN_FEATURES = {
  free:    { maxProjects: 3,  maxExportFPS: 30, maxResolution: '720p', aiMinPerDay: 0,   watermark: true  },
  pro:     { maxProjects: -1, maxExportFPS: 60, maxResolution: '1080p',aiMinPerDay: 5,   watermark: false },
  premium: { maxProjects: -1, maxExportFPS: 60, maxResolution: '4k',   aiMinPerDay: -1,  watermark: false },
};

function canUseFeature(plan, feature) {
  const perms = PLAN_FEATURES[plan] || PLAN_FEATURES.free;
  return perms[feature];
}

// ── withAuth middleware wrapper ───────────────────────────────────────────────
function withAuth(handler, { requirePlan } = {}) {
  return async (event) => {
    // Handle OPTIONS (CORS preflight)
    if (event.httpMethod === 'OPTIONS') {
      return { statusCode: 204, headers: SECURITY_HEADERS, body: '' };
    }

    const claims = verifyToken(event);
    if (!claims) return resp(401, { error: 'Unauthorized. Please sign in.' });
    if (claims.expired) return resp(401, { error: 'Session expired. Please sign in again.', code: 'TOKEN_EXPIRED' });

    // Plan gate
    if (requirePlan) {
      const plan = await getUserPlan(claims.sub);
      const planOrder = { free: 0, pro: 1, premium: 2 };
      if ((planOrder[plan] || 0) < (planOrder[requirePlan] || 0)) {
        return resp(403, { error: `This feature requires ${requirePlan} plan.`, requiredPlan: requirePlan, currentPlan: plan });
      }
    }

    // Attach claims to event
    event._auth = claims;
    event._userId = claims.sub;

    return handler(event);
  };
}

module.exports = { verifyToken, checkFileSize, getUserPlan, canUseFeature, withAuth, SECURITY_HEADERS, resp };
