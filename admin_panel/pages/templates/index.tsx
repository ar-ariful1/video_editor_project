// admin_panel/pages/templates/index.tsx
// Template management — upload, approve, tag, price, preview

'use client';

import { useEffect, useState, useRef } from 'react';

interface Template {
  id: string;
  name: string;
  category: string;
  thumbnail_url: string;
  preview_url: string;
  is_premium: boolean;
  price: number;
  is_approved: boolean;
  is_featured: boolean;
  is_trending: boolean;
  download_count: number;
  rating: number;
  rating_count: number;
  slot_count: number;
  aspect_ratio: string;
  duration_seconds: number;
  tags: string[];
  created_at: string;
}

const CATEGORIES = ['wedding','birthday','travel','food','business','fitness','fashion','gaming','music','seasonal','minimal','cinematic','vlog','sports','education'];

export default function TemplatesPage() {
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'pending' | 'approved' | 'featured'>('all');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Template | null>(null);
  const [uploading, setUploading] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);

  const token = () => typeof window !== 'undefined' ? localStorage.getItem('admin_token') : '';
  const headers = () => ({ Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' });

  useEffect(() => { fetchTemplates(); }, [filter, search, page]);

  async function fetchTemplates() {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), limit: '20', q: search });
      if (filter === 'pending') params.set('is_approved', 'false');
      if (filter === 'approved') params.set('is_approved', 'true');
      if (filter === 'featured') params.set('is_featured', 'true');

      const res = await fetch(`/api/admin/templates?${params}`, { headers: headers() });
      const data = await res.json();
      setTemplates(data.templates || []);
      setTotal(data.pagination?.total || 0);
    } finally {
      setLoading(false);
    }
  }

  async function approveTemplate(id: string, approve: boolean) {
    await fetch(`/api/admin/templates/${id}/approve`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify({ approved: approve }),
    });
    fetchTemplates();
  }

  async function toggleFeatured(id: string, featured: boolean) {
    await fetch(`/api/admin/templates/${id}`, {
      method: 'PATCH',
      headers: headers(),
      body: JSON.stringify({ is_featured: featured }),
    });
    fetchTemplates();
  }

  async function toggleTrending(id: string, trending: boolean) {
    await fetch(`/api/admin/templates/${id}`, {
      method: 'PATCH',
      headers: headers(),
      body: JSON.stringify({ is_trending: trending }),
    });
    fetchTemplates();
  }

  async function updateTemplate(id: string, updates: Partial<Template>) {
    await fetch(`/api/admin/templates/${id}`, {
      method: 'PATCH',
      headers: headers(),
      body: JSON.stringify(updates),
    });
    setSelected(null);
    fetchTemplates();
  }

  async function deleteTemplate(id: string) {
    if (!confirm('Delete this template? This cannot be undone.')) return;
    await fetch(`/api/admin/templates/${id}`, { method: 'DELETE', headers: headers() });
    setSelected(null);
    fetchTemplates();
  }

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>Templates</h1>
          <p>{total} total templates</p>
        </div>
        <button className="btn-primary" onClick={() => setSelected({ id: '', name: '', category: 'wedding', thumbnail_url: '', preview_url: '', is_premium: false, price: 0, is_approved: false, is_featured: false, is_trending: false, download_count: 0, rating: 0, rating_count: 0, slot_count: 0, aspect_ratio: '9:16', duration_seconds: 15, tags: [], created_at: '' })}>
          + Upload Template
        </button>
      </div>

      {/* Filter bar */}
      <div className="filter-bar">
        <div className="filter-tabs">
          {(['all', 'pending', 'approved', 'featured'] as const).map(f => (
            <button key={f} onClick={() => { setFilter(f); setPage(1); }} className={`filter-tab ${filter === f ? 'active' : ''}`}>
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
        <input
          className="search-input"
          placeholder="Search templates..."
          value={search}
          onChange={e => { setSearch(e.target.value); setPage(1); }}
        />
      </div>

      {/* Templates grid */}
      {loading ? (
        <div className="loading-grid">
          {Array.from({ length: 12 }).map((_, i) => <div key={i} className="skeleton-card" />)}
        </div>
      ) : (
        <div className="template-grid">
          {templates.map(t => (
            <div key={t.id} className={`template-card ${!t.is_approved ? 'pending' : ''}`}>
              <div className="template-thumb" onClick={() => setSelected(t)}>
                {t.thumbnail_url ? (
                  <img src={t.thumbnail_url} alt={t.name} />
                ) : (
                  <div className="thumb-placeholder">No Preview</div>
                )}
                <div className="template-badges">
                  {t.is_premium && <span className="badge premium">PRO</span>}
                  {t.is_featured && <span className="badge featured">⭐</span>}
                  {t.is_trending && <span className="badge trending">🔥</span>}
                  {!t.is_approved && <span className="badge pending">Pending</span>}
                </div>
                {t.preview_url && (
                  <div className="preview-overlay">▶ Preview</div>
                )}
              </div>

              <div className="template-info">
                <div className="template-name">{t.name}</div>
                <div className="template-meta">
                  <span className="category-tag">{t.category}</span>
                  <span className="meta-stat">↓ {t.download_count}</span>
                  <span className="meta-stat">★ {t.rating?.toFixed(1)}</span>
                </div>
              </div>

              <div className="template-actions">
                {!t.is_approved ? (
                  <>
                    <button onClick={() => approveTemplate(t.id, true)} className="btn-approve">✓ Approve</button>
                    <button onClick={() => approveTemplate(t.id, false)} className="btn-reject">✗ Reject</button>
                  </>
                ) : (
                  <>
                    <button onClick={() => toggleFeatured(t.id, !t.is_featured)} className={`btn-sm ${t.is_featured ? 'active' : ''}`}>
                      {t.is_featured ? '★ Featured' : '☆ Feature'}
                    </button>
                    <button onClick={() => toggleTrending(t.id, !t.is_trending)} className={`btn-sm ${t.is_trending ? 'active' : ''}`}>
                      {t.is_trending ? '🔥 Trending' : '📈 Trend'}
                    </button>
                    <button onClick={() => setSelected(t)} className="btn-sm">Edit</button>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Pagination */}
      <div className="pagination">
        <button disabled={page <= 1} onClick={() => setPage(p => p - 1)} className="page-btn">← Prev</button>
        <span className="page-info">Page {page} of {Math.ceil(total / 20)}</span>
        <button disabled={page >= Math.ceil(total / 20)} onClick={() => setPage(p => p + 1)} className="page-btn">Next →</button>
      </div>

      {/* Edit Modal */}
      {selected && (
        <TemplateModal
          template={selected}
          onClose={() => setSelected(null)}
          onSave={updates => selected.id ? updateTemplate(selected.id, updates) : handleUpload(updates)}
          onDelete={selected.id ? () => deleteTemplate(selected.id) : undefined}
        />
      )}
    </div>
  );

  async function handleUpload(data: Partial<Template> & { file?: File; jsonFile?: File }) {
    setUploading(true);
    try {
      const t = () => localStorage.getItem('admin_token');
      // 1. Create template record
      const res = await fetch('/api/admin/templates', {
        method: 'POST',
        headers: { Authorization: `Bearer ${t()}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: data.name, category: data.category, tags: data.tags,
          is_premium: data.is_premium, price: data.price,
          aspect_ratio: data.aspect_ratio, duration_seconds: data.duration_seconds,
          slot_count: data.slot_count,
        }),
      });
      const created = await res.json();

      // 2. Upload files if provided
      if (data.file) {
        const uploadRes = await fetch(`/api/admin/templates/${created.id}/upload-urls`, {
          headers: { Authorization: `Bearer ${t()}` },
        });
        const urls = await uploadRes.json();
        await fetch(urls.thumbnailUrl, { method: 'PUT', body: data.file, headers: { 'Content-Type': data.file.type } });
      }

      fetchTemplates();
    } finally {
      setUploading(false);
      setSelected(null);
    }
  }
}

// ── Template Modal ─────────────────────────────────────────────────────────────

function TemplateModal({ template, onClose, onSave, onDelete }: {
  template: Template;
  onClose: () => void;
  onSave: (updates: Partial<Template>) => void;
  onDelete?: () => void;
}) {
  const [form, setForm] = useState({ ...template });
  const [tagInput, setTagInput] = useState('');

  const set = (k: keyof Template) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const val = e.target.type === 'checkbox' ? (e.target as HTMLInputElement).checked : e.target.value;
    setForm(f => ({ ...f, [k]: val }));
  };

  const addTag = () => {
    const tag = tagInput.trim().toLowerCase();
    if (tag && !form.tags.includes(tag)) {
      setForm(f => ({ ...f, tags: [...f.tags, tag] }));
    }
    setTagInput('');
  };

  const removeTag = (tag: string) => setForm(f => ({ ...f, tags: f.tags.filter(t => t !== tag) }));

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>{template.id ? 'Edit Template' : 'Upload Template'}</h2>
          <button onClick={onClose} className="modal-close">✕</button>
        </div>

        <div className="modal-body">
          <div className="form-grid">
            <div className="form-group">
              <label>Name</label>
              <input value={form.name} onChange={set('name')} placeholder="Template name" />
            </div>

            <div className="form-group">
              <label>Category</label>
              <select value={form.category} onChange={set('category')}>
                {CATEGORIES.map(c => <option key={c} value={c}>{c.charAt(0).toUpperCase() + c.slice(1)}</option>)}
              </select>
            </div>

            <div className="form-group">
              <label>Aspect Ratio</label>
              <select value={form.aspect_ratio} onChange={set('aspect_ratio')}>
                <option value="9:16">9:16 (Vertical)</option>
                <option value="16:9">16:9 (Landscape)</option>
                <option value="1:1">1:1 (Square)</option>
                <option value="4:5">4:5 (Instagram)</option>
              </select>
            </div>

            <div className="form-group">
              <label>Duration (seconds)</label>
              <input type="number" value={form.duration_seconds} onChange={set('duration_seconds')} min={3} max={300} />
            </div>

            <div className="form-group">
              <label>Slot Count</label>
              <input type="number" value={form.slot_count} onChange={set('slot_count')} min={1} max={20} />
            </div>

            <div className="form-group">
              <label>Price ($) — 0 for free</label>
              <input type="number" value={form.price} onChange={set('price')} min={0} step={0.99} />
            </div>
          </div>

          <div className="form-checks">
            <label className="checkbox-label">
              <input type="checkbox" checked={form.is_premium} onChange={set('is_premium')} />
              Premium template
            </label>
            <label className="checkbox-label">
              <input type="checkbox" checked={form.is_featured} onChange={set('is_featured')} />
              Featured on homepage
            </label>
            <label className="checkbox-label">
              <input type="checkbox" checked={form.is_trending} onChange={set('is_trending')} />
              Mark as trending
            </label>
            <label className="checkbox-label">
              <input type="checkbox" checked={form.is_approved} onChange={set('is_approved')} />
              Approved (visible in marketplace)
            </label>
          </div>

          {/* Tags */}
          <div className="form-group">
            <label>Tags</label>
            <div className="tag-input-row">
              <input
                value={tagInput} onChange={e => setTagInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && addTag()}
                placeholder="Add tag and press Enter"
              />
              <button onClick={addTag} className="btn-sm">Add</button>
            </div>
            <div className="tags-list">
              {form.tags.map(tag => (
                <span key={tag} className="tag-chip">
                  {tag}
                  <button onClick={() => removeTag(tag)}>×</button>
                </span>
              ))}
            </div>
          </div>
        </div>

        <div className="modal-footer">
          {onDelete && (
            <button onClick={onDelete} className="btn-danger">Delete</button>
          )}
          <div className="modal-actions-right">
            <button onClick={onClose} className="btn-secondary">Cancel</button>
            <button onClick={() => onSave(form)} className="btn-primary">Save</button>
          </div>
        </div>
      </div>
    </div>
  );
}
