// admin_panel/pages/exports/index.tsx
'use client';
import { useEffect, useState } from 'react';

interface ExportJob { id: string; project_title: string; quality: string; status: string; progress: number; user_email: string; queued_at: string; started_at?: string; completed_at?: string; }

export default function ExportsPage() {
  const [jobs, setJobs] = useState<ExportJob[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('active');
  const [autoRefresh, setAutoRefresh] = useState(true);

  const h = () => ({ Authorization: `Bearer ${localStorage.getItem('admin_token')}` });

  useEffect(() => {
    load();
    if (autoRefresh) { const t = setInterval(load, 5000); return () => clearInterval(t); }
  }, [filter, autoRefresh]);

  async function load() {
    try {
      const res = await fetch(`/api/admin/exports?status=${filter}`, { headers: h() });
      const d = await res.json();
      setJobs(d.jobs || []);
    } finally { setLoading(false); }
  }

  async function cancelJob(id: string) {
    await fetch(`/api/admin/exports/${id}`, { method: 'DELETE', headers: h() });
    load();
  }

  const STATUS_COLOR: Record<string,string> = { queued: '#f7c948', processing: '#7c6ef7', done: '#4ade80', failed: '#f76e6e', cancelled: '#5c5a78' };
  const active = jobs.filter(j => ['queued','processing'].includes(j.status));
  const done   = jobs.filter(j => j.status === 'done');
  const failed = jobs.filter(j => j.status === 'failed');

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>Export Queue</h1>
          <p>{active.length} active · {done.length} done · {failed.length} failed</p>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: 'var(--text2)', cursor: 'pointer' }}>
            <input type="checkbox" checked={autoRefresh} onChange={e => setAutoRefresh(e.target.checked)} />
            Auto-refresh (5s)
          </label>
          <button className="btn-secondary" onClick={load}>⟳ Refresh</button>
        </div>
      </div>

      <div className="filter-tabs" style={{ marginBottom: 20 }}>
        {['active','done','failed','all'].map(s => (
          <button key={s} className={`filter-tab ${filter === s ? 'active' : ''}`} onClick={() => setFilter(s)}>
            {s.charAt(0).toUpperCase() + s.slice(1)}
          </button>
        ))}
      </div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 10, marginBottom: 20 }}>
        {[
          { label: 'In Queue', value: jobs.filter(j=>j.status==='queued').length, color: '#f7c948' },
          { label: 'Processing', value: jobs.filter(j=>j.status==='processing').length, color: '#7c6ef7' },
          { label: 'Completed', value: done.length, color: '#4ade80' },
          { label: 'Failed', value: failed.length, color: '#f76e6e' },
        ].map((s,i) => (
          <div key={i} style={{ background: `${s.color}10`, border: `1px solid ${s.color}30`, borderRadius: 10, padding: '12px 16px' }}>
            <div style={{ fontSize: 24, fontWeight: 700, color: s.color }}>{s.value}</div>
            <div style={{ fontSize: 12, color: 'var(--text3)' }}>{s.label}</div>
          </div>
        ))}
      </div>

      {loading ? <div className="loading">Loading…</div> : (
        <table className="admin-table">
          <thead><tr><th>Project</th><th>Quality</th><th>User</th><th>Status</th><th>Progress</th><th>Time</th><th>Action</th></tr></thead>
          <tbody>
            {jobs.map(j => (
              <tr key={j.id}>
                <td style={{ color: 'var(--text)', fontWeight: 500 }}>{j.project_title}</td>
                <td><span style={{ background: 'var(--bg3)', color: 'var(--text2)', padding: '2px 8px', borderRadius: 4, fontSize: 11, fontWeight: 700 }}>{j.quality}</span></td>
                <td style={{ color: 'var(--text3)', fontSize: 12 }}>{j.user_email}</td>
                <td><span style={{ color: STATUS_COLOR[j.status], fontSize: 12, fontWeight: 600 }}>● {j.status}</span></td>
                <td>
                  {j.status === 'processing' ? (
                    <div>
                      <div style={{ width: '100%', height: 4, background: 'var(--border)', borderRadius: 2, overflow: 'hidden' }}>
                        <div style={{ width: `${j.progress * 100}%`, height: '100%', background: '#7c6ef7', borderRadius: 2, transition: 'width 0.5s' }} />
                      </div>
                      <div style={{ fontSize: 10, color: 'var(--text3)', marginTop: 2 }}>{(j.progress * 100).toFixed(0)}%</div>
                    </div>
                  ) : j.status === 'done' ? '100%' : '—'}
                </td>
                <td className="date-cell">{j.started_at ? new Date(j.started_at).toLocaleTimeString() : new Date(j.queued_at).toLocaleTimeString()}</td>
                <td>
                  {['queued','processing'].includes(j.status) && (
                    <button className="btn-sm" style={{ color: 'var(--accent4)' }} onClick={() => cancelJob(j.id)}>Cancel</button>
                  )}
                </td>
              </tr>
            ))}
            {jobs.length === 0 && <tr><td colSpan={7} style={{ textAlign: 'center', padding: 40, color: 'var(--text3)' }}>No jobs found</td></tr>}
          </tbody>
        </table>
      )}
    </div>
  );
}
