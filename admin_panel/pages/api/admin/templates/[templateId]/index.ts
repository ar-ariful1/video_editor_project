// admin_panel/pages/api/admin/templates/[templateId]/index.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Pool } from 'pg';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const { templateId } = req.query;

  if (req.method === 'PATCH') {
    const allowed = ['name','category','tags','is_premium','price','is_approved','is_featured','is_trending','aspect_ratio','duration_seconds','slot_count'];
    const updates: string[] = [];
    const params: any[] = [];
    let idx = 1;

    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        updates.push(`${key} = $${idx}`);
        params.push(req.body[key]);
        idx++;
      }
    }
    if (!updates.length) return res.status(400).json({ error: 'No valid fields' });
    params.push(templateId);

    try {
      await db.query(`UPDATE templates SET ${updates.join(', ')}, updated_at = NOW() WHERE id = $${idx}`, params);
      res.status(200).json({ success: true });
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  } else if (req.method === 'DELETE') {
    try {
      await db.query('DELETE FROM templates WHERE id = $1', [templateId]);
      res.status(200).json({ deleted: true });
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  } else {
    res.status(405).end();
  }
}
