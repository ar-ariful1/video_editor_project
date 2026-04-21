// backend/functions/templates/ranking.js
// Template ranking engine — trending algorithm, download tracking, creator system

const { Pool } = require('pg');
const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

// ── Trending score algorithm (Wilson score + recency decay) ────────────────────
// Score = (downloads * quality) / (age_hours ^ 0.8)
// quality = avg_rating * 0.4 + download_velocity * 0.6

async function computeTrendingScore(templateId) {
  const rows = await db.query(`
    SELECT
      t.id,
      t.download_count,
      t.average_rating,
      t.created_at,
      EXTRACT(EPOCH FROM (NOW() - t.created_at)) / 3600 AS age_hours,
      COALESCE(SUM(td.count), 0) AS recent_downloads
    FROM templates t
    LEFT JOIN (
      SELECT template_id, COUNT(*) as count
      FROM template_downloads
      WHERE downloaded_at > NOW() - INTERVAL '48 hours'
      GROUP BY template_id
    ) td ON td.template_id = t.id
    WHERE t.id = $1
    GROUP BY t.id`, [templateId]);

  if (!rows.rows.length) return 0;
  const r = rows.rows[0];
  const ageH = Math.max(1, parseFloat(r.age_hours));
  const quality = (r.average_rating || 3) * 0.4 + (r.recent_downloads / Math.max(1, ageH)) * 0.6;
  return (r.download_count * quality) / Math.pow(ageH, 0.8);
}

// ── Refresh trending scores (run via cron every hour) ─────────────────────────
async function refreshTrendingScores() {
  const templates = await db.query('SELECT id FROM templates WHERE is_approved = TRUE');
  for (const row of templates.rows) {
    const score = await computeTrendingScore(row.id);
    await db.query('UPDATE templates SET trending_score = $1 WHERE id = $2', [score, row.id]);
  }
  return templates.rows.length;
}

// ── Track download ─────────────────────────────────────────────────────────────
async function trackDownload(templateId, userId, plan) {
  await db.query(`
    INSERT INTO template_downloads (template_id, user_id, user_plan, downloaded_at)
    VALUES ($1, $2, $3, NOW())
    ON CONFLICT DO NOTHING`,
    [templateId, userId, plan]);

  await db.query(
    'UPDATE templates SET download_count = download_count + 1, last_downloaded_at = NOW() WHERE id = $1',
    [templateId]);

  // Update creator earnings (if premium template)
  const tmpl = await db.query('SELECT creator_id, is_premium, price FROM templates WHERE id = $1', [templateId]);
  if (tmpl.rows.length && tmpl.rows[0].is_premium && tmpl.rows[0].creator_id) {
    const earning = parseFloat(tmpl.rows[0].price || 0) * 0.7; // 70% to creator
    await db.query(
      'UPDATE users SET total_earnings = total_earnings + $1 WHERE id = $2',
      [earning, tmpl.rows[0].creator_id]);
  }
}

// ── Creator profile ────────────────────────────────────────────────────────────
async function getCreatorProfile(userId) {
  const rows = await db.query(`
    SELECT
      u.id, u.display_name, u.avatar_url, u.bio, u.total_earnings,
      COUNT(t.id)          AS template_count,
      SUM(t.download_count) AS total_downloads,
      AVG(t.average_rating) AS avg_rating
    FROM users u
    LEFT JOIN templates t ON t.creator_id = u.id AND t.is_approved = TRUE
    WHERE u.id = $1
    GROUP BY u.id`, [userId]);
  return rows.rows[0] || null;
}

async function getCreatorTemplates(userId, { limit = 20, offset = 0 }) {
  const rows = await db.query(`
    SELECT id, name, category, thumbnail_url, is_premium, price,
           download_count, average_rating, created_at, version
    FROM templates
    WHERE creator_id = $1 AND is_approved = TRUE
    ORDER BY created_at DESC
    LIMIT $2 OFFSET $3`,
    [userId, limit, offset]);
  return rows.rows;
}

// ── Template version system ────────────────────────────────────────────────────
async function createNewVersion(templateId, updates, updatedByUserId) {
  const current = await db.query('SELECT * FROM templates WHERE id = $1', [templateId]);
  if (!current.rows.length) throw new Error('Template not found');

  const tmpl = current.rows[0];

  // Save current to version history
  await db.query(`
    INSERT INTO template_versions (template_id, version, template_json, published_at)
    VALUES ($1, $2, $3, NOW())`,
    [templateId, tmpl.version || 1, JSON.stringify(tmpl.template_json)]);

  // Update with new version
  const newVersion = (tmpl.version || 1) + 1;
  const updateFields = { ...updates, version: newVersion, updated_at: new Date() };
  const setClause = Object.keys(updateFields).map((k, i) => `${k} = $${i+2}`).join(', ');
  const values = [templateId, ...Object.values(updateFields)];

  await db.query(`UPDATE templates SET ${setClause} WHERE id = $1`, values);

  return { newVersion, templateId };
}

async function getTemplateVersionHistory(templateId) {
  const rows = await db.query(`
    SELECT version, published_at, updated_by
    FROM template_versions WHERE template_id = $1 ORDER BY version DESC LIMIT 20`,
    [templateId]);
  return rows.rows;
}

// ── Handler ────────────────────────────────────────────────────────────────────
async function handler(event) {
  const { httpMethod, path } = event;
  const body = event.body ? JSON.parse(event.body) : {};
  const query = event.queryStringParameters || {};
  const pp  = event.pathParameters || {};

  const resp = (code, data) => ({
    statusCode: code,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    body: JSON.stringify(data),
  });

  if (httpMethod === 'POST' && path.includes('/ranking/refresh'))
    return resp(200, { updated: await refreshTrendingScores() });

  if (httpMethod === 'POST' && path.includes('/download'))
    { await trackDownload(pp.templateId, body.userId, body.plan || 'free'); return resp(200, { tracked: true }); }

  if (httpMethod === 'GET' && path.includes('/creator/') && path.includes('/templates'))
    return resp(200, { templates: await getCreatorTemplates(pp.userId, query) });

  if (httpMethod === 'GET' && path.includes('/creator/'))
    return resp(200, { creator: await getCreatorProfile(pp.userId) });

  if (httpMethod === 'POST' && path.includes('/version'))
    return resp(200, await createNewVersion(pp.templateId, body, body.userId));

  if (httpMethod === 'GET' && path.includes('/versions'))
    return resp(200, { versions: await getTemplateVersionHistory(pp.templateId) });

  return resp(404, { error: 'Not found' });
}

module.exports = { handler, refreshTrendingScores, trackDownload, getCreatorProfile, computeTrendingScore };
