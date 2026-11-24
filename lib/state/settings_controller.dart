import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_settings.dart';
import '../services/native_bridge.dart';

/// Pengaturan lokal perangkat (mode, kehati-hatian, panel). Setiap perubahan juga didorong ke PanelService.
class SettingsController extends ChangeNotifier {
  static const _key = 'local_settings_v2';
  LocalSettings _s = const LocalSettings();
  bool loaded = false;
  LocalSettings get s => _s;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _s = LocalSettings.decode(p.getString(_key));
    loaded = true;
    notifyListeners();
  }

  Future<void> update(LocalSettings Function(LocalSettings) f) async {
    _s = f(_s);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, _s.encode());
    try {
      await NativeBridge.updateConfig(_s.toNative());
    } catch (_) {}
  }

  /// Panel mengubah mode/kehati-hatian sendiri → sinkronkan ke sini saat aplikasi dibuka.
  Future<void> adoptFromNative(String mode, int confidence) async {
    final m = ResponseMode.parse(mode);
    if (m == _s.mode && confidence == _s.confidence) return;
    final p = await SharedPreferences.getInstance();
    _s = _s.copyWith(
      mode: m,
      confidence: confidenceLevels.contains(confidence)
          ? confidence
          : _s.confidence,
    );
    await p.setString(_key, _s.encode());
    notifyListeners();
  }
}
