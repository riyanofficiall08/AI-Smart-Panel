import type { SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { HttpError } from './common.ts';

// OpenAI API key disimpan terenkripsi AES-256-GCM di tabel app_secrets.
// Kunci enkripsi (SECRETS_ENC_KEY, base64 32 byte) hanya ada di Edge Function Secrets.

function b64decode(s: string): Uint8Array {
  const bin = atob(s);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}
function b64encode(b: Uint8Array): string {
  let s = '';
  b.forEach((x) => (s += String.fromCharCode(x)));
  return btoa(s);
}

async function key(): Promise<CryptoKey> {
  const raw = Deno.env.get('SECRETS_ENC_KEY');
  if (!raw) throw new HttpError(500, 'server_config', 'SECRETS_ENC_KEY belum diatur di Edge Function Secrets.');
  const bytes = b64decode(raw);
  if (bytes.length !== 32) throw new HttpError(500, 'server_config', 'SECRETS_ENC_KEY harus 32 byte (base64).');
  return crypto.subtle.importKey('raw', bytes, 'AES-GCM', false, ['encrypt', 'decrypt']);
}

export async function encrypt(plain: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await key(), new TextEncoder().encode(plain)));
  const out = new Uint8Array(iv.length + ct.length);
  out.set(iv); out.set(ct, iv.length);
  return b64encode(out);
}

export async function decrypt(blob: string): Promise<string> {
  const all = b64decode(blob);
  const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: all.slice(0, 12) }, await key(), all.slice(12));
  return new TextDecoder().decode(pt);
}

/** Urutan: app_secrets (diatur admin dari aplikasi) → env OPENAI_API_KEY. */
export async function getOpenAIKey(db: SupabaseClient): Promise<string> {
  const { data } = await db.from('app_secrets').select('ciphertext').eq('name', 'openai_api_key').maybeSingle();
  if (data?.ciphertext) {
    try { return await decrypt(data.ciphertext); } catch { console.error('gagal dekripsi openai key'); }
  }
  const env = Deno.env.get('OPENAI_API_KEY');
  if (env) return env;
  throw new HttpError(503, 'openai_not_configured', 'OpenAI API Key belum diatur oleh admin.');
}

export async function saveOpenAIKey(db: SupabaseClient, apiKey: string) {
  const { error } = await db.from('app_secrets').upsert({ name: 'openai_api_key', ciphertext: await encrypt(apiKey), updated_at: new Date().toISOString() });
  if (error) throw new HttpError(500, 'save_failed', 'Gagal menyimpan key.');
}
