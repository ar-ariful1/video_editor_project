// admin_panel/pages/api/admin/auth/step2.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { step2_totpAuth } from '../../../../lib/admin_auth';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end();
  try {
    const { partial_token, totp_code } = req.body;
    const result = await step2_totpAuth(partial_token, totp_code);
    res.status(200).json(result);
  } catch (e: any) {
    res.status(401).json({ error: e.message });
  }
}
