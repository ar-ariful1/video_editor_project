// admin_panel/pages/revenue/index.tsx
'use client';
import { useEffect, useState } from 'react';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend } from 'recharts';

export default function RevenuePage() {
  const [data, setData] = useState<any[]>([]);
  const [period, setPeriod] = useState('30d');
  const [summary, setSummary] = useState<any>({});
  const [loading, setLoading] = useState(true);

  const h = () => ({ Authorization: `Bearer ${localStorage.getItem('admin_token')}` });

  useEffect(() => { load(); }, [period]);

  async function load() {
    setLoading(true);
    try {
      const [statsRes, analyticsRes] = await Promise.all([
        fetch('/api/admin/stats', { headers: h() }),
        fetch(`/api/admin/analytics?period=${period}`, { headers: h() }),
      ]);
      const stats     = await statsRes.json();
      const analytics = await analyticsRes.json();
      setSummary(stats);
      setData(analytics.data || []);
    } finally { setLoading(false); }
  }

  const proRevenue     = (summary.proSubscribers ?? 0) * 4.99;
  const premiumRevenue = (summary.premiumSubscribers ?? 0) * 9.99;
  const totalMRR       = proRevenue + premiumRevenue;
  const pieData = [
    { name: 'Pro ($4.99)', value: proRevenue,     color: '#7c6ef7' },
    { name: 'Premium ($9.99)', value: premiumRevenue, color: '#f472b6' },
  ];

  return (
    <div className="dashboard">
      <div className="dash-header">
        <div><h1>Revenue Analytics</h1><p>MRR, subscriber breakdown, and growth</p></div>
        <div className="period-selector">
          {(['7d','30d','90d'] as const).map(p => (
            <button key={p} className={`period-btn ${period === p ? 'active' : ''}`} onClick={() => setPeriod(p)}>{p}</button>
          ))}
        </div>
      </div>

      {loading ? <div className="loading">Loading…</div> : (
        <>
          {/* MRR summary cards */}
          <div className="stats-grid" style={{ marginBottom: 24 }}>
            {[
              { label: 'Monthly Recurring Revenue', value: `$${totalMRR.toLocaleString('en-US', { minimumFractionDigits: 2 })}`, icon: '💰', color: '#4ade8015' },
              { label: 'Pro Subscribers',     value: summary.proSubscribers ?? 0,     icon: '✨', color: '#7c6ef715' },
              { label: 'Premium Subscribers', value: summary.premiumSubscribers ?? 0, icon: '👑', color: '#f472b615' },
              { label: 'Total Paying',         value: (summary.proSubscribers ?? 0) + (summary.premiumSubscribers ?? 0), icon: '📊', color: '#4ecdc415' },
            ].map((c, i) => (
              <div key={i} className="stat-card" style={{ background: c.color }}>
                <div className="stat-icon">{c.icon}</div>
                <div><div className="stat-value">{c.value}</div><div className="stat-label">{c.label}</div></div>
              </div>
            ))}
          </div>

          <div className="charts-row">
            {/* Revenue trend */}
            <div className="chart-card">
              <div className="chart-header"><h2>Revenue Trend</h2></div>
              <ResponsiveContainer width="100%" height={200}>
                <LineChart data={data}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
                  <XAxis dataKey="date" tick={{ fill: '#9d9bb8', fontSize: 10 }} tickFormatter={d => d.slice(5)} />
                  <YAxis tick={{ fill: '#9d9bb8', fontSize: 10 }} tickFormatter={v => `$${v}`} />
                  <Tooltip contentStyle={{ background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }} formatter={(v: any) => [`$${Number(v).toFixed(2)}`, 'Revenue']} labelStyle={{ color: '#e8e6ff' }} />
                  <Line type="monotone" dataKey="revenue" stroke="#4ade80" strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </div>

            {/* Revenue breakdown pie */}
            <div className="chart-card">
              <div className="chart-header"><h2>Revenue Split</h2></div>
              <ResponsiveContainer width="100%" height={200}>
                <PieChart>
                  <Pie data={pieData} cx="50%" cy="50%" innerRadius={50} outerRadius={80} dataKey="value" label={({ name, percent }) => `${(percent * 100).toFixed(0)}%`} labelLine={false}>
                    {pieData.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                  </Pie>
                  <Tooltip formatter={(v: any) => `$${Number(v).toFixed(2)}`} contentStyle={{ background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }} />
                  <Legend wrapperStyle={{ fontSize: 12, color: '#9d9bb8' }} />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Subscriber growth */}
          <div className="chart-card" style={{ marginTop: 16 }}>
            <div className="chart-header"><h2>New Signups per Day</h2></div>
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={data}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
                <XAxis dataKey="date" tick={{ fill: '#9d9bb8', fontSize: 10 }} tickFormatter={d => d.slice(5)} />
                <YAxis tick={{ fill: '#9d9bb8', fontSize: 10 }} />
                <Tooltip contentStyle={{ background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }} labelStyle={{ color: '#e8e6ff' }} />
                <Bar dataKey="new_signups" fill="#7c6ef7" radius={[4, 4, 0, 0]} name="New Users" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </>
      )}
    </div>
  );
}
