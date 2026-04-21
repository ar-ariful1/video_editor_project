// admin_panel/pages/api/admin/auth/step1.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { step1_passwordAuth } from '../../../../lib/admin_auth';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
    const clientIP = (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() || req.socket.remoteAddress || '';
    const result = await step1_passwordAuth(email, password, clientIP);
    res.status(200).json(result);
  } catch (e: any) {
    res.status(401).json({ error: e.message });
  }
}
