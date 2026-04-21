// admin_panel/pages/api/admin/users/[userId]/ban.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Pool } from 'pg';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end();
  const { userId } = req.query;
  const { banned, reason } = req.body;

  try {
    await db.query(
      'UPDATE users SET is_banned = $1, ban_reason = $2 WHERE id = $3',
      [banned, reason || null, userId]
    );
    await db.query(
      `INSERT INTO audit_logs (action, target_type, target_id, metadata)
       VALUES ($1, 'user', $2, $3)`,
      [banned ? 'user.ban' : 'user.unban', userId, JSON.stringify({ reason })]
    );
    res.status(200).json({ success: true });
  } catch (e: any) {
    res.status(500).json({ error: e.message });
  }
}
