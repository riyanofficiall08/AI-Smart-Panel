// Membuat akun ADMIN pertama (sekali saja). Dilindungi header x-bootstrap-secret.
// Setelah berhasil: login, ganti password (wajib), lalu HAPUS fungsi ini / hapus secret BOOTSTRAP_SECRET.
import { HttpError, createAccount, json, serve, serviceClient } from '../_shared/common.ts';

serve('bootstrap', async (req) => {
  const secret = Deno.env.get('BOOTSTRAP_SECRET');
  const given = req.headers.get('x-bootstrap-secret') ?? '';
  if (!secret || secret.length < 16 || given !== secret) {
    throw new HttpError(403, 'forbidden', 'Akses ditolak.');
  }
  const db = serviceClient();
  const { count } = await db.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'admin');
  if ((count ?? 0) > 0) throw new HttpError(409, 'already_bootstrapped', 'Admin sudah ada.');

  const username = Deno.env.get('BOOTSTRAP_ADMIN_USERNAME') ?? 'admin';
  const password = Deno.env.get('BOOTSTRAP_ADMIN_PASSWORD') ?? 'Riyan.123'; // password awal sesuai permintaan; WAJIB diganti saat login pertama
  const p = await createAccount(db, { username, password, display_name: 'Administrator', role: 'admin', must_change_password: true });
  return json({ ok: true, username: p.username, note: 'Login lalu ganti password segera.' });
});
