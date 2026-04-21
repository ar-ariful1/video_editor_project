// admin_panel/pages/api/admin/users/index.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Pool } from 'pg';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') return res.status(405).end();

  const { q = '', page = '1', limit = '20', sort = 'newest' } = req.query;
  const pageNum = Math.max(1, parseInt(page as string));
  const limitNum = Math.min(100, parseInt(limit as string));
  const offset = (pageNum - 1) * limitNum;

  const conditions = ['u.is_banned IS NOT NULL'];
  const params: any[] = [];
  let idx = 1;

  if (q) {
    conditions.push(`(u.email ILIKE $${idx} OR u.display_name ILIKE $${idx})`);
    params.push(`%${q}%`);
    idx++;
  }

  const orderBy = sort === 'newest' ? 'u.created_at DESC' : 'u.last_login_at DESC NULLS LAST';
  params.push(limitNum, offset);

  try {
    const [usersResult, countResult] = await Promise.all([
      db.query(
        `SELECT u.id, u.email, u.display_name, u.avatar_url, u.is_banned,
                u.storage_used_bytes, u.export_count_today, u.created_at, u.last_login_at,
                COALESCE(s.plan, 'free') as plan, s.status as sub_status
         FROM users u
         LEFT JOIN subscriptions s ON s.id = u.subscription_id
         WHERE ${conditions.join(' AND ')}
         ORDER BY ${orderBy}
         LIMIT $${idx} OFFSET $${idx + 1}`,
        params
      ),
      db.query(`SELECT COUNT(*) FROM users u WHERE ${conditions.join(' AND ')}`, params.slice(0, -2)),
    ]);

    res.status(200).json({
      users: usersResult.rows,
      pagination: {
        page: pageNum, limit: limitNum,
        total: parseInt(countResult.rows[0].count),
        pages: Math.ceil(parseInt(countResult.rows[0].count) / limitNum),
      },
    });
  } catch (e: any) {
    res.status(500).json({ error: e.message });
  }
}
