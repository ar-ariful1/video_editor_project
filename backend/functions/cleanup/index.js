// backend/functions/cleanup/index.js
// Scheduled Lambda — runs nightly via EventBridge
// Deletes: expired exports, orphaned S3 files, old temp files

const { Pool } = require('pg');
const { S3Client, DeleteObjectCommand, ListObjectsV2Command, HeadObjectCommand } = require('@aws-sdk/client-s3');

const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const s3 = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const BUCKET = process.env.S3_BUCKET;

// ── Delete old completed exports (>30 days) ───────────────────────────────────
async function cleanupOldExports() {
  const rows = await db.query(
    `SELECT id, output_url FROM export_jobs
     WHERE status = 'done'
       AND completed_at < NOW() - INTERVAL '30 days'
     LIMIT 100`
  );

  let deleted = 0;
  for (const row of rows.rows) {
    try {
      if (row.output_url) {
        const key = row.output_url.split('.amazonaws.com/').pop() || row.output_url.split('.cloudfront.net/').pop();
        if (key) {
          await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
        }
      }
      await db.query(`UPDATE export_jobs SET output_url = NULL, status = 'purged' WHERE id = $1`, [row.id]);
      deleted++;
    } catch (e) {
      console.warn(`Failed to delete export ${row.id}:`, e.message);
    }
  }
  console.log(`Cleaned up ${deleted} old export files`);
  return deleted;
}

// ── Delete failed/cancelled exports (>7 days) ─────────────────────────────────
async function cleanupFailedExports() {
  const result = await db.query(
    `DELETE FROM export_jobs
     WHERE status IN ('failed','cancelled','purged')
       AND queued_at < NOW() - INTERVAL '7 days'
     RETURNING id`
  );
  console.log(`Deleted ${result.rowCount} failed/cancelled export records`);
  return result.rowCount;
}

// ── Delete orphaned S3 temp files (no DB reference) ──────────────────────────
async function cleanupOrphanedFiles() {
  if (!BUCKET) return 0;
  let deleted = 0;
  let continuationToken;

  do {
    const listRes = await s3.send(new ListObjectsV2Command({
      Bucket: BUCKET,
      Prefix: 'temp/',
      ContinuationToken: continuationToken,
      MaxKeys: 500,
    }));

    const objects = listRes.Contents || [];
    const cutoff  = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24h

    for (const obj of objects) {
      if (obj.LastModified && obj.LastModified < cutoff) {
        try {
          await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: obj.Key }));
          deleted++;
        } catch (_) {}
      }
    }
    continuationToken = listRes.NextContinuationToken;
  } while (continuationToken);

  console.log(`Deleted ${deleted} orphaned temp files`);
  return deleted;
}

// ── Delete inactive user upload artifacts (>90 days, user deleted) ────────────
async function cleanupDeletedUserData() {
  const rows = await db.query(
    `SELECT u.id, u.avatar_url FROM users u
     WHERE u.deleted_at IS NOT NULL
       AND u.deleted_at < NOW() - INTERVAL '90 days'
     LIMIT 50`
  );

  let cleaned = 0;
  for (const row of rows.rows) {
    try {
      if (row.avatar_url) {
        const key = row.avatar_url.split('.com/').pop();
        if (key) await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
      }
      await db.query(`DELETE FROM users WHERE id = $1`, [row.id]);
      cleaned++;
    } catch (_) {}
  }
  console.log(`Cleaned up ${cleaned} deleted user records`);
  return cleaned;
}

// ── Vacuum old analytics events (>6 months) ───────────────────────────────────
async function cleanupOldAnalytics() {
  const result = await db.query(
    `DELETE FROM analytics_events WHERE created_at < NOW() - INTERVAL '6 months'`
  );
  console.log(`Deleted ${result.rowCount} old analytics events`);
  return result.rowCount;
}

// ── Vacuum old search history (>3 months) ─────────────────────────────────────
async function cleanupSearchHistory() {
  const result = await db.query(
    `DELETE FROM search_history WHERE created_at < NOW() - INTERVAL '3 months'`
  );
  return result.rowCount;
}

// ── Lambda handler ─────────────────────────────────────────────────────────────
exports.handler = async (event) => {
  console.log('🧹 Running nightly cleanup job…');
  const results = {};

  try { results.oldExports      = await cleanupOldExports(); }      catch (e) { results.oldExportsErr      = e.message; }
  try { results.failedExports   = await cleanupFailedExports(); }    catch (e) { results.failedExportsErr   = e.message; }
  try { results.orphanedFiles   = await cleanupOrphanedFiles(); }    catch (e) { results.orphanedFilesErr   = e.message; }
  try { results.deletedUsers    = await cleanupDeletedUserData(); }   catch (e) { results.deletedUsersErr    = e.message; }
  try { results.analyticsEvents = await cleanupOldAnalytics(); }     catch (e) { results.analyticsErr       = e.message; }
  try { results.searchHistory   = await cleanupSearchHistory(); }    catch (e) { results.searchErr          = e.message; }

  console.log('✅ Cleanup complete:', results);
  return { statusCode: 200, body: JSON.stringify({ success: true, results }) };
};
