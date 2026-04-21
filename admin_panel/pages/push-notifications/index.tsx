// admin_panel/pages/push-notifications/index.tsx
'use client';
import { useState } from 'react';

const NOTIF_TYPES = ['general','template_drop','promo','export_complete','ai_done'];
const TARGET_OPTIONS = [
  { value: 'all',     label: 'All Users' },
  { value: 'free',    label: 'Free Plan Only' },
  { value: 'pro',     label: 'Pro Plan Only' },
  { value: 'premium', label: 'Premium Plan Only' },
];

interface NotifHistory { id: string; title: string; body: string; sent_count: number; sent_at: string; }

export default function PushNotificationsPage() {
  const [title, setTitle]   = useState('');
  const [body, setBody]     = useState('');
  const [type, setType]     = useState('general');
  const [target, setTarget] = useState('all');
  const [sending, setSending] = useState(false);
  const [result, setResult]   = useState<string | null>(null);
  const [history, setHistory] = useState<NotifHistory[]>([]);

  const h = () => ({ Authorization: `Bearer ${localStorage.getItem('admin_token')}`, 'Content-Type': 'application/json' });

  async function send() {
    if (!title.trim() || !body.trim()) return;
    setSending(true); setResult(null);
    try {
      const plan = target === 'all' ? undefined : target;
      const res = await fetch('/api/admin/push', {
        method: 'POST', headers: h(),
        body: JSON.stringify({ title, body, type, filter: { minPlan: plan } }),
      });
      const data = await res.json();
      setResult(`✅ Sent to ${data.sent ?? 0} devices`);
      setTitle(''); setBody('');
    } catch (e: any) {
      setResult(`❌ Failed: ${e.message}`);
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="page">
      <div className="page-header">
        <div><h1>Push Notifications</h1><p>Send targeted push notifications to users</p></div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: 20 }}>

        {/* Compose */}
        <div style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 14, padding: 24 }}>
          <h2 style={{ marginBottom: 20 }}>Compose</h2>

          <div className="form-group" style={{ marginBottom: 14 }}>
            <label>Title</label>
            <input value={title} onChange={e => setTitle(e.target.value)} placeholder="🎨 New Templates Just Dropped!" maxLength={60} />
            <span style={{ fontSize: 11, color: 'var(--text3)' }}>{title.length}/60</span>
          </div>

          <div className="form-group" style={{ marginBottom: 14 }}>
            <label>Body</label>
            <textarea value={body} onChange={e => setBody(e.target.value)} placeholder="20 new templates are ready to use…" maxLength={200} rows={3} style={{ padding: '9px 12px', background: 'var(--bg3)', border: '1px solid var(--border)', borderRadius: 8, color: 'var(--text)', fontSize: 13, width: '100%', resize: 'vertical', outline: 'none' }} />
            <span style={{ fontSize: 11, color: 'var(--text3)' }}>{body.length}/200</span>
          </div>

          <div className="form-grid" style={{ marginBottom: 14 }}>
            <div className="form-group">
              <label>Type</label>
              <select value={type} onChange={e => setType(e.target.value)}>
                {NOTIF_TYPES.map(t => <option key={t} value={t}>{t}</option>)}
              </select>
            </div>
            <div className="form-group">
              <label>Target Audience</label>
              <select value={target} onChange={e => setTarget(e.target.value)}>
                {TARGET_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
            </div>
          </div>

          {result && (
            <div style={{ padding: '10px 14px', borderRadius: 8, marginBottom: 14, background: result.startsWith('✅') ? '#4ade8015' : '#f76e6e15', border: `1px solid ${result.startsWith('✅') ? '#4ade8040' : '#f76e6e40'}`, color: result.startsWith('✅') ? 'var(--green)' : 'var(--accent4)', fontSize: 13 }}>
              {result}
            </div>
          )}

          <button className="btn-primary" onClick={send} disabled={sending || !title.trim() || !body.trim()} style={{ width: '100%', padding: '12px', opacity: sending ? 0.7 : 1 }}>
            {sending ? '⏳ Sending…' : '📤 Send Notification'}
          </button>
        </div>

        {/* Preview */}
        <div>
          <div style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 14, padding: 20 }}>
            <h2 style={{ marginBottom: 16 }}>Preview</h2>
            <div style={{ background: '#1c1c1e', borderRadius: 16, padding: 16 }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
                <div style={{ width: 36, height: 36, borderRadius: 8, background: 'linear-gradient(135deg,#7c6ef7,#4ecdc4)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, flexShrink: 0 }}>🎬</div>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}>
                    <span style={{ color: '#fff', fontSize: 13, fontWeight: 600 }}>Video Editor Pro</span>
                    <span style={{ color: '#8e8e93', fontSize: 11 }}>now</span>
                  </div>
                  <div style={{ color: '#fff', fontSize: 13, fontWeight: 600 }}>{title || 'Notification title'}</div>
                  <div style={{ color: '#ebebf599', fontSize: 12, marginTop: 2 }}>{body || 'Notification body text goes here…'}</div>
                </div>
              </div>
            </div>
            <p style={{ fontSize: 11, color: 'var(--text3)', marginTop: 12 }}>iOS notification preview</p>
          </div>
        </div>
      </div>
    </div>
  );
}
