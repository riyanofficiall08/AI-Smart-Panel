import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_status.dart';
import '../models/admin_models.dart';
import '../models/history_item.dart';

class BackendException implements Exception {
  BackendException(this.message, {this.code = 'error', this.status});
  final String message;
  final String code;
  final int? status;
  @override
  String toString() => message;
}

/// Seluruh komunikasi ke Supabase (Edge Functions + tabel ber-RLS). Tidak ada rahasia server di sini.
class Backend {
  static SupabaseClient get sb => Supabase.instance.client;

  static Future<Map<String, dynamic>> call(
    String fn,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await sb.functions.invoke(fn, body: body);
      final d = res.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      throw BackendException('Respons server tidak dikenali.');
    } on FunctionException catch (e) {
      final d = e.details;
      var msg = 'Terjadi kesalahan (${e.status}).';
      var code = 'error';
      if (d is Map) {
        msg = d['error']?.toString() ?? msg;
        code = d['code']?.toString() ?? code;
      }
      throw BackendException(msg, code: code, status: e.status);
    } on SocketException {
      throw BackendException('Tidak ada koneksi internet.', code: 'network');
    } on BackendException {
      rethrow;
    } catch (e) {
      throw BackendException(
        'Gagal menghubungi server. Periksa koneksi Anda.',
        code: 'network',
      );
    }
  }

  // ───────────── akun ─────────────
  static Future<AccountStatus> accountStatus() async =>
      AccountStatus.fromJson(await call('account', {'action': 'status'}));

  static Future<AccountStatus> redeem(String token) async =>
      AccountStatus.fromJson(
        await call('account', {'action': 'redeem', 'token': token}),
      );

  static Future<void> changePassword(String current, String next) =>
      call('account', {
        'action': 'change_password',
        'current_password': current,
        'new_password': next,
      });

  // ───────────── riwayat (RLS: hanya milik sendiri) ─────────────
  static Future<List<HistoryItem>> history() async {
    final rows = await sb
        .from('history')
        .select()
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> deleteHistory(String id) =>
      sb.from('history').delete().eq('id', id);

  static Future<void> clearHistory(String userId) =>
      sb.from('history').delete().eq('user_id', userId);

  // ───────────── admin ─────────────
  static Future<Map<String, dynamic>> _admin(
    String action, [
    Map<String, dynamic> p = const {},
  ]) => call('admin', {'action': action, ...p});

  static Future<AdminStats> stats() async => AdminStats.fromJson(
    Map<String, dynamic>.from((await _admin('stats'))['stats'] as Map),
  );

  static Future<List<AdminUser>> listUsers() async =>
      ((await _admin('list_users'))['users'] as List)
          .map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

  static Future<({AdminUser user, String token})> createUser({
    required String username,
    required String password,
    required int days,
    String? displayName,
  }) async {
    final r = await _admin('create_user', {
      'username': username,
      'password': password,
      'duration_days': days,
      'display_name': displayName,
    });
    return (
      user: AdminUser.fromJson(Map<String, dynamic>.from(r['user'] as Map)),
      token: r['token'] as String,
    );
  }

  static Future<void> updateUser(String id, Map<String, dynamic> patch) =>
      _admin('update_user', {'user_id': id, ...patch});
  static Future<void> setActive(String id, bool active) =>
      _admin('set_active', {'user_id': id, 'active': active});
  static Future<void> extend(String id, int days) =>
      _admin('extend', {'user_id': id, 'days': days});
  static Future<void> deleteUser(String id) =>
      _admin('delete_user', {'user_id': id});

  static Future<List<String>> issueTokens(int days, int count) async =>
      ((await _admin('issue_token', {
                'duration_days': days,
                'count': count,
              }))['tokens']
              as List)
          .cast<String>();

  static Future<List<LicenseRow>> licenses() async =>
      ((await _admin('list_licenses'))['licenses'] as List)
          .map((e) => LicenseRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

  static Future<void> revokeLicense(String id) =>
      _admin('revoke_license', {'license_id': id});

  static Future<List<UsageLog>> usageLogs({
    String? userId,
    int limit = 100,
  }) async =>
      ((await _admin('usage_logs', {'user_id': userId, 'limit': limit}))['logs']
              as List)
          .map((e) => UsageLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

  static Future<GlobalSettings> getSettings() async => GlobalSettings.fromJson(
    Map<String, dynamic>.from(
      (await _admin('get_settings'))['settings'] as Map,
    ),
  );

  static Future<void> setSettings(Map<String, dynamic> patch) =>
      _admin('set_settings', patch);
  static Future<void> setOpenAIKey(String key) =>
      _admin('set_openai_key', {'api_key': key});

  static Future<({bool valid, String message})> testOpenAI(
    String? model,
  ) async {
    final r = await _admin('test_openai', {'model': model});
    return (
      valid: r['valid'] == true,
      message: (r['message'] ?? '').toString(),
    );
  }
}
