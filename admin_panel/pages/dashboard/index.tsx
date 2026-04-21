// admin_panel/pages/dashboard/index.tsx
// Admin Dashboard — analytics, quick stats, recent activity

'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';

// ── Types ─────────────────────────────────────────────────────────────────────

interface DashboardStats {
  dau: number;
  mau: number;
  totalUsers: number;
  newSignupsToday: number;
  revenueToday: number;
  revenueMonth: number;
  proSubscribers: number;
  premiumSubscribers: number;
  exportsToday: number;
  aiJobsToday: number;
  templateDownloadsToday: number;
  pendingTemplates: number;
  reportedContent: number;
  activeExports: number;
}

interface DailyMetric {
  date: string;
  dau: number;
  revenue: number;
  exports: number;
  new_signups: number;
}

interface RecentUser {
  id: string;
  email: string;
  display_name: string;
  plan: string;
  created_at: string;
  is_banned: boolean;
}

// ── Components ────────────────────────────────────────────────────────────────

function StatCard({ label, value, subValue, color = '#7c6ef7', icon }: {
  label: string; value: string | number; subValue?: string; color?: string; icon: string;
}) {
  return (
    <div className="stat-card">
      <div className="stat-icon" style={{ background: `${color}20`, color }}>{icon}</div>
      <div className="stat-body">
        <div className="stat-value">{value}</div>
        <div className="stat-label">{label}</div>
        {subValue && <div className="stat-sub">{subValue}</div>}
      </div>
    </div>
  );
}

function AlertBadge({ count, label, href, color }: { count: number; label: string; href: string; color: string }) {
  if (count === 0) return null;
  return (
    <a href={href} className="alert-badge" style={{ borderColor: color, color }}>
      <span className="alert-count" style={{ background: color }}>{count}</span>
      {label}
    </a>
  );
}

// ── Main Dashboard ────────────────────────────────────────────────────────────

export default function DashboardPage() {
  const router = useRouter();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [dailyData, setDailyData] = useState<DailyMetric[]>([]);
  const [recentUsers, setRecentUsers] = useState<RecentUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [period, setPeriod] = useState<'7d' | '30d' | '90d'>('30d');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const token = localStorage.getItem('admin_token');
      const headers = { Authorization: `Bearer ${token}` };

      const [statsRes, analyticsRes, usersRes] = await Promise.all([
        fetch('/api/admin/stats', { headers }),
        fetch(`/api/admin/analytics?period=${period}`, { headers }),
        fetch('/api/admin/users?limit=10&sort=newest', { headers }),
      ]);

      if (statsRes.status === 401) { router.push('/login'); return; }

      const [statsData, analyticsData, usersData] = await Promise.all([
        statsRes.json(), analyticsRes.json(), usersRes.json(),
      ]);

      setStats(statsData);
      setDailyData(analyticsData.data || []);
      setRecentUsers(usersData.users || []);
    } catch (e) {
      console.error('Dashboard fetch error:', e);
    } finally {
      setLoading(false);
    }
  }, [period, router]);

  useEffect(() => { fetchData(); }, [fetchData]);

  if (loading) return (
    <div className="dashboard-loading">
      <div className="spinner" />
      <span>Loading dashboard...</span>
    </div>
  );

  return (
    <div className="dashboard">
      <header className="dash-header">
        <div>
          <h1>Dashboard</h1>
          <p className="dash-subtitle">Welcome back — here's what's happening</p>
        </div>
        <div className="dash-actions">
          <div className="period-selector">
            {(['7d', '30d', '90d'] as const).map(p => (
              <button key={p} onClick={() => setPeriod(p)} className={`period-btn ${period === p ? 'active' : ''}`}>
                {p}
              </button>
            ))}
          </div>
          <button onClick={fetchData} className="btn-secondary">↻ Refresh</button>
        </div>
      </header>

      {/* Alerts */}
      {stats && (stats.pendingTemplates > 0 || stats.reportedContent > 0) && (
        <div className="alerts-row">
          <AlertBadge count={stats.pendingTemplates} label="Templates pending review" href="/templates?filter=pending" color="#f7c948" />
          <AlertBadge count={stats.reportedContent} label="Reported content" href="/users?filter=reported" color="#f76e6e" />
          <AlertBadge count={stats.activeExports} label="Active exports" href="/exports" color="#4ecdc4" />
        </div>
      )}

      {/* Primary Stats */}
      <div className="stats-grid">
        <StatCard icon="👥" label="Daily Active Users" value={stats?.dau?.toLocaleString() ?? '—'} subValue={`${stats?.mau?.toLocaleString()} MAU`} color="#7c6ef7" />
        <StatCard icon="🆕" label="New Signups Today" value={stats?.newSignupsToday ?? '—'} subValue={`${stats?.totalUsers?.toLocaleString()} total`} color="#4ecdc4" />
        <StatCard icon="💰" label="Revenue Today" value={`$${stats?.revenueToday?.toFixed(2) ?? '0.00'}`} subValue={`$${stats?.revenueMonth?.toFixed(2) ?? '0.00'} this month`} color="#f7c948" />
        <StatCard icon="⭐" label="Pro Subscribers" value={stats?.proSubscribers?.toLocaleString() ?? '—'} color="#60a5fa" />
        <StatCard icon="👑" label="Premium Subscribers" value={stats?.premiumSubscribers?.toLocaleString() ?? '—'} color="#f472b6" />
        <StatCard icon="📤" label="Exports Today" value={stats?.exportsToday ?? '—'} color="#4ade80" />
        <StatCard icon="🤖" label="AI Jobs Today" value={stats?.aiJobsToday ?? '—'} color="#fb923c" />
        <StatCard icon="🎨" label="Template Downloads" value={stats?.templateDownloadsToday ?? '—'} color="#a78bfa" />
      </div>

      {/* Charts */}
      <div className="charts-row">
        <div className="chart-card">
          <div className="chart-header">
            <h2>Daily Active Users</h2>
            <span className="chart-period">{period}</span>
          </div>
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={dailyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
              <XAxis dataKey="date" tick={{ fill: '#9d9bb8', fontSize: 11 }} tickFormatter={d => d.slice(5)} />
              <YAxis tick={{ fill: '#9d9bb8', fontSize: 11 }} />
              <Tooltip contentStyle={{ background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }} labelStyle={{ color: '#e8e6ff' }} />
              <Line type="monotone" dataKey="dau" stroke="#7c6ef7" strokeWidth={2} dot={false} name="DAU" />
              <Line type="monotone" dataKey="new_signups" stroke="#4ecdc4" strokeWidth={2} dot={false} name="New Users" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="chart-card">
          <div className="chart-header">
            <h2>Revenue ($)</h2>
            <span className="chart-period">{period}</span>
          </div>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={dailyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
              <XAxis dataKey="date" tick={{ fill: '#9d9bb8', fontSize: 11 }} tickFormatter={d => d.slice(5)} />
              <YAxis tick={{ fill: '#9d9bb8', fontSize: 11 }} />
              <Tooltip contentStyle={{ background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }} labelStyle={{ color: '#e8e6ff' }} formatter={(v: number) => [`$${v.toFixed(2)}`, 'Revenue']} />
              <Bar dataKey="revenue" fill="#f7c948" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Exports Chart */}
      <div className="chart-card wide">
        <div className="chart-header">
          <h2>Exports by Day</h2>
        </div>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={dailyData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
            <XAxis dataKey="date" tick={{ fill: '#9d9bb8', fontSize: 11 }} tickFormatter={d => d.slice(5)} />
            <YAxis tick={{ fill: '#9d9bb8', fontSize: 11 }} />
            <Tooltip contentStyle={{ background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }} labelStyle={{ color: '#e8e6ff' }} />
            <Bar dataKey="exports_720p" fill="#60a5fa" radius={[2, 2, 0, 0]} name="720p" stackId="a" />
            <Bar dataKey="exports_1080p" fill="#7c6ef7" radius={[2, 2, 0, 0]} name="1080p" stackId="a" />
            <Bar dataKey="exports_4k" fill="#4ecdc4" radius={[2, 2, 0, 0]} name="4K" stackId="a" />
            <Legend wrapperStyle={{ color: '#9d9bb8', fontSize: 12 }} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Recent Users */}
      <div className="table-card">
        <div className="table-header">
          <h2>Recent Signups</h2>
          <a href="/users" className="see-all">See all →</a>
        </div>
        <table className="admin-table">
          <thead>
            <tr>
              <th>User</th>
              <th>Plan</th>
              <th>Joined</th>
              <th>Status</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {recentUsers.map(u => (
              <tr key={u.id}>
                <td>
                  <div className="user-cell">
                    <div className="user-avatar">{(u.display_name || u.email)[0].toUpperCase()}</div>
                    <div>
                      <div className="user-name">{u.display_name || '—'}</div>
                      <div className="user-email">{u.email}</div>
                    </div>
                  </div>
                </td>
                <td>
                  <span className={`plan-badge plan-${u.plan}`}>{u.plan}</span>
                </td>
                <td className="date-cell">{new Date(u.created_at).toLocaleDateString()}</td>
                <td>
                  {u.is_banned
                    ? <span className="status-badge banned">Banned</span>
                    : <span className="status-badge active">Active</span>
                  }
                </td>
                <td>
                  <a href={`/users/${u.id}`} className="btn-sm">View</a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
