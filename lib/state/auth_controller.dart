import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../models/account_status.dart';
import '../services/backend.dart';

class AuthController extends ChangeNotifier {
  AccountStatus? status;
  bool booting = true;
  String? bootError;
  StreamSubscription<AuthState>? _sub;

  SupabaseClient get _sb => Supabase.instance.client;
  bool get hasSession => _sb.auth.currentSession != null;

  Future<void> init() async {
    _sub = _sb.auth.onAuthStateChange.listen((e) {
      if (e.event == AuthChangeEvent.signedOut) {
        status = null;
        notifyListeners();
      }
    });
    if (hasSession) await _load();
    booting = false;
    notifyListeners();
  }

  Future<void> _load() async {
    bootError = null;
    try {
      status = await Backend.accountStatus();
    } on BackendException catch (e) {
      if (e.status == 401 || e.status == 403 && e.code == 'no_profile') {
        await _sb.auth.signOut();
        status = null;
      } else {
        bootError = e.message; // jaringan/server: sesi dipertahankan, tampilkan "Coba lagi"
      }
    }
  }

  Future<void> retry() async {
    booting = true;
    notifyListeners();
    await _load();
    booting = false;
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    try {
      status = await Backend.accountStatus();
      notifyListeners();
    } on BackendException catch (e) {
      if (e.status == 401) await signOut();
    }
  }

  void setStatus(AccountStatus s) {
    status = s;
    notifyListeners();
  }

  /// [asAdmin] = pilihan pada layar login ("Masuk Admin"). Peran sebenarnya SELALU dari server.
  Future<String?> signIn(
    String username,
    String password, {
    required bool asAdmin,
  }) async {
    try {
      await _sb.auth.signInWithPassword(
        email: Env.emailFor(username),
        password: password,
      );
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('banned'))
        return 'Akun Anda dinonaktifkan. Hubungi admin.';
      if (m.contains('invalid')) return 'Username atau password salah.';
      return 'Login gagal: ${e.message}';
    } catch (_) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
    }
    try {
      final st = await Backend.accountStatus();
      if (asAdmin && !st.isAdmin) {
        await _sb.auth.signOut();
        return 'Akun ini bukan admin. Gunakan login Pengguna.';
      }
      if (!asAdmin && st.isAdmin) {
        await _sb.auth.signOut();
        return 'Akun ini admin. Gunakan tab "Admin" untuk masuk.';
      }
      status = st;
      bootError = null;
      notifyListeners();
      return null;
    } on BackendException catch (e) {
      await _sb.auth.signOut();
      return e.message;
    }
  }

  /// Setelah ganti password, sesi lama tetap berlaku; login ulang agar token segar.
  Future<void> reauthenticate(String password) async {
    final u = status?.username;
    if (u == null) return;
    await _sb.auth.signInWithPassword(
      email: Env.emailFor(u),
      password: password,
    );
    await refreshStatus();
  }

  Future<void> signOut() async {
    try {
      await _sb.auth.signOut();
    } catch (_) {}
    status = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
