// admin_panel/pages/moderation/index.tsx
'use client';
import { useEffect, useState } from 'react';

interface Report { id: string; reporter_id: string; target_type: string; target_id: string; reason: string; description: string; status: string; created_at: string; }

export default function ModerationPage() {
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('pending');

  const h = () => ({ Authorization: `Bearer ${localStorage.getItem('admin_token')}`, 'Content-Type': 'application/json' });

  useEffect(() => { load(); }, [filter]);

  async function load() {
    setLoading(true);
    const res = await fetch(`/api/admin/moderation?status=${filter}`, { headers: h() });
    const d = await res.json();
    setReports(d.reports || []); setLoading(false);
  }

  async function action(id: string, status: 'reviewed' | 'dismissed' | 'actioned') {
    await fetch(`/api/admin/moderation/${id}`, { method: 'PATCH', headers: h(), body: JSON.stringify({ status }) });
    load();
  }

  const STATUS_COLORS: Record<string, string> = { pending: '#f7c948', reviewed: '#4ecdc4', dismissed: '#5c5a78', actioned: '#f76e6e' };

  return (
    <div className="page">
      <div className="page-header">
        <div><h1>Moderation Queue</h1><p>Review reported content and take action</p></div>
      </div>

      <div className="filter-tabs" style={{ marginBottom: 20 }}>
        {['pending','reviewed','dismissed','actioned'].map(s => (
          <button key={s} className={`filter-tab ${filter === s ? 'active' : ''}`} onClick={() => setFilter(s)}>
            {s.charAt(0).toUpperCase() + s.slice(1)}
          </button>
        ))}
      </div>

      {loading ? <div className="loading">Loading reports…</div> : (
        <table className="admin-table">
          <thead><tr><th>Type</th><th>Target</th><th>Reason</th><th>Description</th><th>Status</th><th>Reported</th><th>Actions</th></tr></thead>
          <tbody>
            {reports.map(r => (
              <tr key={r.id}>
                <td><span style={{ background: '#7c6ef720', color: '#7c6ef7', padding: '3px 8px', borderRadius: 4, fontSize: 11, fontWeight: 700 }}>{r.target_type.toUpperCase()}</span></td>
                <td style={{ fontFamily: 'monospace', fontSize: 11, color: '#5c5a78' }}>{r.target_id.slice(0,8)}…</td>
                <td style={{ color: '#e8e6ff', fontSize: 13 }}>{r.reason}</td>
                <td style={{ color: '#9d9bb8', fontSize: 12, maxWidth: 200 }}>{r.description || '—'}</td>
                <td><span style={{ background: `${STATUS_COLORS[r.status]}20`, color: STATUS_COLORS[r.status], padding: '3px 8px', borderRadius: 4, fontSize: 11, fontWeight: 700, border: `1px solid ${STATUS_COLORS[r.status]}40` }}>{r.status}</span></td>
                <td className="date-cell">{new Date(r.created_at).toLocaleDateString()}</td>
                <td>
                  {r.status === 'pending' && (
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn-sm" onClick={() => action(r.id, 'actioned')} style={{ color: '#f76e6e' }}>Remove</button>
                      <button className="btn-sm" onClick={() => action(r.id, 'dismissed')}>Dismiss</button>
                      <button className="btn-sm" onClick={() => action(r.id, 'reviewed')}>Reviewed</button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {reports.length === 0 && (
              <tr><td colSpan={7} style={{ textAlign: 'center', padding: 40, color: '#5c5a78' }}>No {filter} reports</td></tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
