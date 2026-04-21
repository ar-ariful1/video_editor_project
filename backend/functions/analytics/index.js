// backend/functions/analytics/index.js
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const JWT_SECRET = process.env.JWT_SECRET;

const resp = (code, body) => ({
  statusCode: code,
  headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  body: JSON.stringify(body),
});

function requireAuth(event) {
  const h = event.headers?.Authorization || event.headers?.authorization || '';
  if (!h.startsWith('Bearer ')) return null;
  try { return jwt.verify(h.slice(7), JWT_SECRET); }
  catch { return null; }
}

async function trackEvent(userId, body) {
  const { event_name, properties = {} } = body;
  if (!event_name) return resp(400, { error: 'event_name required' });

  // Update daily analytics counters
  const today = new Date().toISOString().split('T')[0];
  try {
    await db.query(`
      INSERT INTO daily_analytics (date, dau)
      VALUES ($1, 1)
      ON CONFLICT (date) DO UPDATE SET dau = daily_analytics.dau + 1
    `, [today]);

    switch (event_name) {
      case 'export_complete':
        const quality = properties.quality || '1080p';
        const col = quality === '4k' ? 'exports_4k' : quality === '720p' ? 'exports_720p' : 'exports_1080p';
        await db.query(`UPDATE daily_analytics SET ${col} = ${col} + 1 WHERE date = $1`, [today]);
        break;
      case 'ai_caption_used':
        await db.query(`UPDATE daily_analytics SET ai_caption_jobs = ai_caption_jobs + 1 WHERE date = $1`, [today]);
        break;
      case 'ai_bg_removal_used':
        await db.query(`UPDATE daily_analytics SET ai_bg_removal_jobs = ai_bg_removal_jobs + 1 WHERE date = $1`, [today]);
        break;
      case 'template_downloaded':
        await db.query(`UPDATE daily_analytics SET template_downloads = template_downloads + 1 WHERE date = $1`, [today]);
        break;
    }
  } catch (e) {
    console.error('Analytics error:', e);
  }
  return resp(200, { tracked: true });
}

async function getAdminStats() {
  const [dauRow, usersRow, subRow, analyticsRow] = await Promise.all([
    db.query(`SELECT COUNT(DISTINCT user_id) as dau FROM exports WHERE DATE(queued_at) = CURRENT_DATE`),
    db.query(`SELECT COUNT(*) as total, COUNT(CASE WHEN DATE(created_at) = CURRENT_DATE THEN 1 END) as today FROM users WHERE is_banned = FALSE`),
    db.query(`SELECT plan, COUNT(*) as cnt FROM subscriptions WHERE status = 'active' GROUP BY plan`),
    db.query(`SELECT * FROM daily_analytics WHERE date = CURRENT_DATE`),
  ]);

  const subMap = {};
  subRow.rows.forEach(r => subMap[r.plan] = parseInt(r.cnt));
  const today = analyticsRow.rows[0] || {};

  return resp(200, {
    dau: parseInt(dauRow.rows[0]?.dau || 0),
    mau: parseInt(usersRow.rows[0]?.total || 0),
    totalUsers: parseInt(usersRow.rows[0]?.total || 0),
    newSignupsToday: parseInt(usersRow.rows[0]?.today || 0),
    proSubscribers: subMap.pro || 0,
    premiumSubscribers: subMap.premium || 0,
    revenueToday: ((subMap.pro || 0) * 4.99 + (subMap.premium || 0) * 9.99) / 30,
    revenueMonth: (subMap.pro || 0) * 4.99 + (subMap.premium || 0) * 9.99,
    exportsToday: (today.exports_720p || 0) + (today.exports_1080p || 0) + (today.exports_4k || 0),
    aiJobsToday: (today.ai_caption_jobs || 0) + (today.ai_bg_removal_jobs || 0),
    templateDownloadsToday: today.template_downloads || 0,
    pendingTemplates: 0,
    reportedContent: 0,
    activeExports: 0,
  });
}

async function getAnalytics(period = '30d') {
  const days = period === '7d' ? 7 : period === '90d' ? 90 : 30;
  const result = await db.query(
    `SELECT * FROM daily_analytics WHERE date >= CURRENT_DATE - INTERVAL '${days} days' ORDER BY date ASC`
  );
  return resp(200, { data: result.rows });
}

exports.handler = async (event) => {
  const { httpMethod, path } = event;
  const body = event.body ? JSON.parse(event.body) : {};
  const query = event.queryStringParameters || {};

  // Public event tracking
  if (httpMethod === 'POST' && path === '/analytics/events') {
    const claims = requireAuth(event);
    return trackEvent(claims?.sub, body);
  }

  // Admin stats (require admin token or internal call)
  if (httpMethod === 'GET' && path === '/admin/stats') return getAdminStats();
  if (httpMethod === 'GET' && path === '/admin/analytics') return getAnalytics(query.period);

  return resp(404, { error: 'Not found' });
};
