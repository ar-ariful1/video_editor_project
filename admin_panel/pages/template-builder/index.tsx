// admin_panel/pages/template-builder/index.tsx
'use client';
import { useState, useRef } from 'react';

interface Slot { id: string; label: string; type: string; startTime: number; endTime: number; }
interface TextLayer { id: string; defaultText: string; editable: boolean; startTime: number; endTime: number; style: Record<string,any>; }

export default function TemplateBuilderPage() {
  const [name, setName] = useState('');
  const [category, setCategory] = useState('wedding');
  const [duration, setDuration] = useState(15);
  const [aspectRatio, setAspectRatio] = useState('9:16');
  const [isPremium, setIsPremium] = useState(false);
  const [price, setPrice] = useState(0);
  const [slots, setSlots] = useState<Slot[]>([]);
  const [textLayers, setTextLayers] = useState<TextLayer[]>([]);
  const [effects, setEffects] = useState<string[]>([]);
  const [saved, setSaved] = useState(false);
  const [previewJson, setPreviewJson] = useState(false);
  const [saving, setSaving] = useState(false);

  const CATEGORIES = ['wedding','birthday','travel','food','business','fashion','gaming','music','islamic','cinematic','minimal'];
  const RATIOS = ['9:16','16:9','1:1','4:5','3:4'];
  const EFFECT_OPTIONS = ['grain','vignette','lut_warm','lut_cinematic','lut_matte','fade_in'];

  const addSlot = () => {
    const last = slots[slots.length - 1];
    const start = last ? last.endTime : 0;
    const end = Math.min(start + 3, duration);
    setSlots([...slots, { id: `slot_${Date.now()}`, label: `Clip ${slots.length + 1}`, type: 'image_or_video', startTime: start, endTime: end }]);
  };

  const addTextLayer = () => {
    setTextLayers([...textLayers, { id: `text_${Date.now()}`, defaultText: 'Your Text Here', editable: true, startTime: 0, endTime: 3, style: { fontFamily: 'Inter', fontSize: 48, color: '#FFFFFF', animIn: 'fadeIn' } }]);
  };

  const generateJson = () => ({
    name, category, duration,
    resolution: aspectRatio === '9:16' ? {w:1080,h:1920} : aspectRatio === '16:9' ? {w:1920,h:1080} : {w:1080,h:1080},
    frameRate: 30, aspectRatio, slots, textLayers,
    effects: effects.map(e => ({ type: e })),
    premium: isPremium, price, version: 1,
  });

  const save = async () => {
    if (!name.trim() || slots.length === 0) { alert('Name and at least one slot are required'); return; }
    setSaving(true);
    try {
      const res = await fetch('/api/admin/templates', {
        method: 'POST',
        headers: { Authorization: `Bearer ${localStorage.getItem('admin_token')}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, category, is_premium: isPremium, price, aspect_ratio: aspectRatio, duration_seconds: duration, slot_count: slots.length, template_json: generateJson() }),
      });
      if (res.ok) setSaved(true);
    } finally { setSaving(false); }
  };

  return (
    <div className="page">
      <div className="page-header">
        <div><h1>Template Builder</h1><p>Create templates with timeline-based slot system</p></div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="btn-secondary" onClick={() => setPreviewJson(!previewJson)}>{previewJson ? 'Hide' : 'Preview'} JSON</button>
          <button className="btn-primary" onClick={save} disabled={saving}>{saving ? '⏳ Saving…' : '💾 Save Template'}</button>
        </div>
      </div>

      {saved && <div style={{ background: '#4ade8015', border: '1px solid #4ade8040', borderRadius: 8, padding: '12px 16px', color: 'var(--green)', marginBottom: 20 }}>✅ Template saved! Go to Templates page to approve and publish it.</div>}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 320px', gap: 20 }}>
        <div>
          {/* Basic info */}
          <div style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 14, padding: 20, marginBottom: 16 }}>
            <h2 style={{ marginBottom: 16 }}>Basic Info</h2>
            <div className="form-grid">
              <div className="form-group"><label>Template Name *</label><input value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Romantic Wedding" /></div>
              <div className="form-group"><label>Category</label><select value={category} onChange={e => setCategory(e.target.value)}>{CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}</select></div>
              <div className="form-group"><label>Duration (seconds)</label><input type="number" value={duration} onChange={e => setDuration(Number(e.target.value))} min={3} max={120} /></div>
              <div className="form-group"><label>Aspect Ratio</label><select value={aspectRatio} onChange={e => setAspectRatio(e.target.value)}>{RATIOS.map(r => <option key={r} value={r}>{r}</option>)}</select></div>
              <div className="form-group"><label>Price ($)</label><input type="number" value={price} onChange={e => setPrice(Number(e.target.value))} min={0} step={0.99} /></div>
            </div>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, color: 'var(--text2)', cursor: 'pointer' }}>
              <input type="checkbox" checked={isPremium} onChange={e => setIsPremium(e.target.checked)} />
              Premium template (requires Pro or Premium plan)
            </label>
          </div>

          {/* Timeline / slots */}
          <div style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 14, padding: 20, marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h2>Media Slots ({slots.length})</h2>
              <button className="btn-sm" onClick={addSlot}>+ Add Slot</button>
            </div>

            {/* Timeline visual */}
            {slots.length > 0 && (
              <div style={{ background: 'var(--bg3)', borderRadius: 8, padding: 12, marginBottom: 16, position: 'relative', height: 50 }}>
                <div style={{ position: 'absolute', inset: '8px 12px', display: 'flex', gap: 2 }}>
                  {slots.map((s, i) => (
                    <div key={s.id} style={{ flex: s.endTime - s.startTime, background: `hsl(${i * 40 + 220},70%,50%)`, borderRadius: 4, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, color: '#fff', fontWeight: 600 }}>
                      {i + 1}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {slots.map((slot, i) => (
              <div key={slot.id} style={{ background: 'var(--bg3)', border: '1px solid var(--border)', borderRadius: 10, padding: 12, marginBottom: 8, display: 'flex', gap: 10, alignItems: 'center' }}>
                <span style={{ background: `hsl(${i*40+220},70%,50%)`, color: '#fff', width: 24, height: 24, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 700, flexShrink: 0 }}>{i+1}</span>
                <div style={{ flex: 1 }}>
                  <input value={slot.label} onChange={e => setSlots(sl => sl.map((s,j) => j===i ? {...s,label:e.target.value} : s))} style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 6, color: 'var(--text)', fontSize: 12, padding: '4px 8px', width: '100%', marginBottom: 4, outline: 'none' }} />
                  <div style={{ display: 'flex', gap: 6, fontSize: 11 }}>
                    <span style={{ color: 'var(--text3)' }}>Start:</span>
                    <input type="number" value={slot.startTime} onChange={e => setSlots(sl => sl.map((s,j) => j===i ? {...s,startTime:Number(e.target.value)} : s))} style={{ width: 50, background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 4, color: 'var(--text)', fontSize: 11, padding: '2px 4px', outline: 'none' }} />
                    <span style={{ color: 'var(--text3)' }}>End:</span>
                    <input type="number" value={slot.endTime} onChange={e => setSlots(sl => sl.map((s,j) => j===i ? {...s,endTime:Number(e.target.value)} : s))} style={{ width: 50, background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 4, color: 'var(--text)', fontSize: 11, padding: '2px 4px', outline: 'none' }} />
                    <select value={slot.type} onChange={e => setSlots(sl => sl.map((s,j) => j===i ? {...s,type:e.target.value} : s))} style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 4, color: 'var(--text)', fontSize: 11, padding: '2px 4px', outline: 'none' }}>
                      <option value="image_or_video">Image or Video</option>
                      <option value="image">Image only</option>
                      <option value="video">Video only</option>
                    </select>
                  </div>
                </div>
                <button onClick={() => setSlots(sl => sl.filter((_,j) => j!==i))} style={{ background: 'none', border: 'none', color: 'var(--accent4)', cursor: 'pointer', fontSize: 16 }}>✕</button>
              </div>
            ))}

            {slots.length === 0 && <div style={{ textAlign: 'center', padding: 24, color: 'var(--text3)', fontSize: 13 }}>No slots yet. Add at least one media slot.</div>}
          </div>

          {/* Text layers */}
          <div style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 14, padding: 20, marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h2>Text Layers ({textLayers.length})</h2>
              <button className="btn-sm" onClick={addTextLayer}>+ Add Text</button>
            </div>
            {textLayers.map((tl, i) => (
              <div key={tl.id} style={{ background: 'var(--bg3)', border: '1px solid var(--border)', borderRadius: 10, padding: 12, marginBottom: 8, display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                <div style={{ flex: 1 }}>
                  <input value={tl.defaultText} onChange={e => setTextLayers(tls => tls.map((t,j) => j===i ? {...t,defaultText:e.target.value} : t))} placeholder="Default text" style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 6, color: 'var(--text)', fontSize: 13, padding: '6px 10px', width: '100%', marginBottom: 4, outline: 'none' }} />
                  <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: 'var(--text2)' }}>
                    <input type="checkbox" checked={tl.editable} onChange={e => setTextLayers(tls => tls.map((t,j) => j===i ? {...t,editable:e.target.checked} : t))} />
                    User editable
                  </label>
                </div>
                <button onClick={() => setTextLayers(tls => tls.filter((_,j) => j!==i))} style={{ background: 'none', border: 'none', color: 'var(--accent4)', cursor: 'pointer' }}>✕</button>
              </div>
            ))}
          </div>
        </div>

        {/* Right panel - JSON preview */}
        <div>
          <div style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 14, padding: 20, marginBottom: 16 }}>
            <h2 style={{ marginBottom: 12 }}>Summary</h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {[['Name', name || '—'],['Category', category],['Duration', `${duration}s`],['Aspect', aspectRatio],['Slots', slots.length],['Text Layers', textLayers.length],['Plan', isPremium ? `Premium ($${price})` : 'Free']].map(([k,v]) => (
                <div key={k} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13 }}>
                  <span style={{ color: 'var(--text3)' }}>{k}</span>
                  <span style={{ color: 'var(--text)', fontWeight: 500 }}>{String(v)}</span>
                </div>
              ))}
            </div>
          </div>

          {previewJson && (
            <div style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 14, padding: 16 }}>
              <h2 style={{ marginBottom: 10 }}>Generated JSON</h2>
              <pre style={{ background: 'var(--bg3)', borderRadius: 8, padding: 12, fontSize: 10, color: 'var(--text2)', overflow: 'auto', maxHeight: 400, whiteSpace: 'pre-wrap', wordBreak: 'break-all' }}>
                {JSON.stringify(generateJson(), null, 2)}
              </pre>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
