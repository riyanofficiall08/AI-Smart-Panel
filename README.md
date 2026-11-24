# AI SMART PANEL

Asisten belajar berbentuk **panel AI melayang** untuk Android. Flutter (UI) + **Kotlin native** (overlay `WindowManager`
`TYPE_APPLICATION_OVERLAY`, MediaProjection, foreground service) + **Supabase** (Auth, PostgreSQL + RLS, Edge Functions)
sebagai backend serverless — **tanpa VPS**. OpenAI API Key & service-role key **tidak pernah ada di APK**.

> Ditujukan untuk belajar, latihan, dan simulasi yang diizinkan. Hormati aturan ujian dan batasan screenshot Android.

---
## 1. Arsitektur
```
┌────────────── APK ──────────────┐        ┌────────────── Supabase ───────────────┐
│ Flutter UI (login, dashboard,   │  JWT   │ Auth (password di-hash, ban akun)     │
│ admin, riwayat, pengaturan)     ├───────►│ Edge Functions: account · admin       │
│            ▲ MethodChannel      │        │                 analyze · bootstrap    │
│ Kotlin: PanelService            │  JWT   │ PostgreSQL + RLS: profiles licenses    │
│  ├ Overlay (WindowManager)      ├───────►│  app_settings app_secrets usage_logs   │
│  ├ MediaProjection (screenshot) │ analyze│  history                               │
│  └ ApiClient → /functions/analyze        │ analyze ──► OpenAI Vision (key di server)
└─────────────────────────────────┘        └───────────────────────────────────────┘
```
Prinsip keamanan: **role, status akun, masa aktif, kuota, dan rate limit selalu divalidasi di server**
(Edge Function memverifikasi JWT via `auth.getUser`, lalu membaca profil dengan service role). Nilai dari Flutter tidak dipercaya.

## 2. Struktur proyek
```
ai_smart_panel/
├─ pubspec.yaml · analysis_options.yaml
├─ config/dart_defines.example.json     # SUPABASE_URL, SUPABASE_ANON_KEY, EMAIL_DOMAIN
├─ tool/setup.sh                        # siapkan config + flutter pub get
├─ .github/workflows/build-apk.yml      # build APK otomatis → GitHub Actions Artifact
├─ android/                             # scaffold Android Embedding V2 (ikut repo)
│  ├─ settings.gradle.kts · build.gradle.kts · gradle/wrapper (Gradle 8.12, AGP 8.7.3, Kotlin 2.1.0)
│  └─ app/src/main/
│     ├─ AndroidManifest.xml · res/ (styles, ikon, accessibility_config, aisp_strings)
│     └─ kotlin/com/aismartpanel/app/
│     ├─ MainActivity.kt                # MethodChannel "com.aismartpanel/native"
│     ├─ PanelService.kt                # foreground service: overlay + MediaProjection + alur AI
│     ├─ PanelView.kt                   # panel (compact/expandable), HandleView (bulat)
│     ├─ RegionSelectorView.kt          # pemilih area: geser & ubah ukuran
│     ├─ ScreenCapturer.kt              # VirtualDisplay, crop, kompres JPEG
│     ├─ ApiClient.kt                   # panggil Edge Function analyze + refresh token
│     ├─ PanelAccessibilityService.kt   # pintasan Volume+ (opsional)
│     ├─ Prefs.kt · Ui.kt
├─ lib/
│  ├─ main.dart                         # Supabase.initialize + Gate (role → dashboard)
│  ├─ core/ env · theme · format        ├─ models/ account, admin, history, local_settings
│  ├─ services/ backend · native_bridge ├─ state/ auth · panel · settings · history
│  ├─ widgets/ common · selectors · admin_widgets
│  └─ ui/ splash · onboarding · login · change_password
│       ├─ user/  user_shell · user_dashboard · history_page · user_settings_page
│       └─ admin/ admin_shell · admin_dashboard · user_management · create_user_page
│                 license_management · config_page · api_config_page · model_config_page
│                 usage_logs_page · admin_settings_page
└─ supabase/
   ├─ config.toml
   ├─ migrations/001_schema.sql         # tabel + RLS + seed
   ├─ functions/_shared · bootstrap · account · analyze · admin
   ├─ tests/rls_test.py                 # uji RLS pada PostgreSQL nyata
   └─ .env.example                      # daftar secrets
```
Pemetaan halaman: Splash, Onboarding, Login (tab Pengguna/Admin), Admin Dashboard, User Dashboard, **Floating Panel / Handle /
Screenshot Preview / AI Analysis Result (native Kotlin di dalam panel)**, History, User Management, Create User,
API Configuration, Model Configuration, License Management, Settings.

## 3. Setup Supabase (sekali)
Prasyarat: akun Supabase, [Supabase CLI](https://supabase.com/docs/guides/cli), akun OpenAI.
```bash
supabase login
supabase link --project-ref <PROJECT_REF>

# 1) Database: tabel + RLS + seed
supabase db push                 # atau tempel supabase/migrations/001_schema.sql di SQL Editor

# 2) Secrets (lihat supabase/.env.example)
cp supabase/.env.example supabase/.env      # isi SECRETS_ENC_KEY, BOOTSTRAP_SECRET, TOKEN_PEPPER
supabase secrets set --env-file supabase/.env

# 3) Edge Functions (verify_jwt=false di config.toml; JWT diverifikasi di kode)
supabase functions deploy bootstrap account analyze admin

# 4) Buat ADMIN pertama (sekali)
curl -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/bootstrap" \
  -H "x-bootstrap-secret: <BOOTSTRAP_SECRET>" -H "apikey: <ANON_KEY>"
```
Akun awal: username **`admin`**, password **`Riyan.123`** (disimpan di Supabase Auth sebagai hash; `must_change_password=true`).
Aplikasi **memaksa penggantian password** saat login pertama dan server menolak fitur AI sampai password diganti.

**Setelah login admin pertama:** `supabase functions delete bootstrap` lalu `supabase secrets unset BOOTSTRAP_SECRET`.

Opsional: Dashboard → Authentication → Providers → Email: matikan "Confirm email" & sign-ups publik (akun hanya dibuat admin;
Edge Function memakai `email_confirm: true`). Login memakai email sintetis `username@<EMAIL_DOMAIN>` — tidak ada email yang dikirim.

## 4. Konfigurasi OpenAI (dari aplikasi, tanpa update APK)
Login Admin → **Konfigurasi → API Configuration** → tempel `sk-…` → *Simpan key* → *Tes key & model*.
Key dikirim lewat HTTPS ke Edge Function, **dienkripsi AES-256-GCM** dengan `SECRETS_ENC_KEY` (hanya ada di Edge Function Secrets),
disimpan di tabel `app_secrets` (tanpa policy RLS = tak terbaca klien mana pun), dan tidak pernah dikirim balik (hanya 4 karakter terakhir).
Alternatif: `supabase secrets set OPENAI_API_KEY=sk-…` (dipakai bila key database kosong).
**Model Configuration** mengatur model untuk mode Cepat/Akurat/Belajar, batas harian default, dan rate limit — berlaku langsung.

## 5. Build APK
Prasyarat: Flutter 3.32.x (stabil), **JDK 17**, Android SDK (platform 35 + build-tools; diunduh otomatis oleh Gradle bila lisensi diterima).
`android/` sudah ada di repo (Embedding V2) — **jangan** menghapusnya atau menjalankan `flutter create .`.
```bash
cp config/dart_defines.example.json config/dart_defines.json    # SUPABASE_URL = https://<ref>.supabase.co (tanpa /rest/v1), anon key = publik
flutter clean && flutter pub get && flutter analyze
flutter build apk --debug --dart-define-from-file=config/dart_defines.json
# → build/app/outputs/flutter-apk/app-debug.apk
```
**Release** memerlukan keystore milik Anda (tidak ada key palsu / debug-signing otomatis):
```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias aisp
printf 'storeFile=upload-keystore.jks\nstorePassword=…\nkeyAlias=aisp\nkeyPassword=…\n' > android/key.properties   # di-.gitignore
flutter build apk --release --dart-define-from-file=config/dart_defines.json
# → build/app/outputs/flutter-apk/app-release.apk
```
Tanpa `android/key.properties`, `assembleRelease` sengaja gagal dengan pesan jelas.

**GitHub Actions** (`.github/workflows/build-apk.yml`): isi Repository Secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `EMAIL_DOMAIN`
(opsional untuk release: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`).
Jalankan workflow → unduh artifact **ai-smart-panel-apk**. Release hanya dibangun jika keystore secrets lengkap.

## 6. Cara pakai
**Admin:** login tab *Admin* → Dashboard (statistik) → *Buat pengguna* (username, password, masa aktif 1/7/30/90/365 hari → token `AISP-…`
tampil **sekali**) → kelola: edit/ganti password, aktif/nonaktif (ban di Auth), perpanjang, hapus, log penggunaan; *Lisensi*: buat/cabut token massal.

**User:** login → Beranda: masa aktif, status token, kuota harian → **Mulai Panel Melayang** → beri izin → dialog perekaman layar
(pilih **"Seluruh layar"**) → buka Chrome/halaman latihan. Di panel: **📷 Screenshot** (layar penuh / pilih area yang bisa digeser & diubah ukurannya)
→ pratinjau tampil → **✨ Analisis AI** → hasil bisa di-scroll → **📋 Salin**. **—** = minimize jadi handle bulat (ketuk = buka),
**👁** = sembunyikan penuh (buka lewat notifikasi "Tampil/Sembunyi" atau Volume+), **✕** = tutup, **◢** = ubah ukuran, header = geser.
Token lisensi tambahan: Beranda → *Masukkan / perpanjang dengan token*.

## 7. Izin Android, cara kerja, dan keterbatasan (jujur)
| Fitur | Mekanisme | Catatan |
|---|---|---|
| Panel di atas aplikasi lain | `SYSTEM_ALERT_WINDOW` + `WindowManager` `TYPE_APPLICATION_OVERLAY` di dalam **foreground service** | Izin manual di Pengaturan. Tetap tampil saat Home/ganti aplikasi karena dimiliki service, bukan Activity. |
| Screenshot | `MediaProjection` + foreground service `mediaProjection` + notifikasi | Dialog persetujuan **setiap kali panel dimulai** (aturan Android). Android 14+: pilih "Seluruh layar". |
| Layar terproteksi | — | Aplikasi dengan `FLAG_SECURE` (sebagian aplikasi ujian/perbankan) tampil **hitam**. Tidak ada cara resmi menembusnya. |
| Volume+ | `AccessibilityService` (`flagRequestFilterKeyEvents`) | **Tidak universal**: perlu layanan diaktifkan manual; sebagian OEM/mode hemat daya mematikannya; tidak aktif saat layar terkunci; aplikasi tertentu dapat memblokir. Hanya membaca Volume+ dan hanya mengonsumsi tombol saat panel berjalan + pintasan aktif. Kebijakan Google Play membatasi AccessibilityService → cocok untuk APK pribadi. Handle bulat & notifikasi adalah cara andal. |
| Notifikasi | `POST_NOTIFICATIONS` (Android 13+) | Diperlukan agar service tidak dimatikan. |
| Sinkron sesi | Flutter mendorong token ke Kotlin; Kotlin me-refresh sendiri bila perlu dan Flutter menyinkronkan saat aplikasi dibuka | Token disimpan di SharedPreferences privat aplikasi (bukan terenkripsi). |

## 8. Model keamanan
- **RLS ketat** (diuji, lihat §9): user hanya membaca profil/lisensi/riwayat/log miliknya; tidak ada policy tulis untuk user pada profiles/licenses/logs/settings; `history` hanya dapat di-insert server; admin **tidak** bisa membaca isi riwayat user (privasi); `app_secrets` tanpa akses klien.
- **Token lisensi**: `AISP-` + 20 karakter CSPRNG (100 bit), disimpan sebagai SHA-256(+pepper), hanya tampil sekali, klaim atomik, anti-tebak (5 gagal/15 menit).
- **Akun nonaktif/kedaluwarsa** ditolak di `analyze` (403 `account_disabled` / `license_expired`); menonaktifkan akun juga **ban di Supabase Auth** (login & refresh gagal).
- **Pembatasan**: kuota harian per user (override per akun), rate limit per menit, validasi input (ukuran gambar, mode, kehati-hatian), timeout 80 dtk, logging ke `usage_logs` + log fungsi.
- Password awal `Riyan.123` hanya default bootstrap; wajib diganti (diverifikasi server dengan password lama).

## 9. Status verifikasi (yang benar-benar dijalankan)
| Komponen | Hasil |
|---|---|
| Kotlin (11 file) | ✅ Ter-compile (kotlinc 2.0.21) terhadap `android.jar` API 33 oleh pembuat awal; belum dikompilasi lewat Gradle/AGP nyata |
| SQL schema | ✅ Valid di parser PostgreSQL & dieksekusi di PostgreSQL nyata |
| **RLS** | ✅ **25 uji lulus** (`supabase/tests/rls_test.py`: isolasi user, anti-eskalasi role, secrets, admin nonaktif, dst.) |
| Token & enkripsi AES-GCM | ✅ Diuji runtime (format, keunikan 2000 token, normalisasi hash, roundtrip, IV acak) |
| Edge Functions (TS) | ✅ Sintaks valid (esbuild). ⚠ Belum dijalankan di runtime Supabase/Deno |
| Dart (35 file) | ✅ Sintaks valid (parser Dart). ⚠ **Belum ada `flutter analyze`/`flutter build`** (Flutter SDK tidak tersedia di lingkungan pembuat) |
| APK | ❌ **Belum ada bukti build sukses.** Lingkungan penyusun scaffold tidak bisa mengunduh Flutter/Android SDK. Jalankan §5 atau workflow Actions; perilaku overlay/screenshot di perangkat nyata belum diuji |

Jalankan uji RLS sendiri: `pip install pgserver psycopg2-binary && python supabase/tests/rls_test.py`.

## 10. Troubleshooting singkat
- *"deleted Android v1 embedding"* → pastikan folder `android/` dari repo ini dipakai (bukan scaffold lama), manifest memuat `flutterEmbedding=2`, dan `MainActivity` turunan `io.flutter.embedding.android.FlutterActivity`.
- *"Konfigurasi Supabase belum diisi"* → build tanpa `--dart-define-from-file`.
- *Login "Username atau password salah"* → pastikan `EMAIL_DOMAIN` sama di Flutter dan secrets fungsi; bootstrap sudah dipanggil.
- *403 password_change_required* → ganti password awal lewat layar yang muncul.
- *503 openai_not_configured / 502 model_error* → atur key & nama model di Konfigurasi admin; tes dengan "Tes key & model".
- *Panel hilang setelah beberapa waktu* → matikan penghematan baterai untuk aplikasi (OEM agresif seperti Xiaomi/Oppo/Vivo).
- *Screenshot hitam* → konten ber-`FLAG_SECURE`; atau pilih "Satu aplikasi" pada dialog (harus "Seluruh layar").
