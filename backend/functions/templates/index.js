// backend/functions/templates/index.js
// Template marketplace API — search, filter, purchase, rate

const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const { ElasticClient } = require('./elastic_client');

const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const JWT_SECRET = process.env.JWT_SECRET;

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

function parseQuery(event) {
  return event.queryStringParameters || {};
}

// ── Helpers ───────────────────────────────────────────────────────────────────

async function getUserPlan(userId) {
  const r = await db.query(
    'SELECT s.plan FROM users u LEFT JOIN subscriptions s ON s.id = u.subscription_id WHERE u.id = $1',
    [userId]
  );
  return r.rows[0]?.plan || 'free';
}

async function hasTemplatePurchase(userId, templateId) {
  const r = await db.query(
    'SELECT id FROM template_purchases WHERE user_id = $1 AND template_id = $2',
    [userId, templateId]
  );
  return r.rows.length > 0;
}

// ── Handlers ──────────────────────────────────────────────────────────────────

async function listTemplates(userId, query) {
  const {
    q,                        // search query
    category,
    is_premium,
    aspect_ratio,
    min_duration,
    max_duration,
    sort = 'trending',        // trending | newest | rating | popular
    page = '1',
    limit = '20',
  } = query;

  const pageNum = Math.max(1, parseInt(page));
  const limitNum = Math.min(50, Math.max(1, parseInt(limit)));
  const offset = (pageNum - 1) * limitNum;

  const conditions = ['is_approved = TRUE'];
  const params = [];
  let paramIdx = 1;

  if (q) {
    conditions.push(`search_vector @@ plainto_tsquery('english', $${paramIdx})`);
    params.push(q);
    paramIdx++;
  }
  if (category) {
    conditions.push(`category = $${paramIdx}`);
    params.push(category);
    paramIdx++;
  }
  if (is_premium !== undefined) {
    conditions.push(`is_premium = $${paramIdx}`);
    params.push(is_premium === 'true');
    paramIdx++;
  }
  if (aspect_ratio) {
    conditions.push(`aspect_ratio = $${paramIdx}`);
    params.push(aspect_ratio);
    paramIdx++;
  }
  if (min_duration) {
    conditions.push(`duration_seconds >= $${paramIdx}`);
    params.push(parseFloat(min_duration));
    paramIdx++;
  }
  if (max_duration) {
    conditions.push(`duration_seconds <= $${paramIdx}`);
    params.push(parseFloat(max_duration));
    paramIdx++;
  }

  const orderBy = {
    trending: 'is_trending DESC, download_count DESC',
    newest: 'created_at DESC',
    rating: 'rating DESC, rating_count DESC',
    popular: 'download_count DESC',
  }[sort] || 'download_count DESC';

  const where = conditions.join(' AND ');
  params.push(limitNum, offset);

  const [templatesResult, countResult] = await Promise.all([
    db.query(
      `SELECT id, name, description, category, tags, thumbnail_url, preview_url,
              aspect_ratio, duration_seconds, slot_count, is_premium, price,
              download_count, rating, rating_count, is_featured, is_trending,
              created_at
       FROM templates
       WHERE ${where}
       ORDER BY ${orderBy}
       LIMIT $${paramIdx} OFFSET $${paramIdx + 1}`,
      params
    ),
    db.query(`SELECT COUNT(*) FROM templates WHERE ${where}`, params.slice(0, -2)),
  ]);

  // If user is authenticated, mark which ones they own
  let ownedIds = new Set();
  if (userId) {
    const plan = await getUserPlan(userId);
    const ownedResult = await db.query(
      'SELECT template_id FROM template_purchases WHERE user_id = $1',
      [userId]
    );
    ownedIds = new Set(ownedResult.rows.map(r => r.template_id));

    // Premium plan users have access to all templates
    if (plan === 'premium') {
      templatesResult.rows = templatesResult.rows.map(t => ({ ...t, has_access: true }));
    } else {
      templatesResult.rows = templatesResult.rows.map(t => ({
        ...t,
        has_access: !t.is_premium || ownedIds.has(t.id) || (plan === 'pro' && t.price === 0),
      }));
    }
  }

  return resp(200, {
    templates: templatesResult.rows,
    pagination: {
      page: pageNum,
      limit: limitNum,
      total: parseInt(countResult.rows[0].count),
      pages: Math.ceil(parseInt(countResult.rows[0].count) / limitNum),
    },
  });
}

async function getTemplate(userId, templateId) {
  const result = await db.query(
    'SELECT * FROM templates WHERE id = $1 AND is_approved = TRUE',
    [templateId]
  );
  if (!result.rows.length) return err(404, 'Template not found');

  const template = result.rows[0];
  let hasAccess = !template.is_premium;

  if (userId) {
    const plan = await getUserPlan(userId);
    hasAccess = !template.is_premium
      || plan === 'premium'
      || await hasTemplatePurchase(userId, templateId)
      || (plan === 'pro' && template.price === 0);
  }

  // Don't return template_json unless user has access
  if (!hasAccess) {
    delete template.template_json;
  }

  // Increment view count (async, don't await)
  db.query('UPDATE templates SET download_count = download_count + 1 WHERE id = $1', [templateId]);

  return resp(200, { ...template, has_access: hasAccess });
}

async function getCategories() {
  const result = await db.query(
    `SELECT category, COUNT(*) as count
     FROM templates WHERE is_approved = TRUE
     GROUP BY category ORDER BY count DESC`
  );
  return resp(200, { categories: result.rows });
}

async function rateTemplate(userId, templateId, body) {
  const { rating, review } = body;
  if (!rating || rating < 1 || rating > 5) return err(400, 'Rating must be 1-5');

  await db.query(
    `INSERT INTO template_ratings (user_id, template_id, rating, review)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, template_id) DO UPDATE SET rating = $3, review = $4`,
    [userId, templateId, rating, review]
  );

  const ratingResult = await db.query(
    'SELECT rating, rating_count FROM templates WHERE id = $1',
    [templateId]
  );
  return resp(200, { success: true, newRating: ratingResult.rows[0] });
}

async function getFeatured() {
  const result = await db.query(
    `SELECT id, name, thumbnail_url, preview_url, category, is_premium, price, rating, download_count
     FROM templates WHERE is_featured = TRUE AND is_approved = TRUE
     ORDER BY created_at DESC LIMIT 10`
  );
  return resp(200, { featured: result.rows });
}

async function getTrending() {
  const result = await db.query(
    `SELECT id, name, thumbnail_url, category, is_premium, price, rating, download_count
     FROM templates WHERE is_approved = TRUE
     ORDER BY download_count DESC LIMIT 20`
  );
  return resp(200, { trending: result.rows });
}

async function getMyTemplates(userId) {
  // Templates the user has purchased + all free templates used
  const result = await db.query(
    `SELECT t.id, t.name, t.thumbnail_url, t.category, t.is_premium, t.price,
            tp.purchased_at
     FROM templates t
     INNER JOIN template_purchases tp ON tp.template_id = t.id
     WHERE tp.user_id = $1 AND t.is_approved = TRUE
     ORDER BY tp.purchased_at DESC`,
    [userId]
  );
  return resp(200, { templates: result.rows });
}

// ── Lambda Handler ─────────────────────────────────────────────────────────────

exports.handler = async (event) => {
  const claims = requireAuth(event);
  const userId = claims?.sub;
  const { httpMethod, path, pathParameters } = event;
  const body = event.body ? JSON.parse(event.body) : {};
  const query = parseQuery(event);
  const templateId = pathParameters?.templateId;

  if (httpMethod === 'GET'  && path === '/templates')           return listTemplates(userId, query);
  if (httpMethod === 'GET'  && path === '/templates/featured')  return getFeatured();
  if (httpMethod === 'GET'  && path === '/templates/trending')  return getTrending();
  if (httpMethod === 'GET'  && path === '/templates/categories')return getCategories();

  if (httpMethod === 'GET'  && templateId) return getTemplate(userId, templateId);

  // Protected
  if (!claims) return err(401, 'Unauthorized');

  if (httpMethod === 'GET'  && path === '/templates/mine')      return getMyTemplates(userId);
  if (httpMethod === 'POST' && path.endsWith('/rate'))          return rateTemplate(userId, templateId, body);

  return err(404, 'Not found');
};
