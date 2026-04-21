// admin_panel/pages/api/admin/staff/index.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Pool } from 'pg';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'GET') {
    try {
      const result = await db.query(
        `SELECT id, email, role, is_active, last_login_at, created_at, allowed_ips
         FROM admins ORDER BY created_at DESC`
      );
      res.status(200).json({ staff: result.rows });
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  } else if (req.method === 'POST') {
    const { email, role, password } = req.body;
    if (!email || !role || !password) return res.status(400).json({ error: 'email, role, password required' });
    if (password.length < 12) return res.status(400).json({ error: 'Password must be at least 12 characters' });

    try {
      const hash = await bcrypt.hash(password, 12);
      const id = uuidv4();
      await db.query(
        `INSERT INTO admins (id, email, password_hash, role) VALUES ($1, $2, $3, $4)`,
        [id, email.toLowerCase(), hash, role]
      );
      res.status(201).json({ id, email, role });
    } catch (e: any) {
      if (e.code === '23505') return res.status(409).json({ error: 'Email already exists' });
      res.status(500).json({ error: e.message });
    }
  } else {
    res.status(405).end();
  }
}
