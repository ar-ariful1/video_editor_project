// backend/functions/exports/index.js
// Export job queue — submit, poll, cancel
const { Pool } = require('pg');
const { SQSClient, SendMessageCommand, DeleteMessageCommand } = require('@aws-sdk/client-sqs');
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const db  = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const sqs = new SQSClient({ region: process.env.AWS_REGION || 'us-east-1' });
const s3  = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

const QUEUE_URL  = process.env.EXPORT_QUEUE_URL;
const S3_BUCKET  = process.env.S3_BUCKET;
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

// ── Submit export job ──────────────────────────────────────────────────────────
async function submitExport(userId, body) {
  const { project_id, quality, watermarked = false } = body;
  if (!project_id || !quality) return resp(400, { error: 'project_id and quality required' });

  // Plan check
  const userRow = await db.query(`
    SELECT u.id, COALESCE(s.plan,'free') as plan
    FROM users u LEFT JOIN subscriptions s ON s.id = u.subscription_id
    WHERE u.id = $1`, [userId]);
  const plan = userRow.rows[0]?.plan || 'free';

  if (quality === '4k' && plan !== 'premium') return resp(403, { error: 'Premium plan required for 4K export' });
  if (quality === '1080p' && plan === 'free')  return resp(403, { error: 'Pro plan required for 1080p export' });

  const jobId = uuidv4();
  const priority = plan === 'premium' ? 10 : plan === 'pro' ? 5 : 0;

  await db.query(
    `INSERT INTO export_jobs (id, project_id, user_id, quality, watermarked, priority)
     VALUES ($1,$2,$3,$4,$5,$6)`,
    [jobId, project_id, userId, quality, plan === 'free' ? true : watermarked, priority]
  );

  // Send to SQS
  if (QUEUE_URL) {
    await sqs.send(new SendMessageCommand({
      QueueUrl: QUEUE_URL,
      MessageBody: JSON.stringify({ job_id: jobId, project_id, user_id: userId, quality, watermarked: plan === 'free' ? true : watermarked }),
      MessageGroupId: userId,
      MessageDeduplicationId: jobId,
      MessageAttributes: { Priority: { DataType: 'Number', StringValue: String(priority) } },
    }));
  }

  return resp(202, { job_id: jobId, status: 'queued', estimated_wait_seconds: 30 });
}

// ── Get export status ──────────────────────────────────────────────────────────
async function getStatus(userId, jobId) {
  const row = await db.query(
    `SELECT id, status, quality, progress, output_url, error_message, queued_at, started_at, completed_at
     FROM export_jobs WHERE id = $1 AND user_id = $2`,
    [jobId, userId]
  );
  if (!row.rows.length) return resp(404, { error: 'Job not found' });

  const job = row.rows[0];

  // Generate presigned URL if done
  if (job.status === 'done' && job.output_url) {
    const key = job.output_url.replace(`https://${S3_BUCKET}.s3.amazonaws.com/`, '');
    job.download_url = await getSignedUrl(s3, new GetObjectCommand({ Bucket: S3_BUCKET, Key: key }), { expiresIn: 3600 });
  }

  return resp(200, job);
}

// ── List user exports ──────────────────────────────────────────────────────────
async function listExports(userId) {
  const rows = await db.query(
    `SELECT ej.id, ej.quality, ej.status, ej.progress, ej.output_url, ej.queued_at, ej.completed_at,
            p.title as project_title
     FROM export_jobs ej
     JOIN projects p ON p.id = ej.project_id
     WHERE ej.user_id = $1
     ORDER BY ej.queued_at DESC LIMIT 20`,
    [userId]
  );
  return resp(200, { exports: rows.rows });
}

// ── Cancel export ─────────────────────────────────────────────────────────────
async function cancelExport(userId, jobId) {
  const row = await db.query(
    `UPDATE export_jobs SET status = 'cancelled' WHERE id = $1 AND user_id = $2 AND status IN ('queued','processing')
     RETURNING id`,
    [jobId, userId]
  );
  if (!row.rows.length) return resp(404, { error: 'Job not found or already completed' });
  return resp(200, { cancelled: true });
}

// ── Worker: update job progress (called by SQS worker Lambda) ────────────────
async function updateJobProgress(jobId, progress, status, outputUrl, errorMessage) {
  const sets = ['progress = $2', 'status = $3'];
  const params = [jobId, progress, status];
  if (status === 'processing' && !await isStarted(jobId)) {
    sets.push('started_at = NOW()');
  }
  if (status === 'done' || status === 'failed') {
    sets.push('completed_at = NOW()');
    if (outputUrl)     { params.push(outputUrl);     sets.push(`output_url = $${params.length}`); }
    if (errorMessage)  { params.push(errorMessage);  sets.push(`error_message = $${params.length}`); }
  }
  await db.query(`UPDATE export_jobs SET ${sets.join(', ')} WHERE id = $1`, params);
  return resp(200, { updated: true });
}

async function isStarted(jobId) {
  const r = await db.query('SELECT started_at FROM export_jobs WHERE id = $1', [jobId]);
  return r.rows[0]?.started_at != null;
}

// ── Lambda handler ─────────────────────────────────────────────────────────────
exports.handler = async (event) => {
  const { httpMethod, path, pathParameters } = event;
  const body = event.body ? JSON.parse(event.body) : {};
  const query = event.queryStringParameters || {};

  const claims = requireAuth(event);

  // Internal worker calls (no auth)
  if (httpMethod === 'PATCH' && path.includes('/internal/progress')) {
    return updateJobProgress(body.job_id, body.progress, body.status, body.output_url, body.error_message);
  }

  if (!claims) return resp(401, { error: 'Unauthorized' });

  if (httpMethod === 'POST' && path === '/exports')       return submitExport(claims.sub, body);
  if (httpMethod === 'GET'  && path === '/exports')       return listExports(claims.sub);
  if (httpMethod === 'GET'  && pathParameters?.jobId)     return getStatus(claims.sub, pathParameters.jobId);
  if (httpMethod === 'DELETE' && pathParameters?.jobId)   return cancelExport(claims.sub, pathParameters.jobId);

  return resp(404, { error: 'Not found' });
};
