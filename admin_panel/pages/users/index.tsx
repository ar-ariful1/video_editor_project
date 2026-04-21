// admin_panel/pages/users/index.tsx
'use client';
import { useEffect, useState } from 'react';

interface User {
  id: string; email: string; display_name: string;
  plan: string; created_at: string; last_login_at: string;
  is_banned: boolean; storage_used_bytes: number; export_count_today: number;
}

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);

  const token = () => localStorage.getItem('admin_token');
  const headers = () => ({ Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' });

  useEffect(() => { fetchUsers(); }, [search, page]);

  async function fetchUsers() {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), limit: '20', q: search });
      const res = await fetch(`/api/admin/users?${params}`, { headers: headers() });
      const data = await res.json();
      setUsers(data.users || []);
      setTotal(data.pagination?.total || 0);
    } finally { setLoading(false); }
  }

  async function banUser(id: string, ban: boolean) {
    await fetch(`/api/admin/users/${id}/ban`, {
      method: 'POST', headers: headers(),
      body: JSON.stringify({ banned: ban }),
    });
    fetchUsers();
  }

  async function resetPassword(id: string) {
    await fetch(`/api/admin/users/${id}/reset-password`, { method: 'POST', headers: headers() });
    alert('Password reset email sent');
  }

  return (
    <div className="page">
      <div className="page-header">
        <div><h1>Users</h1><p>{total.toLocaleString()} total users</p></div>
      </div>

      <div className="filter-bar">
        <input className="search-input" placeholder="Search by email or name…" value={search}
          onChange={e => { setSearch(e.target.value); setPage(1); }} />
      </div>

      {loading ? <div className="loading">Loading…</div> : (
        <table className="admin-table">
          <thead>
            <tr><th>User</th><th>Plan</th><th>Joined</th><th>Last Login</th><th>Storage</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {users.map(u => (
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
                <td><span className={`plan-badge plan-${u.plan}`}>{u.plan}</span></td>
                <td className="date-cell">{new Date(u.created_at).toLocaleDateString()}</td>
                <td className="date-cell">{u.last_login_at ? new Date(u.last_login_at).toLocaleDateString() : '—'}</td>
                <td>{(u.storage_used_bytes / 1024 / 1024).toFixed(1)} MB</td>
                <td>{u.is_banned ? <span className="status-badge banned">Banned</span> : <span className="status-badge active">Active</span>}</td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="btn-sm" onClick={() => banUser(u.id, !u.is_banned)}>
                      {u.is_banned ? 'Unban' : 'Ban'}
                    </button>
                    <button className="btn-sm" onClick={() => resetPassword(u.id)}>Reset Pwd</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <div className="pagination">
        <button disabled={page <= 1} onClick={() => setPage(p => p - 1)} className="page-btn">← Prev</button>
        <span className="page-info">Page {page} of {Math.ceil(total / 20)}</span>
        <button disabled={page >= Math.ceil(total / 20)} onClick={() => setPage(p => p + 1)} className="page-btn">Next →</button>
      </div>
    </div>
  );
}
