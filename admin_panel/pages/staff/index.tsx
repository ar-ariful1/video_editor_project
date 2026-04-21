// admin_panel/pages/staff/index.tsx
'use client';
import { useEffect, useState } from 'react';

interface StaffMember {
  id: string; email: string; role: string;
  is_active: boolean; last_login_at: string;
  created_at: string; allowed_ips: string[];
}

const ROLES = ['super_admin','template_manager','support','moderator'];
const ROLE_COLORS: Record<string,string> = {
  super_admin: '#f472b6', template_manager: '#7c6ef7',
  support: '#4ecdc4', moderator: '#f7c948',
};

export default function StaffPage() {
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ email: '', role: 'support', password: '' });
  const [error, setError] = useState('');

  const token = () => localStorage.getItem('admin_token');
  const headers = () => ({ Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' });

  useEffect(() => { fetchStaff(); }, []);

  async function fetchStaff() {
    setLoading(true);
    try {
      const res = await fetch('/api/admin/staff', { headers: headers() });
      const data = await res.json();
      setStaff(data.staff || []);
    } finally { setLoading(false); }
  }

  async function createStaff(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    try {
      const res = await fetch('/api/admin/staff', {
        method: 'POST', headers: headers(),
        body: JSON.stringify(form),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setShowModal(false);
      setForm({ email: '', role: 'support', password: '' });
      fetchStaff();
    } catch (e: any) { setError(e.message); }
  }

  async function toggleActive(id: string, active: boolean) {
    await fetch(`/api/admin/staff/${id}`, {
      method: 'PATCH', headers: headers(),
      body: JSON.stringify({ is_active: active }),
    });
    fetchStaff();
  }

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>Staff Management</h1>
          <p>Admin accounts with role-based access control</p>
        </div>
        <button className="btn-primary" onClick={() => setShowModal(true)}>+ Add Staff</button>
      </div>

      {/* Role legend */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 20, flexWrap: 'wrap' }}>
        {ROLES.map(r => (
          <div key={r} style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '6px 12px', background: '#16161d', border: '1px solid #2a2a38', borderRadius: 8 }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: ROLE_COLORS[r] }} />
            <span style={{ color: '#9d9bb8', fontSize: 12 }}>{r.replace('_',' ')}</span>
          </div>
        ))}
      </div>

      {loading ? <div className="loading">Loading staff…</div> : (
        <table className="admin-table">
          <thead>
            <tr><th>Email</th><th>Role</th><th>Status</th><th>Last Login</th><th>IPs</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {staff.map(s => (
              <tr key={s.id}>
                <td style={{ color: '#e8e6ff', fontWeight: 500 }}>{s.email}</td>
                <td>
                  <span style={{
                    padding: '3px 10px', borderRadius: 4, fontSize: 11, fontWeight: 700,
                    background: `${ROLE_COLORS[s.role]}20`,
                    color: ROLE_COLORS[s.role],
                    border: `1px solid ${ROLE_COLORS[s.role]}40`,
                  }}>
                    {s.role.replace('_',' ').toUpperCase()}
                  </span>
                </td>
                <td>
                  {s.is_active
                    ? <span className="status-badge active">Active</span>
                    : <span className="status-badge banned">Disabled</span>}
                </td>
                <td className="date-cell">{s.last_login_at ? new Date(s.last_login_at).toLocaleString() : 'Never'}</td>
                <td style={{ color: '#5c5a78', fontSize: 11 }}>
                  {s.allowed_ips?.length ? s.allowed_ips.join(', ') : 'Any IP'}
                </td>
                <td>
                  <button className="btn-sm" onClick={() => toggleActive(s.id, !s.is_active)}>
                    {s.is_active ? 'Disable' : 'Enable'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {/* RBAC explanation */}
      <div style={{ marginTop: 24, padding: 16, background: '#16161d', border: '1px solid #2a2a38', borderRadius: 12 }}>
        <h2 style={{ marginBottom: 12, fontSize: 15 }}>Role Permissions</h2>
        <table className="admin-table">
          <thead><tr><th>Role</th><th>Permissions</th></tr></thead>
          <tbody>
            <tr><td style={{ color: ROLE_COLORS.super_admin }}>super_admin</td><td>Full access — all features, staff management, billing, feature flags</td></tr>
            <tr><td style={{ color: ROLE_COLORS.template_manager }}>template_manager</td><td>Upload/edit/approve templates, set pricing, view analytics</td></tr>
            <tr><td style={{ color: ROLE_COLORS.support }}>support</td><td>View users (read-only), reset passwords, manage support tickets</td></tr>
            <tr><td style={{ color: ROLE_COLORS.moderator }}>moderator</td><td>Review reports, ban users, remove content, moderation queue</td></tr>
          </tbody>
        </table>
      </div>

      {/* Add Staff Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Add Staff Member</h2>
              <button className="modal-close" onClick={() => setShowModal(false)}>✕</button>
            </div>
            <form onSubmit={createStaff}>
              <div className="modal-body">
                {error && <div style={{ background: '#f76e6e15', border: '1px solid #f76e6e40', borderRadius: 8, padding: '10px 14px', color: '#f76e6e', marginBottom: 14 }}>{error}</div>}
                <div className="form-group" style={{ marginBottom: 14 }}>
                  <label>Email</label>
                  <input type="email" value={form.email} onChange={e => setForm(f => ({...f, email: e.target.value}))} required />
                </div>
                <div className="form-group" style={{ marginBottom: 14 }}>
                  <label>Role</label>
                  <select value={form.role} onChange={e => setForm(f => ({...f, role: e.target.value}))}>
                    {ROLES.map(r => <option key={r} value={r}>{r.replace('_',' ')}</option>)}
                  </select>
                </div>
                <div className="form-group">
                  <label>Temporary Password</label>
                  <input type="password" value={form.password} onChange={e => setForm(f => ({...f, password: e.target.value}))} required minLength={12} />
                  <span style={{ color: '#5c5a78', fontSize: 11 }}>Min 12 characters. Staff must set up TOTP 2FA on first login.</span>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-secondary" onClick={() => setShowModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary">Create Account</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
