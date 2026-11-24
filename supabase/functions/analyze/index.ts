// Proxy OpenAI Vision. Semua pengecekan (lisensi, status, kuota, rate limit) dilakukan DI SERVER.
import {
  HttpError, assertUsable, authenticate, getSetting, json, logUsage, readJson, serve, serviceClient, startOfToday,
} from '../_shared/common.ts';
import { getOpenAIKey } from '../_shared/secrets.ts';

type Mode = 'fast' | 'accurate' | 'study';
const OPENAI_BASE = Deno.env.get('OPENAI_BASE_URL') ?? 'https://api.openai.com/v1';

const MODES: Record<Mode, { maxTokens: number; detail: 'auto' | 'high'; style: string }> = {
  fast: { maxTokens: 700, detail: 'auto', style: 'MODE CEPAT: beri jawaban final sesingkat mungkin. "explanation" maksimal 2 kalimat.' },
  accurate: { maxTokens: 1800, detail: 'high', style: 'MODE AKURAT: analisis mendalam. Baca teks, tabel, rumus, dan gambar dengan teliti, kerjakan langkah demi langkah secara internal, periksa ulang hasil, lalu tulis "explanation" yang ringkas namun mencakup alasan utama.' },
  study: { maxTokens: 2400, detail: 'high', style: 'MODE BELAJAR: beri jawaban lalu langkah penyelesaian yang runtut dan mudah dipahami pelajar: konsep yang dipakai, langkah-langkah, mengapa opsi lain kurang tepat (untuk pilihan ganda), dan satu tips mengingat.' },
};
const CONF: Record<number, string> = {
  100: 'Kehati-hatian MAKSIMAL: periksa ulang setiap langkah, jangan menebak. Jika teks tidak terbaca/ambigu atau soal kurang data, katakan terus terang di "caveats".',
  80: 'Kehati-hatian SEIMBANG: periksa hasil sekali dan sebutkan asumsi penting di "caveats".',
  60: 'Kehati-hatian RINGAN: utamakan kecepatan, asumsi wajar boleh dipakai; tetap sebutkan keraguan di "caveats".',
};

function systemPrompt(mode: Mode, conf: number): string {
  return [
    'Kamu adalah asisten belajar yang membantu pelajar berlatih mengerjakan soal dan memahami materi.',
    'Masukan adalah screenshot layar (biasanya halaman web). Abaikan elemen antarmuka browser dan iklan; fokus pada konten belajar.',
    'Kenali teks, soal pilihan ganda, esai, isian, tabel, rumus, dan gambar/diagram. Untuk pilihan ganda sebutkan huruf opsi DAN isinya. Jika ada beberapa soal terlihat, bahas semuanya bernomor.',
    'Jika tidak ada soal/konten yang terbaca, jelaskan singkat di "answer" dan isi "question_type" = "lainnya".',
    'Gunakan Bahasa Indonesia kecuali soal berbahasa lain.',
    MODES[mode].style,
    CONF[conf],
    '"confidence" adalah perkiraan keyakinanmu sendiri (0-100), BUKAN jaminan kebenaran.',
    'Balas HANYA satu objek JSON valid dengan kunci persis:',
    '{"question_text": string, "question_type": "pilihan_ganda"|"esai"|"isian"|"lainnya", "answer": string, "explanation": string, "confidence": integer 0-100, "caveats": string}',
  ].join('\n');
}

function str(v: unknown): string { return Array.isArray(v) ? v.join('\n') : v == null ? '' : String(v); }

function normalize(raw: Record<string, unknown>) {
  let c = Number(raw?.confidence);
  const conf = Number.isFinite(c) ? Math.max(0, Math.min(100, Math.round(c))) : null;
  const type = ['pilihan_ganda', 'esai', 'isian', 'lainnya'].includes(String(raw?.question_type)) ? String(raw.question_type) : 'lainnya';
  return {
    question_text: str(raw?.question_text), question_type: type, answer: str(raw?.answer),
    explanation: str(raw?.explanation), confidence: conf, caveats: str(raw?.caveats),
  };
}

serve('analyze', async (req) => {
  const t0 = Date.now();
  const db = serviceClient();
  const p = await authenticate(req, db);
  const who = { user_id: p.id, username: p.username };
  let mode: Mode = 'accurate';
  let model = '';

  try {
    assertUsable(p);

    // ----- validasi input -----
    const b = await readJson(req);
    const img = b.image_base64;
    const mime = String(b.mime ?? 'image/jpeg');
    mode = String(b.mode ?? 'accurate') as Mode;
    const conf = Number(b.confidence ?? 80);
    if (typeof img !== 'string' || img.length < 100) throw new HttpError(400, 'invalid_input', 'Gambar tidak ada atau tidak valid.');
    if (img.length > 7_000_000) throw new HttpError(413, 'too_large', 'Gambar terlalu besar. Pilih area yang lebih kecil.');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mime)) throw new HttpError(400, 'invalid_input', 'Format gambar tidak didukung.');
    if (!(mode in MODES)) throw new HttpError(400, 'invalid_input', 'Mode tidak dikenal.');
    if (![100, 80, 60].includes(conf)) throw new HttpError(400, 'invalid_input', 'Tingkat kehati-hatian harus 100, 80, atau 60.');

    // ----- kuota harian & rate limit (server-side) -----
    const globalLimit = await getSetting<number>(db, 'daily_limit', 100);
    const limit = p.daily_limit ?? globalLimit;
    const { count: used } = await db.from('usage_logs').select('id', { count: 'exact', head: true })
      .eq('user_id', p.id).eq('action', 'analyze').eq('status', 'ok').gte('created_at', startOfToday().toISOString());
    if ((used ?? 0) >= limit) throw new HttpError(429, 'quota_exceeded', `Batas penggunaan harian (${limit}) tercapai. Coba lagi besok.`);

    const perMin = await getSetting<number>(db, 'rate_limit_per_minute', 6);
    const { count: recent } = await db.from('usage_logs').select('id', { count: 'exact', head: true })
      .eq('user_id', p.id).eq('action', 'analyze').in('status', ['ok', 'error'])
      .gte('created_at', new Date(Date.now() - 60e3).toISOString());
    if ((recent ?? 0) >= perMin) throw new HttpError(429, 'rate_limited', 'Terlalu cepat. Tunggu sebentar lalu coba lagi.');

    // ----- model & key (diatur admin, tanpa update APK) -----
    const models = await getSetting<Record<string, string>>(db, 'models', {});
    model = models[mode] || (mode === 'fast' ? 'gpt-4o-mini' : 'gpt-4o');
    const apiKey = await getOpenAIKey(db);

    // ----- panggil OpenAI (timeout 80 dtk) -----
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 80_000);
    let up: Response;
    try {
      up = await fetch(`${OPENAI_BASE}/chat/completions`, {
        method: 'POST', signal: ctrl.signal,
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
        body: JSON.stringify({
          model, max_completion_tokens: MODES[mode].maxTokens, response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: systemPrompt(mode, conf) },
            { role: 'user', content: [
              { type: 'text', text: 'Analisis konten pada screenshot ini.' },
              { type: 'image_url', image_url: { url: `data:${mime};base64,${img}`, detail: MODES[mode].detail } },
            ] },
          ],
        }),
      });
    } catch (e) {
      if ((e as Error).name === 'AbortError') throw new HttpError(504, 'timeout', 'Waktu habis menunggu AI. Coba lagi.');
      throw new HttpError(502, 'upstream_error', 'Tidak dapat menghubungi layanan AI.');
    } finally { clearTimeout(timer); }

    if (!up.ok) {
      const t = (await up.text().catch(() => '')).slice(0, 300);
      console.error(JSON.stringify({ fn: 'analyze', openai_status: up.status, body: t }));
      if (up.status === 429) throw new HttpError(503, 'upstream_busy', 'Layanan AI sedang sibuk atau kuota server habis.');
      if (up.status === 401 || up.status === 403) throw new HttpError(503, 'openai_key_invalid', 'OpenAI API Key tidak valid. Hubungi admin.');
      if (up.status === 400 || up.status === 404) throw new HttpError(502, 'model_error', 'Model ditolak OpenAI. Hubungi admin untuk memeriksa nama model.');
      throw new HttpError(502, 'upstream_error', 'Layanan AI bermasalah. Coba lagi.');
    }

    const data = await up.json();
    const content = data?.choices?.[0]?.message?.content ?? '';
    let parsed: Record<string, unknown>;
    try { parsed = JSON.parse(content); } catch { parsed = { answer: content, question_type: 'lainnya' }; }
    const result = normalize(parsed);
    if (!result.answer.trim() && !result.explanation.trim()) throw new HttpError(502, 'empty_result', 'AI tidak memberi jawaban. Coba screenshot ulang.');

    await db.from('history').insert({
      user_id: p.id, mode, confidence_pref: conf, question_text: result.question_text, question_type: result.question_type,
      answer: result.answer, explanation: result.explanation, caveats: result.caveats, ai_confidence: result.confidence, model,
    });
    await logUsage(db, {
      ...who, action: 'analyze', status: 'ok', mode, model, latency_ms: Date.now() - t0,
      prompt_tokens: data?.usage?.prompt_tokens, completion_tokens: data?.usage?.completion_tokens,
    });

    return json({ ok: true, result, model, expires_at: p.expires_at, usage: { used: (used ?? 0) + 1, limit } });
  } catch (e) {
    if (e instanceof HttpError) {
      const st = e.code === 'quota_exceeded' ? 'quota' : e.code === 'rate_limited' ? 'rate_limited'
        : e.status === 403 || e.status === 400 || e.status === 413 ? 'denied' : 'error';
      await logUsage(db, { ...who, action: 'analyze', status: st, mode, model, latency_ms: Date.now() - t0, detail: e.code });
    }
    throw e;
  }
});
