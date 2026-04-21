// admin_panel/pages/login/index.tsx
// 4-step admin login: password → TOTP → email OTP → IP check

'use client';

import { useState } from 'react';

type Step = 'password' | 'totp' | 'email_otp' | 'done';

export default function AdminLoginPage() {
  const [step, setStep] = useState<Step>('password');
  const [partialToken, setPartialToken] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Form fields
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [totpCode, setTotpCode] = useState('');
  const [emailOtp, setEmailOtp] = useState('');

  async function handlePasswordSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); setError('');
    try {
      const res = await fetch('/api/admin/auth/step1', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Authentication failed');
      setPartialToken(data.partial_token);
      setStep('totp');
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleTotpSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); setError('');
    try {
      const res = await fetch('/api/admin/auth/step2', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ partial_token: partialToken, totp_code: totpCode }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Invalid TOTP code');
      setPartialToken(data.partial_token);

      // Request email OTP
      await fetch('/api/admin/auth/step3/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ partial_token: data.partial_token }),
      });
      setStep('email_otp');
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleOtpSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); setError('');
    try {
      // Step 3: verify email OTP
      const s3 = await fetch('/api/admin/auth/step3/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ partial_token: partialToken, otp: emailOtp }),
      });
      const d3 = await s3.json();
      if (!s3.ok) throw new Error(d3.error || 'Invalid OTP');

      // Step 4: IP check + get final tokens
      const s4 = await fetch('/api/admin/auth/step4', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ partial_token: d3.partial_token }),
      });
      const d4 = await s4.json();
      if (!s4.ok) throw new Error(d4.error || 'IP check failed');

      // Store token and redirect
      localStorage.setItem('admin_token', d4.access_token);
      localStorage.setItem('admin_refresh', d4.refresh_token);
      window.location.href = '/dashboard';
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  const stepLabels = ['Password', '2FA', 'Email OTP', 'Access'];

  return (
    <div style={{
      minHeight: '100vh', background: '#0f0f13',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: "'Segoe UI', system-ui, sans-serif",
    }}>
      <div style={{ width: 400, padding: 40, background: '#16161d', border: '1px solid #2a2a38', borderRadius: 16 }}>

        {/* Logo */}
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            width: 56, height: 56, background: 'linear-gradient(135deg,#7c6ef7,#4ecdc4)',
            borderRadius: 14, marginBottom: 16,
          }}>
            <span style={{ fontSize: 28 }}>🎬</span>
          </div>
          <div style={{ color: '#e8e6ff', fontSize: 20, fontWeight: 700 }}>Admin Panel</div>
          <div style={{ color: '#5c5a78', fontSize: 12, marginTop: 4 }}>Video Editor Pro</div>
        </div>

        {/* Step indicators */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginBottom: 28 }}>
          {stepLabels.map((label, i) => {
            const stepMap: Step[] = ['password', 'totp', 'email_otp', 'done'];
            const currentIdx = stepMap.indexOf(step);
            const isDone = i < currentIdx;
            const isActive = i === currentIdx;
            return (
              <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                <div style={{
                  width: 24, height: 24, borderRadius: '50%',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 10, fontWeight: 700,
                  background: isDone ? '#4ade80' : isActive ? '#7c6ef7' : '#2a2a38',
                  color: isDone || isActive ? '#fff' : '#5c5a78',
                  border: `2px solid ${isDone ? '#4ade80' : isActive ? '#7c6ef7' : '#3a3a48'}`,
                }}>
                  {isDone ? '✓' : i + 1}
                </div>
                {i < 3 && <div style={{ width: 20, height: 1, background: isDone ? '#4ade8050' : '#2a2a38' }} />}
              </div>
            );
          })}
        </div>

        {/* Error */}
        {error && (
          <div style={{ background: '#f76e6e15', border: '1px solid #f76e6e40', borderRadius: 8, padding: '10px 14px', color: '#f76e6e', fontSize: 13, marginBottom: 16 }}>
            {error}
          </div>
        )}

        {/* Step 1: Password */}
        {step === 'password' && (
          <form onSubmit={handlePasswordSubmit}>
            <p style={{ color: '#9d9bb8', fontSize: 13, marginBottom: 20, textAlign: 'center' }}>
              Enter your admin credentials
            </p>
            <InputField label="Email" type="email" value={email} onChange={setEmail} placeholder="admin@example.com" />
            <InputField label="Password" type="password" value={password} onChange={setPassword} placeholder="••••••••••••" />
            <SubmitButton loading={loading} label="Continue →" />
          </form>
        )}

        {/* Step 2: TOTP */}
        {step === 'totp' && (
          <form onSubmit={handleTotpSubmit}>
            <p style={{ color: '#9d9bb8', fontSize: 13, marginBottom: 20, textAlign: 'center' }}>
              Enter your 6-digit Google Authenticator code
            </p>
            <InputField
              label="Authenticator Code"
              type="text"
              value={totpCode}
              onChange={v => setTotpCode(v.replace(/\D/g, '').slice(0, 6))}
              placeholder="000000"
              autoFocus
              style={{ fontSize: 28, letterSpacing: 12, textAlign: 'center' }}
            />
            <SubmitButton loading={loading} label="Verify Code →" />
          </form>
        )}

        {/* Step 3: Email OTP */}
        {step === 'email_otp' && (
          <form onSubmit={handleOtpSubmit}>
            <p style={{ color: '#9d9bb8', fontSize: 13, marginBottom: 20, textAlign: 'center' }}>
              Check your email for a 6-digit verification code.<br />
              <span style={{ color: '#5c5a78', fontSize: 11 }}>Code expires in 5 minutes.</span>
            </p>
            <InputField
              label="Email Verification Code"
              type="text"
              value={emailOtp}
              onChange={v => setEmailOtp(v.replace(/\D/g, '').slice(0, 6))}
              placeholder="000000"
              autoFocus
              style={{ fontSize: 28, letterSpacing: 12, textAlign: 'center' }}
            />
            <SubmitButton loading={loading} label="Verify & Login →" />
          </form>
        )}

        <div style={{ textAlign: 'center', marginTop: 20, color: '#3a3a48', fontSize: 11 }}>
          🔒 Protected by 4-factor authentication
        </div>
      </div>
    </div>
  );
}

// ── Sub-components ─────────────────────────────────────────────────────────────

function InputField({ label, type, value, onChange, placeholder, autoFocus, style: extraStyle }: {
  label: string; type: string; value: string;
  onChange: (v: string) => void; placeholder?: string;
  autoFocus?: boolean; style?: React.CSSProperties;
}) {
  return (
    <div style={{ marginBottom: 16 }}>
      <label style={{ display: 'block', color: '#9d9bb8', fontSize: 12, fontWeight: 600, marginBottom: 6 }}>
        {label}
      </label>
      <input
        type={type}
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        autoFocus={autoFocus}
        required
        style={{
          width: '100%', padding: '11px 14px',
          background: '#0f0f13', border: '1px solid #2a2a38',
          borderRadius: 8, color: '#e8e6ff', fontSize: 15,
          outline: 'none', boxSizing: 'border-box',
          ...extraStyle,
        }}
      />
    </div>
  );
}

function SubmitButton({ loading, label }: { loading: boolean; label: string }) {
  return (
    <button
      type="submit"
      disabled={loading}
      style={{
        width: '100%', padding: '13px',
        background: loading ? '#7c6ef740' : 'linear-gradient(135deg,#7c6ef7,#4ecdc4)',
        border: 'none', borderRadius: 10,
        color: '#fff', fontSize: 15, fontWeight: 700,
        cursor: loading ? 'not-allowed' : 'pointer',
        marginTop: 8,
      }}
    >
      {loading ? '...' : label}
    </button>
  );
}
