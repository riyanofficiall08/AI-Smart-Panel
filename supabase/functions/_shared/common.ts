import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

export const EMAIL_DOMAIN = Deno.env.get('EMAIL_DOMAIN') ?? 'aisp.example.com';
export const TZ_OFFSET_HOURS = Number(Deno.env.get('TZ_OFFSET_HOURS') ?? '7');
export const DURATIONS = [1, 7, 30, 90, 365];

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-bootstrap-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' } });
}

export class HttpError extends Error {
  constructor(public status: number, public code: string, message: string) { super(message); }
}

export interface Profile {
  id: string;
  username: string;
  display_name: string | null;
  role: 'admin' | 'user';
  is_active: boolean;
  expires_at: string | null;
  daily_limit: number | null;
  must_change_password: boolean;
  created_at: string;
}

export function serviceClient(): SupabaseClient {
  return createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function anonClient(): SupabaseClient {
  return createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Membungkus handler: CORS, penanganan error terstruktur, logging. */
export function serve(name: string, fn: (req: Request) => Promise<Response>) {
  Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
    try {
      if (req.method !== 'POST') throw new HttpError(405, 'method_not_allowed', 'Gunakan metode POST.');
      return await fn(req);
    } catch (e) {
      if (e instanceof HttpError) {
        console.warn(JSON.stringify({ fn: name, status: e.status, code: e.code, msg: e.message }));
        return json({ ok: false, code: e.code, error: e.message }, e.status);
      }
      console.error(JSON.stringify({ fn: name, unhandled: String((e as Error)?.message ?? e) }));
      return json({ ok: false, code: 'internal', error: 'Terjadi kesalahan pada server.' }, 500);
    }
  });
}

export async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    const b = await req.json();
    if (b && typeof b === 'object' && !Array.isArray(b)) return b as Record<string, unknown>;
  } catch { /* fallthrough */ }
  throw new HttpError(400, 'invalid_input', 'Body harus berupa JSON object.');
}

/** Verifikasi JWT di server + muat profil. Peran/status TIDAK pernah dipercaya dari klien. */
export async function authenticate(req: Request, db: SupabaseClient): Promise<Profile> {
  const m = /^Bearer\s+(.+)$/i.exec(req.headers.get('Authorization') ?? '');
  if (!m) throw new HttpError(401, 'unauthorized', 'Sesi tidak valid. Silakan login ulang.');
  const { data, error } = await db.auth.getUser(m[1].trim());
  if (error || !data?.user) throw new HttpError(401, 'unauthorized', 'Sesi berakhir. Silakan login ulang.');
  const { data: p, error: pe } = await db.from('profiles').select('*').eq('id', data.user.id).maybeSingle();
  if (pe || !p) throw new HttpError(403, 'no_profile', 'Profil akun tidak ditemukan.');
  return p as Profile;
}

export type LicenseState = 'active' | 'expired' | 'no_license' | 'disabled' | 'admin';

export function licenseState(p: Profile): LicenseState {
  if (!p.is_active) return 'disabled';
  if (p.role === 'admin') return 'admin';
  if (!p.expires_at) return 'no_license';
  return new Date(p.expires_at).getTime() > Date.now() ? 'active' : 'expired';
}

/** Dipanggil sebelum fitur AI dipakai. */
export function assertUsable(p: Profile) {
  switch (licenseState(p)) {
    case 'disabled': throw new HttpError(403, 'account_disabled', 'Akun Anda dinonaktifkan. Hubungi admin.');
    case 'expired': throw new HttpError(403, 'license_expired', 'Masa aktif akun telah habis. Masukkan token baru atau hubungi admin.');
    case 'no_license': throw new HttpError(403, 'no_license', 'Akun belum memiliki masa aktif. Masukkan token lisensi.');
    default: break;
  }
  if (p.must_change_password) throw new HttpError(403, 'password_change_required', 'Ganti password awal Anda terlebih dahulu di aplikasi.');
}

export function startOfToday(): Date {
  const off = TZ_OFFSET_HOURS * 3600e3;
  const local = new Date(Date.now() + off);
  local.setUTCHours(0, 0, 0, 0);
  return new Date(local.getTime() - off);
}

export async function getSetting<T>(db: SupabaseClient, key: string, fallback: T): Promise<T> {
  const { data } = await db.from('app_settings').select('value').eq('key', key).maybeSingle();
  return (data?.value ?? fallback) as T;
}

export async function logUsage(db: SupabaseClient, row: {
  user_id?: string | null; username?: string | null; action: string; status: string;
  mode?: string; model?: string; latency_ms?: number; prompt_tokens?: number; completion_tokens?: number; detail?: string;
}) {
  const { error } = await db.from('usage_logs').insert(row);
  if (error) console.error('logUsage', error.message);
}

export function usernameToEmail(u: string) { return `${u}@${EMAIL_DOMAIN}`; }

export const USERNAME_RE = /^[a-z0-9_.]{3,32}$/;

export function validatePassword(pw: unknown): string {
  if (typeof pw !== 'string' || pw.length < 8 || pw.length > 72) {
    throw new HttpError(400, 'invalid_input', 'Password harus 8-72 karakter.');
  }
  return pw;
}

export function addDays(base: Date, days: number): Date {
  return new Date(base.getTime() + days * 86400e3);
}

/** Buat akun auth + profil; rollback bila gagal. */
export async function createAccount(db: SupabaseClient, a: {
  username: string; password: string; display_name?: string | null; role: 'admin' | 'user';
  expires_at?: string | null; must_change_password?: boolean; created_by?: string | null;
}): Promise<Profile> {
  if (!USERNAME_RE.test(a.username)) throw new HttpError(400, 'invalid_input', 'Username 3-32 karakter: huruf kecil, angka, titik, garis bawah.');
  validatePassword(a.password);
  const { data: exists } = await db.from('profiles').select('id').eq('username', a.username).maybeSingle();
  if (exists) throw new HttpError(409, 'username_taken', 'Username sudah dipakai.');

  const { data: created, error } = await db.auth.admin.createUser({
    email: usernameToEmail(a.username), password: a.password, email_confirm: true,
    user_metadata: { username: a.username },
  });
  if (error || !created?.user) throw new HttpError(400, 'create_failed', `Gagal membuat akun: ${error?.message ?? 'tidak diketahui'}`);

  const { data: profile, error: pe } = await db.from('profiles').insert({
    id: created.user.id, username: a.username, display_name: a.display_name ?? null, role: a.role,
    is_active: true, expires_at: a.expires_at ?? null, must_change_password: a.must_change_password ?? false,
    created_by: a.created_by ?? null,
  }).select('*').single();
  if (pe || !profile) {
    await db.auth.admin.deleteUser(created.user.id);
    throw new HttpError(500, 'create_failed', 'Gagal menyimpan profil akun.');
  }
  return profile as Profile;
}
