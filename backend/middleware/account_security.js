// backend/middleware/account_security.js
// Account safety — device limit, suspicious login detection, token refresh

const jwt    = require('jsonwebtoken');
const crypto = require('crypto');
const { Pool } = require('pg');

const db         = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const JWT_SECRET = process.env.JWT_SECRET;
const MAX_DEVICES = parseInt(process.env.MAX_DEVICES_PER_USER || '3');

// ── Token management ──────────────────────────────────────────────────────────

function signAccessToken(userId, plan) {
  return jwt.sign({ sub: userId, plan, type: 'access' }, JWT_SECRET, { expiresIn: '15m', issuer: 'videoeditorpro' });
}

function signRefreshToken(userId, deviceId) {
  return jwt.sign({ sub: userId, deviceId, type: 'refresh' }, JWT_SECRET, { expiresIn: '30d', issuer: 'videoeditorpro' });
}

function verifyToken(token, expectedType) {
  try {
    const claims = jwt.verify(token, JWT_SECRET, { issuer: 'videoeditorpro' });
    if (claims.type !== expectedType) return null;
    return claims;
  } catch { return null; }
}

// ── Device fingerprint ────────────────────────────────────────────────────────

function deviceFingerprint(ip, userAgent, platform) {
  return crypto.createHash('sha256').update(`${ip}:${userAgent}:${platform}`).digest('hex').slice(0, 16);
}

// ── Register device ───────────────────────────────────────────────────────────

async function registerDevice(userId, deviceId, deviceName, platform, ip) {
  // Count active devices
  const active = await db.query(
    'SELECT COUNT(*) FROM user_devices WHERE user_id = $1 AND is_revoked = FALSE',
    [userId]
  );

  if (parseInt(active.rows[0].count) >= MAX_DEVICES) {
    // Get oldest device to evict (LRU)
    const oldest = await db.query(
      'SELECT id FROM user_devices WHERE user_id = $1 AND is_revoked = FALSE ORDER BY last_active_at ASC LIMIT 1',
      [userId]
    );
    if (oldest.rows.length) {
      await db.query('UPDATE user_devices SET is_revoked = TRUE WHERE id = $1', [oldest.rows[0].id]);
    }
  }

  await db.query(`
    INSERT INTO user_devices (user_id, device_id, device_name, platform, ip_address, registered_at, last_active_at)
    VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
    ON CONFLICT (user_id, device_id) DO UPDATE
    SET last_active_at = NOW(), ip_address = $5, is_revoked = FALSE`,
    [userId, deviceId, deviceName, platform, ip]
  );
}

// ── Check device is allowed ───────────────────────────────────────────────────

async function isDeviceAllowed(userId, deviceId) {
  const row = await db.query(
    'SELECT is_revoked FROM user_devices WHERE user_id = $1 AND device_id = $2',
    [userId, deviceId]
  );
  if (!row.rows.length) return false; // unknown device
  return !row.rows[0].is_revoked;
}

// ── Suspicious login detection ────────────────────────────────────────────────

async function detectSuspiciousLogin(userId, ip, userAgent, platform) {
  const signals = [];

  // 1. New device from different country (simplified: new IP range)
  const recent = await db.query(
    `SELECT DISTINCT ip_address FROM user_devices WHERE user_id = $1 ORDER BY last_active_at DESC LIMIT 5`,
    [userId]
  );
  const knownIPs = recent.rows.map(r => r.ip_address);
  const ipPrefix = ip.split('.').slice(0, 2).join('.');
  const knownPrefix = knownIPs.some(known => known.startsWith(ipPrefix));
  if (!knownPrefix && knownIPs.length > 0) signals.push('new_ip_range');

  // 2. Too many login attempts in short time
  const recentAttempts = await db.query(
    `SELECT COUNT(*) FROM auth_logs WHERE user_id = $1 AND created_at > NOW() - INTERVAL '10 minutes'`,
    [userId]
  );
  if (parseInt(recentAttempts.rows[0].count) > 10) signals.push('too_many_attempts');

  // 3. Login from multiple countries simultaneously
  const recentLogins = await db.query(
    `SELECT ip_address FROM auth_logs WHERE user_id = $1 AND created_at > NOW() - INTERVAL '30 minutes' AND success = TRUE`,
    [userId]
  );
  if (recentLogins.rows.length > 1) {
    const prefixes = new Set(recentLogins.rows.map(r => r.ip_address.split('.').slice(0,2).join('.')));
    if (prefixes.size > 1) signals.push('concurrent_locations');
  }

  const suspicious = signals.length > 0;

  if (suspicious) {
    await db.query(
      `INSERT INTO security_events (user_id, type, ip_address, signals, created_at)
       VALUES ($1, 'suspicious_login', $2, $3, NOW())`,
      [userId, ip, JSON.stringify(signals)]
    ).catch(() => {});

    // Notify user via email (would trigger notification Lambda)
    console.log(`⚠️ Suspicious login for user ${userId}: ${signals.join(', ')}`);
  }

  return { suspicious, signals };
}

// ── Refresh token endpoint ────────────────────────────────────────────────────

async function refreshAccessToken(refreshToken, deviceId) {
  const claims = verifyToken(refreshToken, 'refresh');
  if (!claims) return { error: 'Invalid refresh token' };
  if (claims.deviceId !== deviceId) return { error: 'Device mismatch' };

  // Check if device is still allowed
  const allowed = await isDeviceAllowed(claims.sub, deviceId);
  if (!allowed) return { error: 'Device revoked. Please sign in again.' };

  // Get user plan
  const userRow = await db.query(
    `SELECT COALESCE(s.plan,'free') as plan FROM users u
     LEFT JOIN subscriptions s ON s.id = u.subscription_id WHERE u.id = $1`,
    [claims.sub]
  );
  const plan = userRow.rows[0]?.plan || 'free';

  // Update device last active
  await db.query(
    'UPDATE user_devices SET last_active_at = NOW() WHERE user_id = $1 AND device_id = $2',
    [claims.sub, deviceId]
  );

  return {
    access_token:  signAccessToken(claims.sub, plan),
    refresh_token: signRefreshToken(claims.sub, deviceId), // rotate refresh token
    plan,
  };
}

// ── Revoke device ─────────────────────────────────────────────────────────────

async function revokeDevice(userId, deviceId) {
  await db.query(
    'UPDATE user_devices SET is_revoked = TRUE WHERE user_id = $1 AND device_id = $2',
    [userId, deviceId]
  );
}

async function revokeAllDevices(userId) {
  await db.query('UPDATE user_devices SET is_revoked = TRUE WHERE user_id = $1', [userId]);
}

// ── List user devices ─────────────────────────────────────────────────────────

async function listDevices(userId) {
  const rows = await db.query(
    `SELECT device_id, device_name, platform, ip_address, registered_at, last_active_at, is_revoked
     FROM user_devices WHERE user_id = $1 ORDER BY last_active_at DESC`,
    [userId]
  );
  return rows.rows;
}

// ── Lambda handler ─────────────────────────────────────────────────────────────

async function handler(event) {
  const { httpMethod, path } = event;
  const body  = event.body ? JSON.parse(event.body) : {};
  const pp    = event.pathParameters || {};
  const hdr   = event.headers || {};
  const ip    = event.requestContext?.identity?.sourceIp || hdr['x-forwarded-for'] || '0.0.0.0';

  const resp = (code, data) => ({
    statusCode: code,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    body: JSON.stringify(data),
  });

  if (httpMethod === 'POST' && path === '/auth/refresh') {
    const result = await refreshAccessToken(body.refresh_token, body.device_id);
    return result.error ? resp(401, result) : resp(200, result);
  }

  if (httpMethod === 'GET' && path === '/auth/devices') {
    const claims = verifyToken((hdr.Authorization || '').replace('Bearer ', ''), 'access');
    if (!claims) return resp(401, { error: 'Unauthorized' });
    return resp(200, { devices: await listDevices(claims.sub) });
  }

  if (httpMethod === 'DELETE' && pp.deviceId) {
    const claims = verifyToken((hdr.Authorization || '').replace('Bearer ', ''), 'access');
    if (!claims) return resp(401, { error: 'Unauthorized' });
    await revokeDevice(claims.sub, pp.deviceId);
    return resp(200, { revoked: true });
  }

  return resp(404, { error: 'Not found' });
}

module.exports = { handler, signAccessToken, signRefreshToken, verifyToken, registerDevice, isDeviceAllowed, detectSuspiciousLogin, refreshAccessToken, revokeDevice, revokeAllDevices, listDevices };
