// Endpoint akun untuk pengguna login: status lisensi, aktivasi token, ganti password.
import {
  HttpError, addDays, anonClient, authenticate, getSetting, json, licenseState, logUsage,
  readJson, serve, serviceClient, startOfToday, usernameToEmail, validatePassword, type Profile,
} from '../_shared/common.ts';
import { hashToken, isTokenFormat } from '../_shared/tokens.ts';

async function statusPayload(db: ReturnType<typeof serviceClient>, p: Profile) {
  const globalLimit = await getSetting<number>(db, 'daily_limit', 100);
  const limit = p.daily_limit ?? globalLimit;
  const { count } = await db.from('usage_logs').select('id', { count: 'exact', head: true })
    .eq('user_id', p.id).eq('action', 'analyze').eq('status', 'ok').gte('created_at', startOfToday().toISOString());
  const { data: lic } = await db.from('licenses').select('token_hint,duration_days,status,redeemed_at,expires_at')
    .eq('user_id', p.id).order('redeemed_at', { ascending: false, nullsFirst: false }).limit(1).maybeSingle();
  const state = licenseState(p);
  const daysLeft = p.expires_at ? Math.max(0, Math.ceil((new Date(p.expires_at).getTime() - Date.now()) / 86400e3)) : 0;
  return {
    ok: true,
    profile: {
      id: p.id, username: p.username, display_name: p.display_name, role: p.role, is_active: p.is_active,
      expires_at: p.expires_at, must_change_password: p.must_change_password,
    },
    license_state: state,
    days_left: daysLeft,
    usage: { used_today: count ?? 0, limit },
    license: lic ?? null,
  };
}

serve('account', async (req) => {
  const db = serviceClient();
  const p = await authenticate(req, db);
  const body = await readJson(req);
  const action = String(body.action ?? 'status');

  if (action === 'status') return json(await statusPayload(db, p));

  if (action === 'redeem') {
    if (!p.is_active) throw new HttpError(403, 'account_disabled', 'Akun Anda dinonaktifkan. Hubungi admin.');
    const token = String(body.token ?? '');
    // batasi tebakan token: maks 5 gagal / 15 menit
    const since = new Date(Date.now() - 15 * 60e3).toISOString();
    const { count: fails } = await db.from('usage_logs').select('id', { count: 'exact', head: true })
      .eq('user_id', p.id).eq('action', 'redeem').neq('status', 'ok').gte('created_at', since);
    if ((fails ?? 0) >= 5) throw new HttpError(429, 'rate_limited', 'Terlalu banyak percobaan token. Coba lagi 15 menit lagi.');

    const fail = async (code: string, msg: string, status = 400) => {
      await logUsage(db, { user_id: p.id, username: p.username, action: 'redeem', status: 'denied', detail: code });
      throw new HttpError(status, code, msg);
    };
    if (!isTokenFormat(token)) return await fail('invalid_token', 'Format token tidak valid.');

    const hash = await hashToken(token);
    const { data: lic } = await db.from('licenses').select('*').eq('token_hash', hash).maybeSingle();
    if (!lic) return await fail('invalid_token', 'Token tidak ditemukan.');
    if (lic.status === 'revoked') return await fail('token_revoked', 'Token ini sudah dicabut.');
    if (lic.status !== 'unused') return await fail('token_used', 'Token ini sudah pernah dipakai.');

    const base = p.expires_at && new Date(p.expires_at).getTime() > Date.now() ? new Date(p.expires_at) : new Date();
    const newExpiry = addDays(base, lic.duration_days).toISOString();

    // klaim atomik: hanya berhasil bila masih 'unused'
    const { data: claimed } = await db.from('licenses').update({
      status: 'redeemed', user_id: p.id, redeemed_at: new Date().toISOString(), expires_at: newExpiry,
    }).eq('id', lic.id).eq('status', 'unused').select('id').maybeSingle();
    if (!claimed) return await fail('token_used', 'Token ini sudah pernah dipakai.');

    await db.from('profiles').update({ expires_at: newExpiry }).eq('id', p.id);
    await logUsage(db, { user_id: p.id, username: p.username, action: 'redeem', status: 'ok', detail: `+${lic.duration_days} hari` });
    const fresh = { ...p, expires_at: newExpiry };
    return json(await statusPayload(db, fresh));
  }

  if (action === 'change_password') {
    const current = String(body.current_password ?? '');
    const next = validatePassword(body.new_password);
    if (next === current) throw new HttpError(400, 'invalid_input', 'Password baru harus berbeda dari password lama.');
    // verifikasi password lama di server
    const { error: verr } = await anonClient().auth.signInWithPassword({ email: usernameToEmail(p.username), password: current });
    if (verr) throw new HttpError(400, 'wrong_password', 'Password saat ini salah.');
    const { error } = await db.auth.admin.updateUserById(p.id, { password: next });
    if (error) throw new HttpError(400, 'change_failed', `Gagal mengganti password: ${error.message}`);
    await db.from('profiles').update({ must_change_password: false }).eq('id', p.id);
    return json({ ok: true });
  }

  throw new HttpError(400, 'invalid_input', 'Aksi tidak dikenal.');
});
