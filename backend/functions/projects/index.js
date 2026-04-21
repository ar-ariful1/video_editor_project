// backend/functions/projects/index.js
// CRUD for user video projects + cloud sync

const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { v4: uuidv4 } = require('uuid');
const zlib = require('zlib');
const { promisify } = require('util');

const gzip = promisify(zlib.gzip);
const gunzip = promisify(zlib.gunzip);

const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const s3 = new S3Client({ region: process.env.AWS_REGION });
const BUCKET = process.env.S3_BUCKET;
const JWT_SECRET = process.env.JWT_SECRET;
const MAX_PROJECTS_FREE = 3;
const MAX_PROJECT_SIZE_BYTES = 50 * 1024 * 1024; // 50MB JSON limit

// ── Helpers ───────────────────────────────────────────────────────────────────

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

async function getUserPlan(userId) {
  const r = await db.query(
    'SELECT s.plan FROM users u LEFT JOIN subscriptions s ON s.id = u.subscription_id WHERE u.id = $1',
    [userId]
  );
  return r.rows[0]?.plan || 'free';
}

async function getProjectCount(userId) {
  const r = await db.query(
    "SELECT COUNT(*) FROM projects WHERE user_id = $1 AND status != 'deleted'",
    [userId]
  );
  return parseInt(r.rows[0].count);
}

// Compress timeline JSON for S3 storage
async function compressTimeline(timelineJson) {
  const json = JSON.stringify(timelineJson);
  const compressed = await gzip(json);
  return compressed;
}

async function decompressTimeline(compressed) {
  const decompressed = await gunzip(compressed);
  return JSON.parse(decompressed.toString('utf8'));
}

// ── Handlers ──────────────────────────────────────────────────────────────────

async function listProjects(userId) {
  const result = await db.query(
    `SELECT id, title, thumbnail_url, duration_seconds, resolution,
            status, size_bytes, is_cloud_synced, last_synced_at,
            created_at, updated_at, template_id
     FROM projects
     WHERE user_id = $1 AND status != 'deleted'
     ORDER BY updated_at DESC`,
    [userId]
  );
  return resp(200, { projects: result.rows });
}

async function getProject(userId, projectId) {
  const result = await db.query(
    'SELECT * FROM projects WHERE id = $1 AND user_id = $2 AND status != $3',
    [projectId, userId, 'deleted']
  );
  if (!result.rows.length) return err(404, 'Project not found');

  const project = result.rows[0];

  // Fetch timeline JSON from S3 if cloud synced
  if (project.is_cloud_synced && project.timeline_json === null) {
    try {
      const key = `users/${userId}/projects/${projectId}/timeline.json.gz`;
      const s3Resp = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: key }));
      const body = Buffer.concat(await streamToChunks(s3Resp.Body));
      project.timeline_json = await decompressTimeline(body);
    } catch (e) {
      console.error('Failed to fetch timeline from S3:', e);
    }
  }

  return resp(200, project);
}

async function createProject(userId, body) {
  const plan = await getUserPlan(userId);
  if (plan === 'free') {
    const count = await getProjectCount(userId);
    if (count >= MAX_PROJECTS_FREE) {
      return err(403, `Free plan limited to ${MAX_PROJECTS_FREE} projects. Upgrade to Pro for unlimited.`);
    }
  }

  const projectId = uuidv4();
  const { title = 'Untitled Project', resolution, templateId } = body;

  const result = await db.query(
    `INSERT INTO projects (id, user_id, title, resolution, template_id)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, title, resolution, status, created_at, updated_at`,
    [projectId, userId, title, JSON.stringify(resolution || { width: 1920, height: 1080, frameRate: 30 }), templateId]
  );

  return resp(201, result.rows[0]);
}

async function updateProject(userId, projectId, body) {
  const { title, timeline_json, thumbnail_url, duration_seconds, size_bytes } = body;

  // Validate project belongs to user
  const existing = await db.query(
    "SELECT id FROM projects WHERE id = $1 AND user_id = $2 AND status != 'deleted'",
    [projectId, userId]
  );
  if (!existing.rows.length) return err(404, 'Project not found');

  // Store large timeline JSON in S3, keep small ones in DB
  let dbTimelineJson = null;
  let isCloudSynced = false;

  if (timeline_json) {
    const jsonStr = JSON.stringify(timeline_json);
    if (jsonStr.length > 1 * 1024 * 1024) { // > 1MB → S3
      try {
        const compressed = await compressTimeline(timeline_json);
        const key = `users/${userId}/projects/${projectId}/timeline.json.gz`;
        await s3.send(new PutObjectCommand({
          Bucket: BUCKET, Key: key,
          Body: compressed,
          ContentType: 'application/gzip',
          ContentEncoding: 'gzip',
        }));
        isCloudSynced = true;
      } catch (e) {
        console.error('S3 upload failed, storing in DB:', e);
        dbTimelineJson = timeline_json;
      }
    } else {
      dbTimelineJson = timeline_json;
    }
  }

  await db.query(
    `UPDATE projects SET
      title = COALESCE($1, title),
      timeline_json = COALESCE($2, timeline_json),
      thumbnail_url = COALESCE($3, thumbnail_url),
      duration_seconds = COALESCE($4, duration_seconds),
      size_bytes = COALESCE($5, size_bytes),
      is_cloud_synced = $6,
      last_synced_at = CASE WHEN $6 THEN NOW() ELSE last_synced_at END
     WHERE id = $7 AND user_id = $8`,
    [title, dbTimelineJson, thumbnail_url, duration_seconds, size_bytes, isCloudSynced, projectId, userId]
  );

  return getProject(userId, projectId);
}

async function deleteProject(userId, projectId) {
  const result = await db.query(
    "UPDATE projects SET status = 'deleted' WHERE id = $1 AND user_id = $2 RETURNING id",
    [projectId, userId]
  );
  if (!result.rows.length) return err(404, 'Project not found');

  // Schedule S3 cleanup (in production, use SQS)
  try {
    await s3.send(new DeleteObjectCommand({
      Bucket: BUCKET,
      Key: `users/${userId}/projects/${projectId}/timeline.json.gz`,
    }));
  } catch {}

  return resp(200, { deleted: true });
}

async function duplicateProject(userId, projectId) {
  const plan = await getUserPlan(userId);
  if (plan === 'free') {
    const count = await getProjectCount(userId);
    if (count >= MAX_PROJECTS_FREE) return err(403, 'Upgrade to Pro to duplicate projects');
  }

  const result = await db.query(
    "SELECT * FROM projects WHERE id = $1 AND user_id = $2 AND status != 'deleted'",
    [projectId, userId]
  );
  if (!result.rows.length) return err(404, 'Project not found');

  const src = result.rows[0];
  const newId = uuidv4();

  await db.query(
    `INSERT INTO projects (id, user_id, title, thumbnail_url, duration_seconds, resolution, timeline_json, template_id, size_bytes)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
    [newId, userId, `${src.title} (Copy)`, src.thumbnail_url, src.duration_seconds, src.resolution, src.timeline_json, src.template_id, src.size_bytes]
  );

  return resp(201, { id: newId, title: `${src.title} (Copy)` });
}

async function getThumbnailUploadUrl(userId, projectId) {
  const key = `users/${userId}/projects/${projectId}/thumbnail.jpg`;
  const url = await getSignedUrl(s3, new PutObjectCommand({
    Bucket: BUCKET, Key: key, ContentType: 'image/jpeg',
  }), { expiresIn: 300 });
  const cdnUrl = `https://${process.env.CDN_DOMAIN}/${key}`;
  return resp(200, { uploadUrl: url, cdnUrl });
}

async function streamToChunks(stream) {
  const chunks = [];
  for await (const chunk of stream) chunks.push(chunk);
  return chunks;
}

// ── Lambda Handler ─────────────────────────────────────────────────────────────

exports.handler = async (event) => {
  const claims = requireAuth(event);
  if (!claims) return err(401, 'Unauthorized');

  const { httpMethod, path, pathParameters } = event;
  const body = event.body ? JSON.parse(event.body) : {};
  const projectId = pathParameters?.projectId;
  const userId = claims.sub;

  // Routes
  if (httpMethod === 'GET'    && path === '/projects') return listProjects(userId);
  if (httpMethod === 'POST'   && path === '/projects') return createProject(userId, body);
  if (httpMethod === 'GET'    && path.startsWith('/projects/') && !path.includes('/thumbnail')) return getProject(userId, projectId);
  if (httpMethod === 'PUT'    && path.startsWith('/projects/') && !path.includes('/')) return updateProject(userId, projectId, body);
  if (httpMethod === 'DELETE' && path.startsWith('/projects/')) return deleteProject(userId, projectId);
  if (httpMethod === 'POST'   && path.endsWith('/duplicate')) return duplicateProject(userId, projectId);
  if (httpMethod === 'GET'    && path.endsWith('/thumbnail-upload-url')) return getThumbnailUploadUrl(userId, projectId);

  return err(404, 'Not found');
};
