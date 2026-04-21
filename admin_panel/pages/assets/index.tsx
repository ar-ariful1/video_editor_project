// admin_panel/pages/assets/index.tsx
'use client';
import { useEffect, useState } from 'react';

type AssetType = 'music' | 'sticker' | 'font' | 'lut' | 'effect' | 'transition';

interface Asset {
  id: string; type: AssetType; name: string; url: string;
  thumbnail_url?: string; category?: string; tags: string[];
  duration_seconds?: number; file_size_bytes: number;
  is_premium: boolean; download_count: number; is_active: boolean;
}

const TYPES: AssetType[] = ['music','sticker','font','lut','effect','transition'];
const TYPE_ICONS: Record<AssetType, string> = {
  music: '🎵', sticker: '😀', font: '🔤', lut: '🎨', effect: '✨', transition: '🔀',
};

export default function AssetsPage() {
  const [assets, setAssets] = useState<Asset[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeType, setActiveType] = useState<AssetType>('music');
  const [uploading, setUploading] = useState(false);
  const [total, setTotal] = useState(0);

  const token = () => localStorage.getItem('admin_token');
  const headers = () => ({ Authorization: `Bearer ${token()}` });

  useEffect(() => { fetchAssets(); }, [activeType]);

  async function fetchAssets() {
    setLoading(true);
    try {
      const res = await fetch(`/api/admin/assets?type=${activeType}&limit=50`, { headers: headers() });
      const data = await res.json();
      setAssets(data.assets || []);
      setTotal(data.total || 0);
    } finally { setLoading(false); }
  }

  async function toggleAsset(id: string, active: boolean) {
    await fetch(`/api/admin/assets/${id}`, {
      method: 'PATCH',
      headers: { ...headers(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ is_active: active }),
    });
    fetchAssets();
  }

  async function deleteAsset(id: string) {
    if (!confirm('Delete this asset permanently?')) return;
    await fetch(`/api/admin/assets/${id}`, { method: 'DELETE', headers: headers() });
    fetchAssets();
  }

  function formatSize(bytes: number) {
    if (bytes > 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024).toFixed(0)} KB`;
  }

  return (
    <div className="page">
      <div className="page-header">
        <div><h1>Assets</h1><p>{total} {activeType} assets</p></div>
        <button className="btn-primary" onClick={() => document.getElementById('file-upload')?.click()}>
          + Upload {activeType}
        </button>
        <input id="file-upload" type="file" style={{ display: 'none' }} multiple
          onChange={async e => {
            if (!e.target.files?.length) return;
            setUploading(true);
            const fd = new FormData();
            Array.from(e.target.files).forEach(f => fd.append('files', f));
            fd.append('type', activeType);
            await fetch('/api/admin/assets/upload', { method: 'POST', headers: headers(), body: fd });
            setUploading(false);
            fetchAssets();
          }}
        />
      </div>

      {/* Type tabs */}
      <div className="filter-tabs" style={{ marginBottom: 20 }}>
        {TYPES.map(t => (
          <button key={t} onClick={() => setActiveType(t)} className={`filter-tab ${activeType === t ? 'active' : ''}`}>
            {TYPE_ICONS[t]} {t.charAt(0).toUpperCase() + t.slice(1)}
          </button>
        ))}
      </div>

      {uploading && (
        <div style={{ padding: '12px 16px', background: '#7c6ef715', border: '1px solid #7c6ef740', borderRadius: 8, marginBottom: 16, color: '#7c6ef7' }}>
          ⏳ Uploading assets…
        </div>
      )}

      {loading ? <div className="loading">Loading assets…</div> : (
        <table className="admin-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Category</th>
              {activeType === 'music' && <th>Duration</th>}
              <th>Size</th>
              <th>Downloads</th>
              <th>Premium</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {assets.map(a => (
              <tr key={a.id}>
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <span style={{ fontSize: 20 }}>{TYPE_ICONS[a.type]}</span>
                    <div>
                      <div style={{ color: '#e8e6ff', fontWeight: 500, fontSize: 13 }}>{a.name}</div>
                      {a.tags?.length > 0 && (
                        <div style={{ fontSize: 10, color: '#5c5a78' }}>{a.tags.slice(0,3).join(', ')}</div>
                      )}
                    </div>
                  </div>
                </td>
                <td style={{ color: '#9d9bb8', fontSize: 12 }}>{a.category || '—'}</td>
                {activeType === 'music' && (
                  <td style={{ color: '#9d9bb8', fontSize: 12 }}>
                    {a.duration_seconds ? `${Math.floor(a.duration_seconds / 60)}:${(a.duration_seconds % 60).toFixed(0).padStart(2,'0')}` : '—'}
                  </td>
                )}
                <td style={{ color: '#9d9bb8', fontSize: 12 }}>{formatSize(a.file_size_bytes || 0)}</td>
                <td style={{ color: '#9d9bb8', fontSize: 12 }}>{a.download_count}</td>
                <td>
                  {a.is_premium
                    ? <span style={{ color: '#f472b6', fontSize: 11, fontWeight: 700 }}>PRO</span>
                    : <span style={{ color: '#5c5a78', fontSize: 11 }}>Free</span>}
                </td>
                <td>
                  {a.is_active
                    ? <span className="status-badge active">Active</span>
                    : <span className="status-badge banned">Hidden</span>}
                </td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="btn-sm" onClick={() => toggleAsset(a.id, !a.is_active)}>
                      {a.is_active ? 'Hide' : 'Show'}
                    </button>
                    <button className="btn-sm" style={{ color: '#f76e6e' }} onClick={() => deleteAsset(a.id)}>
                      Delete
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {assets.length === 0 && (
              <tr>
                <td colSpan={8} style={{ textAlign: 'center', padding: 40, color: '#5c5a78' }}>
                  No {activeType} assets yet. Click "Upload" to add some.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
