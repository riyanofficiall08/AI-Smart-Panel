import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import 'common.dart';

const licenseDurations = [1, 7, 30, 90, 365];

class DurationPicker extends StatelessWidget {
  const DurationPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final d in licenseDurations)
        ChoiceChip(
          label: Text(d == 365 ? '1 tahun' : '$d hari'),
          selected: value == d,
          selectedColor: AppColors.cyan.withOpacity(.25),
          onSelected: (_) => onChanged(d),
        ),
    ],
  );
}

/// Menampilkan token hasil generate. Token HANYA tampil sekali (server hanya menyimpan hash).
Future<void> showTokenDialog(
  BuildContext context, {
  required String title,
  required List<String> tokens,
  String? extra,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (extra != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  extra,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            for (final t in tokens)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        t,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.cyan,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: t));
                        if (ctx.mounted) showSnack(ctx, 'Token disalin');
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              '⚠ Token ini hanya ditampilkan SATU KALI. Salin dan simpan sekarang.',
              style: TextStyle(
                color: AppColors.warn,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (tokens.length > 1)
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: tokens.join('\n')));
              if (ctx.mounted) showSnack(ctx, 'Semua token disalin');
            },
            child: const Text('Salin semua'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Selesai'),
        ),
      ],
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String ok = 'Ya',
}) async =>
    (await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
        ],
      ),
    )) ==
    true;

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.cyan,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
      ],
    ),
  );
}
