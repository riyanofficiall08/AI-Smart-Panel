import 'dart:convert';

enum ResponseMode {
  fast('Cepat', 'Jawaban singkat & langsung'),
  accurate('Akurat', 'Analisis mendalam, lebih teliti'),
  study('Belajar', 'Jawaban + langkah penyelesaian');

  const ResponseMode(this.label, this.description);
  final String label;
  final String description;

  static ResponseMode parse(String? v) => ResponseMode.values.firstWhere(
    (m) => m.name == v,
    orElse: () => ResponseMode.accurate,
  );
}

/// Preferensi tingkat kehati-hatian analisis (bukan jaminan kebenaran).
const confidenceLevels = [100, 80, 60];

String confidenceHint(int c) => switch (c) {
  100 => 'Sangat hati-hati: periksa ulang, tidak menebak, jujur bila ragu.',
  80 => 'Seimbang: periksa sekali dan sebutkan asumsi penting.',
  _ => 'Ringan: lebih cepat, boleh berasumsi wajar.',
};

class LocalSettings {
  const LocalSettings({
    this.mode = ResponseMode.accurate,
    this.confidence = 80,
    this.showHandle = true,
    this.autoAnalyze = false,
    this.volumeShortcut = false,
    this.opacity = 0.94,
    this.onboarded = false,
  });

  final ResponseMode mode;
  final int confidence;
  final bool showHandle;
  final bool autoAnalyze;
  final bool volumeShortcut;
  final double opacity;
  final bool onboarded;

  LocalSettings copyWith({
    ResponseMode? mode,
    int? confidence,
    bool? showHandle,
    bool? autoAnalyze,
    bool? volumeShortcut,
    double? opacity,
    bool? onboarded,
  }) => LocalSettings(
    mode: mode ?? this.mode,
    confidence: confidence ?? this.confidence,
    showHandle: showHandle ?? this.showHandle,
    autoAnalyze: autoAnalyze ?? this.autoAnalyze,
    volumeShortcut: volumeShortcut ?? this.volumeShortcut,
    opacity: opacity ?? this.opacity,
    onboarded: onboarded ?? this.onboarded,
  );

  /// Dikirim ke Kotlin (PanelService).
  Map<String, dynamic> toNative() => {
    'mode': mode.name,
    'confidence': confidence,
    'showHandle': showHandle,
    'autoAnalyze': autoAnalyze,
    'volumeShortcut': volumeShortcut,
    'opacity': opacity,
  };

  String encode() => jsonEncode({...toNative(), 'onboarded': onboarded});

  factory LocalSettings.decode(String? raw) {
    if (raw == null) return const LocalSettings();
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final c = (j['confidence'] as num?)?.toInt() ?? 80;
      return LocalSettings(
        mode: ResponseMode.parse(j['mode'] as String?),
        confidence: confidenceLevels.contains(c) ? c : 80,
        showHandle: j['showHandle'] as bool? ?? true,
        autoAnalyze: j['autoAnalyze'] as bool? ?? false,
        volumeShortcut: j['volumeShortcut'] as bool? ?? false,
        opacity: ((j['opacity'] as num?)?.toDouble() ?? 0.94)
            .clamp(0.5, 1.0)
            .toDouble(),
        onboarded: j['onboarded'] as bool? ?? false,
      );
    } catch (_) {
      return const LocalSettings();
    }
  }
}
