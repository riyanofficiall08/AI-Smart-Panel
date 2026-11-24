// Seluruh administrasi: hanya role ADMIN aktif (dicek di server). Semua mutasi memakai service role.
import {
  DURATIONS, HttpError, USERNAME_RE, addDays, authenticate, createAccount, getSetting, json, licenseState,
  logUsage, readJson, serve, serviceClient, startOfToday, usernameToEmail, validatePassword, type Profile,
} from '../_shared/common.ts';
import { generateToken, hashToken } from '../_shared/tokens.ts';
import { getOpenAIKey, saveOpenAIKey } from '../_shared/secrets.ts';

type DB = ReturnType<typeof serviceClient>;
const OPENAI_BASE = Deno.env.get('OPENAI_BASE_URL') ?? 'https://api.openai.com/v1';
const MODEL_RE = /^[A-Za-z0-9._:\-]{1,64}$/;

const str = (v: unknown, name: string, max = 200): string => {
  if (typeof v !== 'string' || !v.trim() || v.length > max) throw new HttpError(400, 'invalid_input', `Field ${name} tidak valid.`);
  return v.trim();
};
const days = (v: unknown): number => {
  const n = Number(v);
  if (!DURATIONS.includes(n)) throw new HttpError(400, 'invalid_input', 'Masa aktif harus 1, 7, 30, 90, atau 365 hari.');
  return n;
};
const publicUser = (p: Profile, usedToday = 0) => ({
  id: p.id, username: p.username, display_name: p.display_name, is_active: p.is_active, expires_at: p.expires_at,
  daily_limit: p.daily_limit, created_at: p.created_at, state: licenseState(p), used_today: usedToday,
  must_change_password: p.must_change_password,
});

async function targetUser(db: DB, id: unknown): Promise<Profile> {
  const uid = str(id, 'user_id', 64);
  const { data } = await db.from('profiles').select('*').eq('id', uid).maybeSingle();
  if (!data) throw new HttpError(404, 'not_found', 'Pengguna tidak ditemukan.');
  if (data.role !== 'user') throw new HttpError(403, 'forbidden', 'Akun admin tidak dapat diubah lewat menu ini.');
  return data as Profile;
}

async function issueLicense(db: DB, admin: Profile, d: number, userId: string | null): Promise<{ token: string; id: string }> {
  const token = generateToken();
  const row: Record<string, unknown> = {
    token_hash: await hashToken(token), token_hint: token.slice(-4), duration_days: d, created_by: admin.id,
  };
  if (userId) Object.assign(row, { status: 'redeemed', user_id: userId, redeemed_at: new Date().toISOString() });
  const { data, error } = await db.from('licenses').insert(row).select('id').single();
  if (error || !data) throw new HttpError(500, 'create_failed', 'Gagal membuat token.');
  return { token, id: data.id as string };
}

serve('admin', async (req) => {
  const db = serviceClient();
  const admin = await authenticate(req, db);
  if (admin.role !== 'admin' || !admin.is_active) throw new HttpError(403, 'forbidden', 'Hanya admin yang boleh mengakses.');
  const b = await readJson(req);
  const action = String(b.action ?? '');
  const log = (status: string, detail: string) => logUsage(db, { user_id: admin.id, username: admin.username, action: `admin_${action}`, status, detail });

  switch (action) {
    // ───────────── statistik ─────────────
    case 'stats': {
      const now = new Date().toISOString();
      const today = startOfToday().toISOString();
      const week = new Date(Date.now() - 7 * 86400e3).toISOString();
      const cnt = async (q: PromiseLike<{ count: number | null }>) => (await q).count ?? 0;
      const head = { count: 'exact' as const, head: true };
      const [total, active, expired, disabled, unused, today_ok, today_err, week_ok, keyRow] = await Promise.all([
        cnt(db.from('profiles').select('id', head).eq('role', 'user')),
        cnt(db.from('profiles').select('id', head).eq('role', 'user').eq('is_active', true).gt('expires_at', now)),
        cnt(db.from('profiles').select('id', head).eq('role', 'user').eq('is_active', true).or(`expires_at.lte.${now},expires_at.is.null`)),
        cnt(db.from('profiles').select('id', head).eq('role', 'user').eq('is_active', false)),
        cnt(db.from('licenses').select('id', head).eq('status', 'unused')),
        cnt(db.from('usage_logs').select('id', head).eq('action', 'analyze').eq('status', 'ok').gte('created_at', today)),
        cnt(db.from('usage_logs').select('id', head).eq('action', 'analyze').in('status', ['error']).gte('created_at', today)),
        cnt(db.from('usage_logs').select('id', head).eq('action', 'analyze').eq('status', 'ok').gte('created_at', week)),
        db.from('app_secrets').select('name').eq('name', 'openai_api_key').maybeSingle(),
      ]);
      const configured = !!(keyRow as { data: unknown }).data || !!Deno.env.get('OPENAI_API_KEY');
      return json({ ok: true, stats: { total_users: total, active_users: active, expired_users: expired, disabled_users: disabled, unused_tokens: unused, requests_today: today_ok, errors_today: today_err, requests_7d: week_ok, openai_configured: configured } });
    }

    // ───────────── pengguna ─────────────
    case 'list_users': {
      const { data } = await db.from('profiles').select('*').eq('role', 'user').order('created_at', { ascending: false }).limit(500);
      const { data: logs } = await db.from('usage_logs').select('user_id').eq('action', 'analyze').eq('status', 'ok')
        .gte('created_at', startOfToday().toISOString()).limit(20000);
      const tally = new Map<string, number>();
      (logs ?? []).forEach((l: { user_id: string | null }) => { if (l.user_id) tally.set(l.user_id, (tally.get(l.user_id) ?? 0) + 1); });
      return json({ ok: true, users: (data ?? []).map((p: Profile) => publicUser(p, tally.get(p.id) ?? 0)) });
    }

    case 'create_user': {
      const username = str(b.username, 'username', 32).toLowerCase();
      const password = validatePassword(b.password);
      const d = days(b.duration_days);
      const expires = addDays(new Date(), d).toISOString();
      const p = await createAccount(db, {
        username, password, role: 'user', display_name: typeof b.display_name === 'string' ? b.display_name.trim().slice(0, 80) || null : null,
        expires_at: expires, created_by: admin.id,
      });
      const lic = await issueLicense(db, admin, d, p.id);
      await db.from('licenses').update({ expires_at: expires }).eq('id', lic.id);
      await log('ok', `create ${username} ${d}d`);
      return json({ ok: true, user: publicUser(p), token: lic.token, note: 'Token hanya ditampilkan sekali.' });
    }

    case 'update_user': {
      const p = await targetUser(db, b.user_id);
      const patch: Record<string, unknown> = {};
      const authPatch: Record<string, unknown> = {};
      if (b.username !== undefined) {
        const u = str(b.username, 'username', 32).toLowerCase();
        if (!USERNAME_RE.test(u)) throw new HttpError(400, 'invalid_input', 'Username tidak valid.');
        if (u !== p.username) {
          const { data: ex } = await db.from('profiles').select('id').eq('username', u).maybeSingle();
          if (ex) throw new HttpError(409, 'username_taken', 'Username sudah dipakai.');
          patch.username = u; authPatch.email = usernameToEmail(u); authPatch.email_confirm = true;
        }
      }
      if (b.display_name !== undefined) patch.display_name = b.display_name === null ? null : String(b.display_name).trim().slice(0, 80);
      if (b.daily_limit !== undefined) {
        if (b.daily_limit === null) patch.daily_limit = null;
        else {
          const n = Number(b.daily_limit);
          if (!Number.isInteger(n) || n < 0 || n > 100000) throw new HttpError(400, 'invalid_input', 'Batas harian tidak valid.');
          patch.daily_limit = n;
        }
      }
      if (b.password !== undefined && b.password !== '') {
        authPatch.password = validatePassword(b.password);
        patch.must_change_password = b.force_change === true;
      }
      if (Object.keys(authPatch).length) {
        const { error } = await db.auth.admin.updateUserById(p.id, authPatch);
        if (error) throw new HttpError(400, 'update_failed', `Gagal memperbarui akun: ${error.message}`);
      }
      if (Object.keys(patch).length) await db.from('profiles').update(patch).eq('id', p.id);
      await log('ok', `update ${p.username}`);
      const { data: fresh } = await db.from('profiles').select('*').eq('id', p.id).single();
      return json({ ok: true, user: publicUser(fresh as Profile) });
    }

    case 'set_active': {
      const p = await targetUser(db, b.user_id);
      const active = b.active === true;
      // ban di Auth → login & refresh token ditolak total
      const { error } = await db.auth.admin.updateUserById(p.id, { ban_duration: active ? 'none' : '876000h' });
      if (error) throw new HttpError(400, 'update_failed', `Gagal: ${error.message}`);
      await db.from('profiles').update({ is_active: active }).eq('id', p.id);
      await log('ok', `${active ? 'aktifkan' : 'nonaktifkan'} ${p.username}`);
      return json({ ok: true });
    }

    case 'extend': {
      const p = await targetUser(db, b.user_id);
      const d = days(b.days);
      const base = p.expires_at && new Date(p.expires_at).getTime() > Date.now() ? new Date(p.expires_at) : new Date();
      const exp = addDays(base, d).toISOString();
      await db.from('profiles').update({ expires_at: exp }).eq('id', p.id);
      await log('ok', `extend ${p.username} +${d}d`);
      return json({ ok: true, expires_at: exp });
    }

    case 'delete_user': {
      const p = await targetUser(db, b.user_id);
      const { error } = await db.auth.admin.deleteUser(p.id);
      if (error) throw new HttpError(400, 'delete_failed', `Gagal menghapus: ${error.message}`);
      await log('ok', `delete ${p.username}`);
      return json({ ok: true });
    }

    // ───────────── lisensi ─────────────
    case 'issue_token': {
      const d = days(b.duration_days);
      const n = Math.min(20, Math.max(1, Number(b.count ?? 1) | 0));
      const tokens: string[] = [];
      for (let i = 0; i < n; i++) tokens.push((await issueLicense(db, admin, d, null)).token);
      await log('ok', `issue ${n}x${d}d`);
      return json({ ok: true, tokens, duration_days: d, note: 'Token hanya ditampilkan sekali.' });
    }

    case 'list_licenses': {
      const { data } = await db.from('licenses').select('id,token_hint,duration_days,status,created_at,redeemed_at,expires_at,user_id')
        .order('created_at', { ascending: false }).limit(300);
      const ids = [...new Set((data ?? []).map((l: { user_id: string | null }) => l.user_id).filter(Boolean))] as string[];
      const names = new Map<string, string>();
      if (ids.length) {
        const { data: ps } = await db.from('profiles').select('id,username').in('id', ids);
        (ps ?? []).forEach((x: { id: string; username: string }) => names.set(x.id, x.username));
      }
      return json({ ok: true, licenses: (data ?? []).map((l: Record<string, unknown>) => ({ ...l, username: names.get(l.user_id as string) ?? null })) });
    }

    case 'revoke_license': {
      const id = str(b.license_id, 'license_id', 64);
      const { data } = await db.from('licenses').update({ status: 'revoked' }).eq('id', id).eq('status', 'unused').select('id').maybeSingle();
      if (!data) throw new HttpError(409, 'not_revocable', 'Hanya token yang belum dipakai yang bisa dicabut. Untuk token terpakai, nonaktifkan akun.');
      await log('ok', `revoke ${id}`);
      return json({ ok: true });
    }

    // ───────────── log penggunaan ─────────────
    case 'usage_logs': {
      const limit = Math.min(200, Math.max(1, Number(b.limit ?? 100) | 0));
      const offset = Math.max(0, Number(b.offset ?? 0) | 0);
      let q = db.from('usage_logs').select('*').order('created_at', { ascending: false }).range(offset, offset + limit - 1);
      if (typeof b.user_id === 'string' && b.user_id) q = q.eq('user_id', b.user_id);
      const { data } = await q;
      return json({ ok: true, logs: data ?? [] });
    }

    // ───────────── pengaturan global ─────────────
    case 'get_settings': {
      const models = await getSetting<Record<string, string>>(db, 'models', {});
      const hint = await getSetting<string | null>(db, 'openai_key_hint', null);
      const { data: sec } = await db.from('app_secrets').select('updated_at').eq('name', 'openai_api_key').maybeSingle();
      return json({
        ok: true,
        settings: {
          models, daily_limit: await getSetting<number>(db, 'daily_limit', 100),
          rate_limit_per_minute: await getSetting<number>(db, 'rate_limit_per_minute', 6),
          openai_configured: !!sec || !!Deno.env.get('OPENAI_API_KEY'), openai_hint: hint, openai_updated_at: sec?.updated_at ?? null,
          openai_source: sec ? 'database' : (Deno.env.get('OPENAI_API_KEY') ? 'env' : 'none'),
        },
      });
    }

    case 'set_settings': {
      const upserts: { key: string; value: unknown; updated_by: string }[] = [];
      if (b.models !== undefined) {
        const m = b.models as Record<string, unknown>;
        const out: Record<string, string> = {};
        for (const k of ['fast', 'accurate', 'study']) {
          const v = String(m?.[k] ?? '').trim();
          if (!MODEL_RE.test(v)) throw new HttpError(400, 'invalid_input', `Nama model untuk "${k}" tidak valid.`);
          out[k] = v;
        }
        upserts.push({ key: 'models', value: out, updated_by: admin.id });
      }
      if (b.daily_limit !== undefined) {
        const n = Number(b.daily_limit);
        if (!Number.isInteger(n) || n < 1 || n > 100000) throw new HttpError(400, 'invalid_input', 'Batas harian harus 1-100000.');
        upserts.push({ key: 'daily_limit', value: n, updated_by: admin.id });
      }
      if (b.rate_limit_per_minute !== undefined) {
        const n = Number(b.rate_limit_per_minute);
        if (!Number.isInteger(n) || n < 1 || n > 120) throw new HttpError(400, 'invalid_input', 'Rate limit harus 1-120 per menit.');
        upserts.push({ key: 'rate_limit_per_minute', value: n, updated_by: admin.id });
      }
      if (!upserts.length) throw new HttpError(400, 'invalid_input', 'Tidak ada perubahan.');
      const { error } = await db.from('app_settings').upsert(upserts.map((u) => ({ ...u, updated_at: new Date().toISOString() })));
      if (error) throw new HttpError(500, 'save_failed', 'Gagal menyimpan pengaturan.');
      await log('ok', upserts.map((u) => u.key).join(','));
      return json({ ok: true });
    }

    case 'set_openai_key': {
      const key = str(b.api_key, 'api_key', 300);
      if (!/^sk-[A-Za-z0-9_\-]{16,}$/.test(key)) throw new HttpError(400, 'invalid_input', 'Format API key tidak valid (harus diawali sk-).');
      await saveOpenAIKey(db, key);
      await db.from('app_settings').upsert({ key: 'openai_key_hint', value: `…${key.slice(-4)}`, updated_at: new Date().toISOString(), updated_by: admin.id });
      await log('ok', 'set openai key');
      return json({ ok: true, hint: `…${key.slice(-4)}` });
    }

    case 'test_openai': {
      const apiKey = await getOpenAIKey(db);
      const models = await getSetting<Record<string, string>>(db, 'models', {});
      const model = typeof b.model === 'string' && MODEL_RE.test(b.model) ? b.model : (models.accurate ?? 'gpt-4o');
      const ctrl = new AbortController();
      const t = setTimeout(() => ctrl.abort(), 15_000);
      try {
        const r = await fetch(`${OPENAI_BASE}/models/${encodeURIComponent(model)}`, { headers: { Authorization: `Bearer ${apiKey}` }, signal: ctrl.signal });
        if (r.ok) return json({ ok: true, valid: true, message: `Key valid dan model "${model}" tersedia.` });
        if (r.status === 401) return json({ ok: true, valid: false, message: 'API key ditolak OpenAI (401).' });
        if (r.status === 404) return json({ ok: true, valid: false, message: `Model "${model}" tidak ditemukan / tidak tersedia untuk akun ini.` });
        return json({ ok: true, valid: false, message: `OpenAI membalas status ${r.status}.` });
      } catch {
        return json({ ok: true, valid: false, message: 'Tidak dapat menghubungi OpenAI (timeout/jaringan).' });
      } finally { clearTimeout(t); }
    }

    default:
      throw new HttpError(400, 'invalid_input', 'Aksi tidak dikenal.');
  }
});
