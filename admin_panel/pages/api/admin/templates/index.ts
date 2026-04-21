// admin_panel/pages/api/admin/templates/index.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Pool } from 'pg';
import { v4 as uuidv4 } from 'uuid';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'GET') {
    const { q = '', page = '1', limit = '20', is_approved, is_featured } = req.query;
    const pageNum = Math.max(1, parseInt(page as string));
    const limitNum = Math.min(50, parseInt(limit as string));
    const offset = (pageNum - 1) * limitNum;

    const conditions: string[] = [];
    const params: any[] = [];
    let idx = 1;

    if (q) {
      conditions.push(`(name ILIKE $${idx} OR category ILIKE $${idx})`);
      params.push(`%${q}%`); idx++;
    }
    if (is_approved !== undefined) {
      conditions.push(`is_approved = $${idx}`);
      params.push(is_approved === 'true'); idx++;
    }
    if (is_featured !== undefined) {
      conditions.push(`is_featured = $${idx}`);
      params.push(is_featured === 'true'); idx++;
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    params.push(limitNum, offset);

    try {
      const [rows, count] = await Promise.all([
        db.query(
          `SELECT id, name, category, tags, thumbnail_url, preview_url, aspect_ratio,
                  duration_seconds, slot_count, is_premium, price, download_count,
                  rating, rating_count, is_approved, is_featured, is_trending, created_at
           FROM templates ${where}
           ORDER BY created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`,
          params
        ),
        db.query(`SELECT COUNT(*) FROM templates ${where}`, params.slice(0, -2)),
      ]);

      res.status(200).json({
        templates: rows.rows,
        pagination: { page: pageNum, limit: limitNum, total: parseInt(count.rows[0].count), pages: Math.ceil(parseInt(count.rows[0].count) / limitNum) },
      });
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  } else if (req.method === 'POST') {
    const { name, category, tags = [], is_premium = false, price = 0, aspect_ratio = '9:16', duration_seconds, slot_count } = req.body;
    if (!name || !category) return res.status(400).json({ error: 'name and category required' });

    try {
      const id = uuidv4();
      const result = await db.query(
        `INSERT INTO templates (id, name, category, tags, is_premium, price, aspect_ratio, duration_seconds, slot_count, template_json)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'{}') RETURNING id, name, category`,
        [id, name, category, tags, is_premium, price, aspect_ratio, duration_seconds, slot_count]
      );
      res.status(201).json(result.rows[0]);
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  } else {
    res.status(405).end();
  }
}
