// admin_panel/pages/api/admin/templates/[templateId]/approve.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Pool } from 'pg';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end();
  const { templateId } = req.query;
  const { approved } = req.body;

  try {
    await db.query('UPDATE templates SET is_approved = $1, updated_at = NOW() WHERE id = $2', [approved, templateId]);
    await db.query(
      `INSERT INTO audit_logs (action, target_type, target_id, metadata)
       VALUES ($1, 'template', $2, $3)`,
      [approved ? 'template.approve' : 'template.reject', templateId, JSON.stringify({ approved })]
    );
    res.status(200).json({ success: true });
  } catch (e: any) {
    res.status(500).json({ error: e.message });
  }
}
