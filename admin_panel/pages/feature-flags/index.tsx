// admin_panel/pages/feature-flags/index.tsx
'use client';
import { useEffect, useState } from 'react';

interface Flag { id: string; key: string; value: any; description: string; rollout_percentage: number; is_enabled: boolean; updated_at: string; }

export default function FeatureFlagsPage() {
  const [flags, setFlags] = useState<Flag[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<Flag | null>(null);

  const h = () => ({ Authorization: `Bearer ${localStorage.getItem('admin_token')}`, 'Content-Type': 'application/json' });

  useEffect(() => { load(); }, []);

  async function load() {
    setLoading(true);
    const res = await fetch('/api/admin/feature-flags', { headers: h() });
    const d = await res.json();
    setFlags(d.flags || []); setLoading(false);
  }

  async function toggle(id: string, enabled: boolean) {
    await fetch(`/api/admin/feature-flags/${id}`, { method: 'PATCH', headers: h(), body: JSON.stringify({ is_enabled: enabled }) });
    load();
  }

  async function saveEdit() {
    if (!editing) return;
    await fetch(`/api/admin/feature-flags/${editing.id}`, { method: 'PATCH', headers: h(), body: JSON.stringify({ rollout_percentage: editing.rollout_percentage, value: editing.value }) });
    setEditing(null); load();
  }

  return (
    <div className="page">
      <div className="page-header">
        <div><h1>Feature Flags</h1><p>Control feature rollout without deployments</p></div>
      </div>

      {loading ? <div className="loading">Loading…</div> : (
        <table className="admin-table">
          <thead><tr><th>Flag Key</th><th>Description</th><th>Rollout</th><th>Value</th><th>Enabled</th><th>Actions</th></tr></thead>
          <tbody>
            {flags.map(f => (
              <tr key={f.id}>
                <td style={{ fontFamily: 'monospace', color: '#7c6ef7', fontSize: 13 }}>{f.key}</td>
                <td style={{ color: '#9d9bb8', fontSize: 13 }}>{f.description || '—'}</td>
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 60, height: 4, background: '#2a2a38', borderRadius: 2, overflow: 'hidden' }}>
                      <div style={{ width: `${f.rollout_percentage}%`, height: '100%', background: '#7c6ef7', borderRadius: 2 }} />
                    </div>
                    <span style={{ color: '#9d9bb8', fontSize: 11 }}>{f.rollout_percentage}%</span>
                  </div>
                </td>
                <td style={{ fontFamily: 'monospace', color: '#4ecdc4', fontSize: 12 }}>{JSON.stringify(f.value)}</td>
                <td>
                  <label style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ position: 'relative', width: 36, height: 20, background: f.is_enabled ? '#7c6ef7' : '#2a2a38', borderRadius: 10, transition: 'background .2s', cursor: 'pointer' }} onClick={() => toggle(f.id, !f.is_enabled)}>
                      <div style={{ position: 'absolute', top: 2, left: f.is_enabled ? 18 : 2, width: 16, height: 16, background: '#fff', borderRadius: '50%', transition: 'left .2s' }} />
                    </div>
                    <span style={{ color: f.is_enabled ? '#4ade80' : '#5c5a78', fontSize: 12 }}>{f.is_enabled ? 'On' : 'Off'}</span>
                  </label>
                </td>
                <td><button className="btn-sm" onClick={() => setEditing(f)}>Edit</button></td>
              </tr>
            ))}
            {flags.length === 0 && <tr><td colSpan={6} style={{ textAlign: 'center', padding: 40, color: '#5c5a78' }}>No feature flags configured</td></tr>}
          </tbody>
        </table>
      )}

      {editing && (
        <div className="modal-overlay" onClick={() => setEditing(null)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header"><h2>Edit: {editing.key}</h2><button className="modal-close" onClick={() => setEditing(null)}>✕</button></div>
            <div className="modal-body">
              <div className="form-group" style={{ marginBottom: 14 }}>
                <label>Rollout Percentage</label>
                <input type="range" min={0} max={100} value={editing.rollout_percentage}
                  onChange={e => setEditing(f => f ? {...f, rollout_percentage: parseInt(e.target.value)} : null)} />
                <span style={{ color: '#9d9bb8', fontSize: 13 }}>{editing.rollout_percentage}% of users</span>
              </div>
              <div className="form-group">
                <label>Value (JSON)</label>
                <input value={JSON.stringify(editing.value)}
                  onChange={e => { try { setEditing(f => f ? {...f, value: JSON.parse(e.target.value)} : null); } catch {} }} />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-secondary" onClick={() => setEditing(null)}>Cancel</button>
              <button className="btn-primary" onClick={saveEdit}>Save</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
