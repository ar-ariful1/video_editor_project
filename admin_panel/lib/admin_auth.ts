// admin_panel/lib/admin_auth.ts
// Multi-step admin authentication: hidden URL + bcrypt + TOTP + email OTP + IP allowlist

import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { authenticator } from 'otplib';
import crypto from 'crypto';
import nodemailer from 'nodemailer';
import { Pool } from 'pg';
import { NextRequest, NextResponse } from 'next/server';

const db = new Pool({ connectionString: process.env.DATABASE_URL });
const ADMIN_JWT_SECRET = process.env.ADMIN_JWT_SECRET!;
const TOTP_ENCRYPTION_KEY = process.env.TOTP_ENCRYPTION_KEY!; // 32-byte hex key
const ADMIN_SESSION_DURATION = '15m';    // Short-lived JWT
const ADMIN_REFRESH_DURATION = '8h';

// ── TOTP Encryption (AES-256-GCM) ────────────────────────────────────────────

function encryptTOTP(secret: string): string {
  const key = Buffer.from(TOTP_ENCRYPTION_KEY, 'hex');
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(secret, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${tag.toString('hex')}:${encrypted.toString('hex')}`;
}

function decryptTOTP(stored: string): string {
  const [ivHex, tagHex, encHex] = stored.split(':');
  const key = Buffer.from(TOTP_ENCRYPTION_KEY, 'hex');
  const iv = Buffer.from(ivHex, 'hex');
  const tag = Buffer.from(tagHex, 'hex');
  const encrypted = Buffer.from(encHex, 'hex');
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return decipher.update(encrypted) + decipher.final('utf8');
}

// ── OTP Store (Redis in production, memory here) ──────────────────────────────

const otpStore = new Map<string, { otp: string; expiresAt: number }>();

function generateOTP(): string {
  return crypto.randomInt(100000, 999999).toString();
}

async function sendOTPEmail(email: string, otp: string): Promise<void> {
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587'),
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });

  await transporter.sendMail({
    from: process.env.SMTP_FROM,
    to: email,
    subject: `[Video Editor Admin] Login Verification Code`,
    html: `
      <div style="font-family: monospace; max-width: 400px; margin: 40px auto; padding: 24px; background: #16161d; border: 1px solid #2a2a38; border-radius: 12px;">
        <h2 style="color: #7c6ef7; margin: 0 0 16px;">Admin Login Code</h2>
        <p style="color: #9d9bb8; margin: 0 0 20px;">Your verification code expires in 5 minutes.</p>
        <div style="font-size: 36px; font-weight: 700; color: #e8e6ff; letter-spacing: 8px; text-align: center; padding: 20px; background: #0f0f13; border-radius: 8px;">${otp}</div>
        <p style="color: #5c5a78; font-size: 12px; margin: 16px 0 0;">If you did not request this code, your account may be compromised.</p>
      </div>
    `,
  });
}

// ── Step 1: Email + Password ──────────────────────────────────────────────────

export async function step1_passwordAuth(email: string, password: string, clientIP: string) {
  // Find admin
  const result = await db.query(
    'SELECT * FROM admins WHERE email = $1 AND is_active = TRUE',
    [email.toLowerCase()]
  );

  if (!result.rows.length) {
    // Constant-time comparison to prevent timing attacks
    await bcrypt.compare(password, '$2b$12$invalidhashfortimingattackprevention');
    throw new Error('Invalid credentials');
  }

  const admin = result.rows[0];

  // Check account lock
  if (admin.locked_until && new Date(admin.locked_until) > new Date()) {
    const minutesLeft = Math.ceil((new Date(admin.locked_until).getTime() - Date.now()) / 60000);
    throw new Error(`Account locked. Try again in ${minutesLeft} minutes.`);
  }

  // Verify password
  const valid = await bcrypt.compare(password, admin.password_hash);
  if (!valid) {
    // Increment failed attempts
    const attempts = (admin.login_attempts || 0) + 1;
    const lockUntil = attempts >= 5 ? new Date(Date.now() + 30 * 60 * 1000) : null;
    await db.query(
      'UPDATE admins SET login_attempts = $1, locked_until = $2 WHERE id = $3',
      [attempts, lockUntil, admin.id]
    );
    throw new Error('Invalid credentials');
  }

  // Reset failed attempts
  await db.query('UPDATE admins SET login_attempts = 0, locked_until = NULL WHERE id = $1', [admin.id]);

  // Issue step-1 partial token (expires in 10 minutes)
  const partial_token = jwt.sign(
    { sub: admin.id, step: 1, email: admin.email, role: admin.role },
    ADMIN_JWT_SECRET,
    { expiresIn: '10m' }
  );

  return { partial_token, next_step: 'totp', admin_id: admin.id };
}

// ── Step 2: TOTP (Google Authenticator) ──────────────────────────────────────

export async function step2_totpAuth(partial_token: string, totp_code: string) {
  const claims = jwt.verify(partial_token, ADMIN_JWT_SECRET) as jwt.JwtPayload;
  if (claims.step !== 1) throw new Error('Invalid auth step');

  const result = await db.query('SELECT totp_secret FROM admins WHERE id = $1', [claims.sub]);
  if (!result.rows[0]?.totp_secret) throw new Error('TOTP not configured');

  const secret = decryptTOTP(result.rows[0].totp_secret);
  const valid = authenticator.check(totp_code, secret);
  if (!valid) throw new Error('Invalid TOTP code');

  // Issue step-2 partial token
  const partial_token_2 = jwt.sign(
    { sub: claims.sub, step: 2, email: claims.email, role: claims.role },
    ADMIN_JWT_SECRET,
    { expiresIn: '10m' }
  );

  return { partial_token: partial_token_2, next_step: 'email_otp' };
}

// ── Step 3: Email OTP ─────────────────────────────────────────────────────────

export async function step3_requestEmailOTP(partial_token: string) {
  const claims = jwt.verify(partial_token, ADMIN_JWT_SECRET) as jwt.JwtPayload;
  if (claims.step !== 2) throw new Error('Invalid auth step');

  const otp = generateOTP();
  otpStore.set(claims.sub, { otp, expiresAt: Date.now() + 5 * 60 * 1000 });
  await sendOTPEmail(claims.email, otp);

  return { message: `OTP sent to ${claims.email}` };
}

export async function step3_verifyEmailOTP(partial_token: string, otp: string) {
  const claims = jwt.verify(partial_token, ADMIN_JWT_SECRET) as jwt.JwtPayload;
  if (claims.step !== 2) throw new Error('Invalid auth step');

  const stored = otpStore.get(claims.sub);
  if (!stored || Date.now() > stored.expiresAt) throw new Error('OTP expired');
  if (stored.otp !== otp) throw new Error('Invalid OTP');

  otpStore.delete(claims.sub);

  // Issue step-3 partial token
  const partial_token_3 = jwt.sign(
    { sub: claims.sub, step: 3, email: claims.email, role: claims.role },
    ADMIN_JWT_SECRET,
    { expiresIn: '10m' }
  );

  return { partial_token: partial_token_3, next_step: 'ip_check' };
}

// ── Step 4: IP Allowlist ──────────────────────────────────────────────────────

export async function step4_ipCheck(partial_token: string, clientIP: string) {
  const claims = jwt.verify(partial_token, ADMIN_JWT_SECRET) as jwt.JwtPayload;
  if (claims.step !== 3) throw new Error('Invalid auth step');

  const result = await db.query('SELECT allowed_ips, role FROM admins WHERE id = $1', [claims.sub]);
  const admin = result.rows[0];
  const allowedIPs: string[] = admin.allowed_ips || [];

  // If no IPs configured, skip check (only for super_admin setup)
  if (allowedIPs.length > 0 && !allowedIPs.includes(clientIP)) {
    // Log the attempt
    await db.query(
      "INSERT INTO audit_logs (admin_id, action, ip_address, metadata) VALUES ($1, 'login.ip_blocked', $2, $3)",
      [claims.sub, clientIP, JSON.stringify({ attempted_ip: clientIP, allowed_ips: allowedIPs })]
    );
    throw new Error('Access denied from this IP address');
  }

  // Issue final tokens
  const access_token = jwt.sign(
    { sub: claims.sub, email: claims.email, role: claims.role, type: 'admin' },
    ADMIN_JWT_SECRET,
    { expiresIn: ADMIN_SESSION_DURATION }
  );
  const refresh_token = jwt.sign(
    { sub: claims.sub, type: 'admin_refresh' },
    ADMIN_JWT_SECRET,
    { expiresIn: ADMIN_REFRESH_DURATION }
  );

  // Log successful login
  await db.query(
    "UPDATE admins SET last_login_at = NOW() WHERE id = $1",
    [claims.sub]
  );
  await db.query(
    "INSERT INTO audit_logs (admin_id, action, ip_address, metadata) VALUES ($1, 'login.success', $2, $3)",
    [claims.sub, clientIP, JSON.stringify({ role: claims.role })]
  );

  return {
    access_token,
    refresh_token,
    admin: { id: claims.sub, email: claims.email, role: claims.role },
  };
}

// ── TOTP Setup ────────────────────────────────────────────────────────────────

export async function setupTOTP(adminId: string) {
  const secret = authenticator.generateSecret();
  const encryptedSecret = encryptTOTP(secret);

  // Get admin email for QR code
  const result = await db.query('SELECT email FROM admins WHERE id = $1', [adminId]);
  const email = result.rows[0]?.email;

  const otpAuthUrl = authenticator.keyuri(email, 'VideoEditor Admin', secret);

  return {
    secret,          // Show to admin once to set up in authenticator app
    otpAuthUrl,      // For QR code generation
    encryptedSecret, // Store this in DB
  };
}

export async function saveTOTPSecret(adminId: string, encryptedSecret: string) {
  await db.query('UPDATE admins SET totp_secret = $1 WHERE id = $2', [encryptedSecret, adminId]);
}

// ── Middleware ─────────────────────────────────────────────────────────────────

export function requireAdminRole(...roles: string[]) {
  return (handler: Function) => async (req: NextRequest) => {
    const token = req.headers.get('Authorization')?.replace('Bearer ', '');
    if (!token) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    try {
      const claims = jwt.verify(token, ADMIN_JWT_SECRET) as jwt.JwtPayload;
      if (claims.type !== 'admin') return NextResponse.json({ error: 'Not an admin token' }, { status: 403 });
      if (roles.length > 0 && !roles.includes(claims.role)) {
        return NextResponse.json({ error: 'Insufficient permissions' }, { status: 403 });
      }
      (req as any).admin = claims;
      return handler(req);
    } catch {
      return NextResponse.json({ error: 'Invalid or expired token' }, { status: 401 });
    }
  };
}

// ── Admin Password Hash (for setup) ──────────────────────────────────────────

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 12);
}
