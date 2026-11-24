import 'package:flutter/services.dart';

/// Jembatan ke Kotlin (MainActivity + PanelService). Nama channel & method HARUS sama dengan MainActivity.kt.
class NativeBridge {
  static const _ch = MethodChannel('com.aismartpanel/native');

  static Future<({bool overlay, bool running, bool accessibility})>
  status() async {
    final m = await _ch.invokeMapMethod<String, dynamic>('status') ?? const {};
    return (
      overlay: m['overlay'] == true,
      running: m['running'] == true,
      accessibility: m['accessibility'] == true,
    );
  }

  static Future<void> openOverlaySettings() =>
      _ch.invokeMethod('openOverlaySettings');
  static Future<void> openAccessibilitySettings() =>
      _ch.invokeMethod('openAccessibilitySettings');
  static Future<void> updateConfig(Map<String, dynamic> cfg) =>
      _ch.invokeMethod('updateConfig', cfg);
  static Future<void> stopPanel() => _ch.invokeMethod('stopPanel');
  static Future<void> moveToBack() => _ch.invokeMethod('moveToBack');

  /// true = panel berjalan; false = pengguna menolak perekaman layar.
  /// Melempar PlatformException(code: 'overlay_permission') bila izin overlay belum ada.
  static Future<bool> startPanel(Map<String, dynamic> cfg) async =>
      (await _ch.invokeMethod<bool>('startPanel', cfg)) ?? false;

  static Future<Map<String, dynamic>> readNativeState() async =>
      Map<String, dynamic>.from(
        await _ch.invokeMapMethod<String, dynamic>('readNativeState') ??
            const {},
      );
}
