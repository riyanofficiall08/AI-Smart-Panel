import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/history_item.dart';
import '../../state/auth_controller.dart';
import '../../state/history_controller.dart';
import '../../widgets/common.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<HistoryController>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HistoryController>();
    final q = _q.trim().toLowerCase();
    final items = h.items
        .where(
          (e) =>
              q.isEmpty ||
              e.questionText.toLowerCase().contains(q) ||
              e.answer.toLowerCase().contains(q) ||
              e.explanation.toLowerCase().contains(q),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Riwayat',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              if (h.items.isNotEmpty)
                IconButton(
                  tooltip: 'Hapus semua',
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    color: AppColors.muted,
                  ),
                  onPressed: () async {
                    final uid = context.read<AuthController>().status?.id;
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Hapus semua riwayat?'),
                        content: const Text(
                          'Riwayat analisis Anda akan dihapus permanen.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && uid != null && context.mounted)
                      await context.read<HistoryController>().clear(uid);
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Cari soal atau jawaban…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<HistoryController>().load(),
            child: h.loading && h.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 90),
                      Icon(
                        h.error != null
                            ? Icons.cloud_off_rounded
                            : Icons.history_toggle_off_rounded,
                        size: 48,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          h.error ??
                              (h.items.isEmpty
                                  ? 'Belum ada riwayat'
                                  : 'Tidak ditemukan'),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _Tile(item: items[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});
  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final title = item.questionText.trim().isEmpty
        ? item.answer
        : item.questionText;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(.25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      onDismissed: (_) => context.read<HistoryController>().remove(item.id),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          onTap: () => _detail(context),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ellipsize(title, 110),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Jawaban: ${ellipsize(item.answer, 60)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.cyan, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '${fmtTime(item.createdAt)} • ${item.typeLabel} • ${item.mode.label} • ${item.confidencePref}%',
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _detail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        maxChildSize: .96,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${fmtFull(item.createdAt)} • ${item.typeLabel} • Mode ${item.mode.label}${item.aiConfidence != null ? ' • perkiraan AI ${item.aiConfidence}%' : ''}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (item.questionText.trim().isNotEmpty) ...[
              const Text(
                'Soal / konten',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.questionText, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 16),
            ],
            const Text(
              'Jawaban',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cyan.withOpacity(.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cyan.withOpacity(.35)),
              ),
              child: Text(
                item.answer,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            if (item.explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Penjelasan',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(item.explanation, style: const TextStyle(height: 1.55)),
            ],
            if (item.caveats.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Catatan: ${item.caveats}',
                style: const TextStyle(
                  color: AppColors.warn,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: item.answer));
                      if (c.mounted) showSnack(c, 'Jawaban disalin');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Salin jawaban'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: item.fullText),
                      );
                      if (c.mounted)
                        showSnack(c, 'Jawaban + penjelasan disalin');
                    },
                    icon: const Icon(Icons.article_rounded, size: 18),
                    label: const Text('Salin semua'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
