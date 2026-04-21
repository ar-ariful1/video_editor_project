// admin_panel/pages/ab-tests/index.tsx
'use client';
import { useEffect, useState } from 'react';

interface ABTest {
  id: string; name: string; description: string; variants: string[];
  traffic_pct: number; is_active: boolean; started_at: string; ended_at?: string;
  results?: Record<string, { users: number; conversion: number }>;
}

export default function ABTestsPage() {
  const [tests, setTests] = useState<ABTest[]>([]);
  const [loading, setLoading] = useState(true);
  const [showNew, setShowNew] = useState(false);
  const [form, setForm] = useState({ name: '', description: '', variants: 'control,treatment', traffic_pct: 100 });

  const h = () => ({ Authorization: `Bearer ${localStorage.getItem('admin_token')}`, 'Content-Type': 'application/json' });

  useEffect(() => { load(); }, []);

  async function load() {
    setLoading(true);
    try {
      const res = await fetch('/api/admin/ab-tests', { headers: h() });
      const d = await res.json();
      setTests(d.tests || []);
    } finally { setLoading(false); }
  }

  async function createTest() {
    await fetch('/api/admin/ab-tests', {
      method: 'POST', headers: h(),
      body: JSON.stringify({ ...form, variants: form.variants.split(',').map(v => v.trim()) }),
    });
    setShowNew(false);
    setForm({ name: '', description: '', variants: 'control,treatment', traffic_pct: 100 });
    load();
  }

  async function stopTest(id: string) {
    if (!confirm('Stop this A/B test?')) return;
    await fetch(`/api/admin/ab-tests/${id}`, { method: 'PATCH', headers: h(), body: JSON.stringify({ is_active: false }) });
    load();
  }

  return (
    <div className="page">
      <div className="page-header">
        <div><h1>A/B Tests</h1><p>Run experiments to improve user experience</p></div>
        <button className="btn-primary" onClick={() => setShowNew(true)}>+ New Test</button>
      </div>

      {loading ? <div className="loading">Loading…</div> : (
        <div style={{ display: 'grid', gap: 12 }}>
          {tests.map(test => (
            <div key={test.id} style={{ background: 'var(--bg2)', border: `1px solid ${test.is_active ? '#7c6ef740' : 'var(--border)'}`, borderRadius: 14, padding: 20 }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, marginBottom: 14 }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                    <span style={{ color: 'var(--text)', fontWeight: 600, fontSize: 15 }}>{test.name}</span>
                    <span style={{ padding: '2px 8px', borderRadius: 4, fontSize: 11, fontWeight: 700, background: test.is_active ? '#4ade8020' : '#2a2a38', color: test.is_active ? 'var(--green)' : 'var(--text3)', border: `1px solid ${test.is_active ? '#4ade8040' : 'var(--border)'}` }}>
                      {test.is_active ? '● LIVE' : '◉ ENDED'}
                    </span>
                  </div>
                  <div style={{ color: 'var(--text3)', fontSize: 12 }}>{test.description}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ color: 'var(--text2)', fontSize: 12 }}>Traffic: {test.traffic_pct}%</div>
                  <div style={{ color: 'var(--text3)', fontSize: 11 }}>Started: {new Date(test.started_at).toLocaleDateString()}</div>
                </div>
              </div>

              {/* Variants */}
              <div style={{ display: 'flex', gap: 10, marginBottom: test.results ? 14 : 0 }}>
                {test.variants.map(v => (
                  <div key={v} style={{ flex: 1, padding: '10px 14px', background: 'var(--bg3)', borderRadius: 8, border: '1px solid var(--border)' }}>
                    <div style={{ color: 'var(--text)', fontWeight: 600, fontSize: 13, marginBottom: 4 }}>{v}</div>
                    {test.results?.[v] ? (
                      <>
                        <div style={{ color: 'var(--text2)', fontSize: 12 }}>{test.results[v].users.toLocaleString()} users</div>
                        <div style={{ color: 'var(--accent2)', fontSize: 13, fontWeight: 700 }}>{(test.results[v].conversion * 100).toFixed(1)}% conv.</div>
                        <div style={{ marginTop: 6, height: 4, background: 'var(--border)', borderRadius: 2, overflow: 'hidden' }}>
                          <div style={{ width: `${test.results[v].conversion * 100 * 3}%`, height: '100%', background: '#4ecdc4', borderRadius: 2 }} />
                        </div>
                      </>
                    ) : <div style={{ color: 'var(--text3)', fontSize: 11 }}>Collecting data…</div>}
                  </div>
                ))}
              </div>

              {test.is_active && (
                <button className="btn-sm" onClick={() => stopTest(test.id)} style={{ color: 'var(--accent4)' }}>Stop Test</button>
              )}
            </div>
          ))}
          {tests.length === 0 && <div className="loading">No A/B tests yet. Create your first one!</div>}
        </div>
      )}

      {/* New test modal */}
      {showNew && (
        <div className="modal-overlay" onClick={() => setShowNew(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header"><h2>New A/B Test</h2><button className="modal-close" onClick={() => setShowNew(false)}>✕</button></div>
            <div className="modal-body">
              <div className="form-group" style={{ marginBottom: 14 }}>
                <label>Test Name</label>
                <input value={form.name} onChange={e => setForm(f => ({...f, name: e.target.value}))} placeholder="e.g. onboarding_v2_vs_control" />
              </div>
              <div className="form-group" style={{ marginBottom: 14 }}>
                <label>Description</label>
                <input value={form.description} onChange={e => setForm(f => ({...f, description: e.target.value}))} placeholder="What are you testing?" />
              </div>
              <div className="form-group" style={{ marginBottom: 14 }}>
                <label>Variants (comma-separated)</label>
                <input value={form.variants} onChange={e => setForm(f => ({...f, variants: e.target.value}))} placeholder="control,treatment" />
              </div>
              <div className="form-group">
                <label>Traffic % ({form.traffic_pct}%)</label>
                <input type="range" min={1} max={100} value={form.traffic_pct} onChange={e => setForm(f => ({...f, traffic_pct: parseInt(e.target.value)}))} style={{ width: '100%' }} />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-secondary" onClick={() => setShowNew(false)}>Cancel</button>
              <button className="btn-primary" onClick={createTest} disabled={!form.name}>Launch Test</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
