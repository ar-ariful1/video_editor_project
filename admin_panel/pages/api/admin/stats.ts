// admin_panel/pages/api/admin/stats.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Pool } from 'pg';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') return res.status(405).end();

  try {
    const [usersRow, subRow, analyticsRow, pendingRow] = await Promise.all([
      db.query(`SELECT COUNT(*) as total, COUNT(CASE WHEN DATE(created_at) = CURRENT_DATE THEN 1 END) as today FROM users WHERE is_banned = FALSE`),
      db.query(`SELECT plan, COUNT(*) as cnt FROM subscriptions WHERE status IN ('active','trial') GROUP BY plan`),
      db.query(`SELECT * FROM daily_analytics WHERE date = CURRENT_DATE`),
      db.query(`SELECT COUNT(*) as cnt FROM templates WHERE is_approved = FALSE`),
    ]);

    const subMap: Record<string, number> = {};
    subRow.rows.forEach((r: any) => subMap[r.plan] = parseInt(r.cnt));
    const today = analyticsRow.rows[0] || {};

    res.status(200).json({
      dau: parseInt(today.dau || 0),
      mau: parseInt(usersRow.rows[0]?.total || 0),
      totalUsers: parseInt(usersRow.rows[0]?.total || 0),
      newSignupsToday: parseInt(usersRow.rows[0]?.today || 0),
      proSubscribers: subMap['pro'] || 0,
      premiumSubscribers: subMap['premium'] || 0,
      revenueToday: (((subMap['pro'] || 0) * 4.99 + (subMap['premium'] || 0) * 9.99) / 30).toFixed(2),
      revenueMonth: ((subMap['pro'] || 0) * 4.99 + (subMap['premium'] || 0) * 9.99).toFixed(2),
      exportsToday: (today.exports_720p || 0) + (today.exports_1080p || 0) + (today.exports_4k || 0),
      aiJobsToday: (today.ai_caption_jobs || 0) + (today.ai_bg_removal_jobs || 0),
      templateDownloadsToday: today.template_downloads || 0,
      pendingTemplates: parseInt(pendingRow.rows[0]?.cnt || 0),
      reportedContent: 0,
      activeExports: 0,
    });
  } catch (e: any) {
    res.status(500).json({ error: e.message });
  }
}
