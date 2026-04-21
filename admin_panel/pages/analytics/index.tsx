// admin_panel/pages/analytics/index.tsx
'use client';
import { useEffect, useState } from 'react';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';

export default function AnalyticsPage() {
  const [data, setData] = useState<any[]>([]);
  const [period, setPeriod] = useState('30d');
  const [loading, setLoading] = useState(true);

  useEffect(() => { fetchData(); }, [period]);

  async function fetchData() {
    setLoading(true);
    try {
      const res = await fetch(`/api/admin/analytics?period=${period}`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('admin_token')}` },
      });
      const json = await res.json();
      setData(json.data || []);
    } finally { setLoading(false); }
  }

  return (
    <div className="dashboard">
      <div className="dash-header">
        <div><h1>Analytics</h1><p>Detailed platform metrics and trends</p></div>
        <div className="period-selector">
          {(['7d','30d','90d'] as const).map(p => (
            <button key={p} onClick={() => setPeriod(p)} className={`period-btn ${period === p ? 'active' : ''}`}>{p}</button>
          ))}
        </div>
      </div>

      {loading ? <div className="loading">Loading analytics…</div> : (
        <>
          {/* DAU / New Users */}
          <div className="chart-card" style={{ marginBottom: 16 }}>
            <div className="chart-header"><h2>User Activity</h2></div>
            <ResponsiveContainer width="100%" height={240}>
              <LineChart data={data}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
                <XAxis dataKey="date" tick={{ fill: '#9d9bb8', fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                <YAxis tick={{ fill: '#9d9bb8', fontSize: 11 }} />
                <Tooltip contentStyle={{ background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }} labelStyle={{ color: '#e8e6ff' }} />
                <Legend wrapperStyle={{ color: '#9d9bb8', fontSize: 12 }} />
                <Line type="monotone" dataKey="dau" stroke="#7c6ef7" strokeWidth={2} dot={false} name="DAU" />
                <Line type="monotone" dataKey="new_signups" stroke="#4ecdc4" strokeWidth={2} dot={false} name="New Signups" />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* Exports */}
          <div className="chart-card" style={{ marginBottom: 16 }}>
            <div className="chart-header"><h2>Exports by Quality</h2></div>
            <ResponsiveContainer width="100%" height={240}>
              <BarChart data={data}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
                <XAxis dataKey="date" tick={{ fill: '#9d9bb8', fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                <YAxis tick={{ fill: '#9d9bb8', fontSize: 11 }} />
                <Tooltip contentStyle={{ background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }} labelStyle={{ color: '#e8e6ff' }} />
                <Legend wrapperStyle={{ color: '#9d9bb8', fontSize: 12 }} />
                <Bar dataKey="exports_720p"  fill="#60a5fa" name="720p"  stackId="a" radius={[0,0,0,0]} />
                <Bar dataKey="exports_1080p" fill="#7c6ef7" name="1080p" stackId="a" radius={[0,0,0,0]} />
                <Bar dataKey="exports_4k"    fill="#4ecdc4" name="4K"    stackId="a" radius={[2,2,0,0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* AI usage */}
          <div className="chart-card">
            <div className="chart-header"><h2>AI Jobs</h2></div>
            <ResponsiveContainer width="100%" height={220}>
              <LineChart data={data}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
                <XAxis dataKey="date" tick={{ fill: '#9d9bb8', fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                <YAxis tick={{ fill: '#9d9bb8', fontSize: 11 }} />
                <Tooltip contentStyle={{ background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }} labelStyle={{ color: '#e8e6ff' }} />
                <Legend wrapperStyle={{ color: '#9d9bb8', fontSize: 12 }} />
                <Line type="monotone" dataKey="ai_caption_jobs"    stroke="#f7c948" strokeWidth={2} dot={false} name="Captions" />
                <Line type="monotone" dataKey="ai_bg_removal_jobs" stroke="#f472b6" strokeWidth={2} dot={false} name="BG Removal" />
                <Line type="monotone" dataKey="template_downloads" stroke="#4ade80" strokeWidth={2} dot={false} name="Template Downloads" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </>
      )}
    </div>
  );
}
