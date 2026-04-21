// backend/functions/search/index.js
// Full-text search for templates, music, stickers, fonts
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');

const db  = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const JWT_SECRET = process.env.JWT_SECRET;

const resp = (code, body) => ({
  statusCode: code,
  headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  body: JSON.stringify(body),
});

// ── Full-text search across all content types ──────────────────────────────────
async function search(query, types = ['templates','music','fonts','effects'], limit = 20) {
  if (!query || query.trim().length < 2) return resp(400, { error: 'Query too short' });
  const q = query.trim();
  const results = {};

  await Promise.all(types.map(async (type) => {
    switch (type) {
      case 'templates': {
        const rows = await db.query(
          `SELECT id, name, category, thumbnail_url, is_premium, rating, download_count,
                  ts_rank(to_tsvector('english', name || ' ' || COALESCE(description,'') || ' ' || array_to_string(tags,' ')), plainto_tsquery('english', $1)) as rank
           FROM templates
           WHERE is_approved = TRUE
             AND to_tsvector('english', name || ' ' || COALESCE(description,'') || ' ' || array_to_string(tags,' ')) @@ plainto_tsquery('english', $1)
           ORDER BY rank DESC, download_count DESC
           LIMIT $2`,
          [q, limit]
        );
        results.templates = rows.rows;
        break;
      }
      case 'music': {
        const rows = await db.query(
          `SELECT id, title, artist, genre, mood, duration_seconds, bpm, url, is_premium
           FROM music_tracks
           WHERE is_active = TRUE
             AND (title ILIKE $1 OR artist ILIKE $1 OR genre ILIKE $1 OR mood ILIKE $1
                  OR $2 = ANY(tags))
           ORDER BY download_count DESC LIMIT $3`,
          [`%${q}%`, q, limit]
        );
        results.music = rows.rows;
        break;
      }
      case 'fonts': {
        const rows = await db.query(
          `SELECT id, family, display_name, preview_url, category, is_premium
           FROM fonts WHERE is_active = TRUE
             AND (family ILIKE $1 OR display_name ILIKE $1 OR category ILIKE $1)
           LIMIT $2`,
          [`%${q}%`, limit]
        );
        results.fonts = rows.rows;
        break;
      }
      case 'stickers': {
        const rows = await db.query(
          `SELECT s.id, s.name, s.url, s.thumbnail_url, sp.name as pack_name
           FROM stickers s JOIN sticker_packs sp ON sp.id = s.pack_id
           WHERE sp.is_active = TRUE AND (s.name ILIKE $1 OR $2 = ANY(s.tags))
           LIMIT $3`,
          [`%${q}%`, q, limit]
        );
        results.stickers = rows.rows;
        break;
      }
    }
  }));

  return resp(200, { query: q, results, total: Object.values(results).reduce((a,b) => a + b.length, 0) });
}

// ── Autocomplete suggestions ──────────────────────────────────────────────────
async function suggest(query, limit = 8) {
  if (!query || query.length < 2) return resp(200, { suggestions: [] });
  const q = `%${query.trim()}%`;

  const [templates, music] = await Promise.all([
    db.query(`SELECT name as suggestion, 'template' as type FROM templates WHERE name ILIKE $1 AND is_approved=TRUE LIMIT $2`, [q, limit / 2]),
    db.query(`SELECT title as suggestion, 'music' as type FROM music_tracks WHERE title ILIKE $1 AND is_active=TRUE LIMIT $2`, [q, limit / 2]),
  ]);

  const suggestions = [...templates.rows, ...music.rows]
    .sort((a,b) => a.suggestion.localeCompare(b.suggestion))
    .slice(0, limit);

  return resp(200, { suggestions });
}

// ── Trending searches ─────────────────────────────────────────────────────────
async function trending() {
  try {
    const rows = await db.query(
      `SELECT query, COUNT(*) as count
       FROM search_history
       WHERE created_at > NOW() - INTERVAL '7 days'
       GROUP BY query ORDER BY count DESC LIMIT 12`
    );
    return resp(200, { trending: rows.rows.map(r => r.query) });
  } catch (_) {
    return resp(200, { trending: ['wedding', 'travel vlog', 'birthday', 'cinematic', 'food', 'dance', 'aesthetic'] });
  }
}

// ── Log search ────────────────────────────────────────────────────────────────
async function logSearch(userId, query) {
  if (!query || query.trim().length < 2) return;
  try {
    await db.query(
      'INSERT INTO search_history (user_id, query) VALUES ($1, $2)',
      [userId, query.trim().toLowerCase()]
    );
  } catch (_) {}
}

// ── Lambda handler ─────────────────────────────────────────────────────────────
exports.handler = async (event) => {
  const { httpMethod, path } = event;
  const query = event.queryStringParameters || {};

  const h = event.headers?.Authorization || event.headers?.authorization || '';
  let userId = null;
  try { userId = jwt.verify(h.replace('Bearer ',''), JWT_SECRET)?.sub; } catch (_) {}

  if (httpMethod === 'GET' && path === '/search') {
    const types = query.types ? query.types.split(',') : undefined;
    if (userId && query.q) await logSearch(userId, query.q);
    return search(query.q, types, parseInt(query.limit) || 20);
  }

  if (httpMethod === 'GET' && path === '/search/suggest') return suggest(query.q, parseInt(query.limit) || 8);
  if (httpMethod === 'GET' && path === '/search/trending')  return trending();

  return resp(404, { error: 'Not found' });
};
