// admin_panel/pages/api/admin/assets/index.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Pool } from 'pg';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'GET') {
    const { type, limit = '50', page = '1' } = req.query;
    const offset = (parseInt(page as string) - 1) * parseInt(limit as string);

    try {
      const conditions = type ? `WHERE type = $1` : '';
      const params: any[] = type ? [type, parseInt(limit as string), offset] : [parseInt(limit as string), offset];

      const [rows, count] = await Promise.all([
        db.query(
          `SELECT * FROM assets ${conditions} ORDER BY created_at DESC LIMIT $${type ? 2 : 1} OFFSET $${type ? 3 : 2}`,
          params
        ),
        db.query(`SELECT COUNT(*) FROM assets ${conditions}`, type ? [type] : []),
      ]);

      res.status(200).json({ assets: rows.rows, total: parseInt(count.rows[0].count) });
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  } else {
    res.status(405).end();
  }
}
