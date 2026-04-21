// admin_panel/pages/api/admin/auth/step3/verify.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { step3_verifyEmailOTP } from '../../../../../lib/admin_auth';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end();
  try {
    const { partial_token, otp } = req.body;
    const result = await step3_verifyEmailOTP(partial_token, otp);
    res.status(200).json(result);
  } catch (e: any) {
    res.status(401).json({ error: e.message });
  }
}
