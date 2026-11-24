// Token lisensi: AISP-XXXXX-XXXXX-XXXXX-XXXXX (100 bit entropi, CSPRNG). Hanya hash yang disimpan.
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 32 simbol tanpa karakter ambigu (0/O, 1/I)

export function generateToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(20));
  const chars = Array.from(bytes, (b) => ALPHABET[b & 31]); // 256 % 32 == 0 → tanpa bias
  const groups = [0, 5, 10, 15].map((i) => chars.slice(i, i + 5).join(''));
  return `AISP-${groups.join('-')}`;
}

export function normalizeToken(s: string): string {
  return s.trim().toUpperCase().replace(/\s+/g, '');
}

export async function hashToken(token: string): Promise<string> {
  const pepper = Deno.env.get('TOKEN_PEPPER') ?? '';
  const data = new TextEncoder().encode(pepper + normalizeToken(token));
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

export function isTokenFormat(s: string): boolean {
  return /^AISP-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}$/.test(normalizeToken(s));
}
