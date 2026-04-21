// admin_panel/pages/api/admin/analytics.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Pool } from 'pg';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') return res.status(405).end();
  const period = (req.query.period as string) || '30d';
  const days = period === '7d' ? 7 : period === '90d' ? 90 : 30;

  try {
    const result = await db.query(
      `SELECT date, dau, new_signups, exports_720p, exports_1080p, exports_4k,
              ai_caption_jobs, ai_bg_removal_jobs, template_downloads,
              COALESCE(revenue_usd, 0) as revenue
       FROM daily_analytics
       WHERE date >= CURRENT_DATE - INTERVAL '${days} days'
       ORDER BY date ASC`
    );
    res.status(200).json({ data: result.rows });
  } catch (e: any) {
    res.status(500).json({ error: e.message });
  }
}
