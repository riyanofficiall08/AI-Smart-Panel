const _bulan = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String fmtTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_bulan[d.month - 1]} ${two(d.hour)}:${two(d.minute)}';
}

String ellipsize(String s, int max) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= max ? t : '${t.substring(0, max - 1)}…';
}

String fmtFull(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_bulan[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}
