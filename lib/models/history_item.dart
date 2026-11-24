import 'local_settings.dart';

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.createdAt,
    required this.mode,
    required this.confidencePref,
    required this.questionText,
    required this.questionType,
    required this.answer,
    required this.explanation,
    required this.caveats,
    required this.aiConfidence,
    required this.model,
  });
  final String id, questionText, questionType, answer, explanation, caveats;
  final DateTime createdAt;
  final ResponseMode mode;
  final int confidencePref;
  final int? aiConfidence;
  final String? model;

  String get typeLabel => switch (questionType) {
    'pilihan_ganda' => 'Pilihan ganda',
    'esai' => 'Esai',
    'isian' => 'Isian',
    _ => 'Lainnya',
  };

  String get fullText => explanation.trim().isEmpty
      ? answer
      : '$answer\n\nPenjelasan:\n$explanation';

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
    id: j['id'] as String,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    mode: ResponseMode.parse(j['mode'] as String?),
    confidencePref: (j['confidence_pref'] as num?)?.toInt() ?? 80,
    questionText: j['question_text'] as String? ?? '',
    questionType: j['question_type'] as String? ?? 'lainnya',
    answer: j['answer'] as String? ?? '',
    explanation: j['explanation'] as String? ?? '',
    caveats: j['caveats'] as String? ?? '',
    aiConfidence: (j['ai_confidence'] as num?)?.toInt(),
    model: j['model'] as String?,
  );
}
