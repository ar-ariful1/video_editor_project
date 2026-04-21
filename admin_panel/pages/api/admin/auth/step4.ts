// admin_panel/pages/api/admin/auth/step4.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { step4_ipCheck } from '../../../../lib/admin_auth';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end();
  try {
    const clientIP = (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() || req.socket.remoteAddress || '';
    const result = await step4_ipCheck(req.body.partial_token, clientIP);
    res.status(200).json(result);
  } catch (e: any) {
    res.status(403).json({ error: e.message });
  }
}
