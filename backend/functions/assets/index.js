// backend/functions/assets/index.js
// Assets API — music library, sound effects, stickers, fonts, LUTs
const { Pool } = require('pg');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const db  = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const s3  = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

const S3_BUCKET  = process.env.S3_BUCKET;
const CDN_DOMAIN = process.env.CDN_DOMAIN;
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

// ── Music library ─────────────────────────────────────────────────────────────
async function listMusic(query = {}) {
  const { genre, mood, q, limit = 20, offset = 0, sort = 'popular' } = query;
  const conditions = ['is_active = TRUE'];
  const params = [];
  let idx = 1;

  if (genre) { conditions.push(`genre = $${idx++}`); params.push(genre); }
  if (mood)  { conditions.push(`mood = $${idx++}`);  params.push(mood); }
  if (q)     { conditions.push(`(title ILIKE $${idx} OR artist ILIKE $${idx++})`); params.push(`%${q}%`); }

  const orderBy = sort === 'newest' ? 'created_at DESC' : sort === 'bpm' ? 'bpm ASC' : 'download_count DESC';
  params.push(parseInt(limit), parseInt(offset));

  const rows = await db.query(
    `SELECT id, title, artist, genre, mood, duration_seconds, bpm, url, waveform_url, thumbnail_url, tags, is_premium, download_count
     FROM music_tracks WHERE ${conditions.join(' AND ')} ORDER BY ${orderBy} LIMIT $${idx} OFFSET $${idx + 1}`,
    params
  );
  const count = await db.query(`SELECT COUNT(*) FROM music_tracks WHERE ${conditions.join(' AND ')}`, params.slice(0, -2));
  return resp(200, { music: rows.rows, total: parseInt(count.rows[0].count) });
}

// ── Sound effects ─────────────────────────────────────────────────────────────
async function listSFX(query = {}) {
  const { category, q, limit = 30, offset = 0 } = query;
  const conditions = ['is_active = TRUE'];
  const params = [];
  let idx = 1;

  if (category) { conditions.push(`category = $${idx++}`); params.push(category); }
  if (q)        { conditions.push(`name ILIKE $${idx++}`); params.push(`%${q}%`); }
  params.push(parseInt(limit), parseInt(offset));

  const rows = await db.query(
    `SELECT id, name, category, duration_seconds, url, is_premium, tags
     FROM sound_effects WHERE ${conditions.join(' AND ')} ORDER BY name ASC LIMIT $${idx} OFFSET $${idx + 1}`,
    params
  );
  return resp(200, { sfx: rows.rows });
}

// ── Sticker packs ─────────────────────────────────────────────────────────────
async function listStickerPacks() {
  const packs = await db.query(`SELECT sp.*, COUNT(s.id) as sticker_count FROM sticker_packs sp LEFT JOIN stickers s ON s.pack_id = sp.id WHERE sp.is_active = TRUE GROUP BY sp.id ORDER BY sp.name`);
  return resp(200, { packs: packs.rows });
}

async function listStickersInPack(packId) {
  const stickers = await db.query('SELECT * FROM stickers WHERE pack_id = $1 ORDER BY name', [packId]);
  return resp(200, { stickers: stickers.rows });
}

// ── Fonts ─────────────────────────────────────────────────────────────────────
async function listFonts(query = {}) {
  const { category, q, limit = 50 } = query;
  const conditions = ['is_active = TRUE'];
  const params = [];
  let idx = 1;
  if (category) { conditions.push(`category = $${idx++}`); params.push(category); }
  if (q)        { conditions.push(`(family ILIKE $${idx} OR display_name ILIKE $${idx++})`); params.push(`%${q}%`); }
  params.push(parseInt(limit));
  const rows = await db.query(
    `SELECT id, family, display_name, url, preview_url, category, is_premium FROM fonts WHERE ${conditions.join(' AND ')} ORDER BY display_name LIMIT $${idx}`,
    params
  );
  return resp(200, { fonts: rows.rows });
}

// ── Favorites ─────────────────────────────────────────────────────────────────
async function getFavorites(userId, type) {
  const rows = await db.query('SELECT item_id, type, created_at FROM user_favorites WHERE user_id = $1 AND type = $2 ORDER BY created_at DESC', [userId, type]);
  return resp(200, { favorites: rows.rows });
}

async function toggleFavorite(userId, type, itemId) {
  const existing = await db.query('SELECT id FROM user_favorites WHERE user_id = $1 AND type = $2 AND item_id = $3', [userId, type, itemId]);
  if (existing.rows.length) {
    await db.query('DELETE FROM user_favorites WHERE user_id = $1 AND type = $2 AND item_id = $3', [userId, type, itemId]);
    return resp(200, { favorited: false });
  } else {
    await db.query('INSERT INTO user_favorites (user_id, type, item_id) VALUES ($1,$2,$3)', [userId, type, itemId]);
    return resp(200, { favorited: true });
  }
}

// ── Presigned upload (for admin asset uploads) ────────────────────────────────
async function getUploadUrl(body) {
  const { type, filename, content_type } = body;
  const key = `assets/${type}/${uuidv4()}-${filename}`;
  const url = await getSignedUrl(s3, new PutObjectCommand({ Bucket: S3_BUCKET, Key: key, ContentType: content_type }), { expiresIn: 3600 });
  const cdnUrl = `https://${CDN_DOMAIN}/${key}`;
  return resp(200, { upload_url: url, cdn_url: cdnUrl, key });
}

// ── Increment download count ──────────────────────────────────────────────────
async function trackDownload(table, id) {
  await db.query(`UPDATE ${table} SET download_count = download_count + 1 WHERE id = $1`, [id]);
  return resp(200, { tracked: true });
}

// ── Lambda handler ─────────────────────────────────────────────────────────────
exports.handler = async (event) => {
  const { httpMethod, path } = event;
  const query = event.queryStringParameters || {};
  const body  = event.body ? JSON.parse(event.body) : {};
  const pp    = event.pathParameters || {};
  const claims = requireAuth(event);

  // Public listing endpoints
  if (httpMethod === 'GET' && path === '/assets/music')        return listMusic(query);
  if (httpMethod === 'GET' && path === '/assets/sfx')          return listSFX(query);
  if (httpMethod === 'GET' && path === '/assets/sticker-packs') return listStickerPacks();
  if (httpMethod === 'GET' && pp.packId)                        return listStickersInPack(pp.packId);
  if (httpMethod === 'GET' && path === '/assets/fonts')         return listFonts(query);

  // Auth required
  if (!claims) return resp(401, { error: 'Unauthorized' });
  if (httpMethod === 'GET'  && path === '/assets/favorites')    return getFavorites(claims.sub, query.type);
  if (httpMethod === 'POST' && path === '/assets/favorites')    return toggleFavorite(claims.sub, body.type, body.item_id);
  if (httpMethod === 'POST' && path === '/assets/upload-url')   return getUploadUrl(body);
  if (httpMethod === 'POST' && path.includes('/download'))      return trackDownload(body.table, body.id);

  return resp(404, { error: 'Not found' });
};
