/// Dibaca saat build: flutter build apk --dart-define-from-file=config/dart_defines.json
/// Hanya URL proyek + ANON key (publik, dilindungi RLS). JANGAN pernah memasukkan service_role / OpenAI key.
class Env {
  static const _rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// URL dasar proyek (https://<ref>.supabase.co). Akhiran seperti '/' atau '/rest/v1' dibuang
  /// agar Auth dan Edge Functions (Flutter & Kotlin) memakai host yang benar.
  static final String supabaseUrl = _rawSupabaseUrl
      .trim()
      .replaceAll(RegExp(r'(/rest/v1|/auth/v1|/functions/v1)?/*$'), '');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const emailDomain = String.fromEnvironment(
    'EMAIL_DOMAIN',
    defaultValue: 'aisp.example.com',
  );

  static bool get configured =>
      supabaseUrl.startsWith('https://') && anonKey.length > 20;

  static String emailFor(String username) =>
      '${username.trim().toLowerCase()}@$emailDomain';
}
