import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../models/local_settings.dart';
import '../services/native_bridge.dart';
import 'settings_controller.dart';

/// Mengatur siklus hidup panel native dari Flutter + menyinkronkan sesi Supabase ke PanelService.
class PanelController extends ChangeNotifier {
  PanelController(this._settings);
  final SettingsController _settings;

  bool overlay = false;
  bool running = false;
  bool accessibility = false;
  StreamSubscription<AuthState>? _sub;

  SupabaseClient get _sb => Supabase.instance.client;

  void init() {
    // Setiap token baru (login/refresh) langsung didorong ke native.
    _sub = _sb.auth.onAuthStateChange.listen((e) {
      if (e.session != null) pushSession();
    });
  }

  Map<String, dynamic> _sessionMap() {
    final s = _sb.auth.currentSession;
    return {
      'supabaseUrl': Env.supabaseUrl,
      'anonKey': Env.anonKey,
      if (s != null) 'accessToken': s.accessToken,
      if (s?.refreshToken != null) 'refreshToken': s!.refreshToken,
    };
  }

  Future<void> pushSession() async {
    try {
      await NativeBridge.updateConfig(_sessionMap());
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      final st = await NativeBridge.status();
      overlay = st.overlay;
      running = st.running;
      accessibility = st.accessibility;
    } catch (_) {}
    notifyListeners();
  }

  /// Native dapat menukar refresh token sendiri (panel dipakai >1 jam). Sinkronkan agar sesi Flutter tidak basi.
  Future<void> syncFromNative() async {
    try {
      final n = await NativeBridge.readNativeState();
      if (n['refreshed'] == true &&
          (n['refreshToken'] as String?)?.isNotEmpty == true) {
        await _sb.auth.setSession(n['refreshToken'] as String);
      }
      final mode = n['mode'] as String?;
      final conf = (n['confidence'] as num?)?.toInt();
      if (mode != null && conf != null)
        await _settings.adoptFromNative(mode, conf);
    } catch (_) {}
  }

  /// Mengembalikan pesan error, atau null bila sukses.
  Future<String?> start() async {
    if (_sb.auth.currentSession == null)
      return 'Sesi login tidak ada. Login ulang.';
    try {
      if (!(await Permission.notification.status).isGranted)
        await Permission.notification.request();
      final cfg = {..._sessionMap(), ..._settings.s.toNative()};
      final ok = await NativeBridge.startPanel(cfg);
      await refresh();
      if (!ok)
        return 'Izin perekaman layar ditolak. Pilih "Seluruh layar" pada dialog.';
      await Future.delayed(const Duration(milliseconds: 600));
      await NativeBridge.moveToBack();
      return null;
    } on PlatformException catch (e) {
      await refresh();
      if (e.code == 'overlay_permission') {
        await NativeBridge.openOverlaySettings();
        return 'Aktifkan "Tampil di atas aplikasi lain" untuk AI Smart Panel, lalu tekan Mulai lagi.';
      }
      return e.message ?? 'Gagal memulai panel (${e.code}).';
    } catch (e) {
      return 'Gagal memulai panel: $e';
    }
  }

  Future<void> stop() async {
    try {
      await NativeBridge.stopPanel();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));
    await refresh();
  }

  Future<void> resetGeometry() =>
      NativeBridge.updateConfig({'resetGeometry': true});

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
