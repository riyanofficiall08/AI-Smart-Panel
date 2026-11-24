import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin_models.dart';
import '../../services/backend.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/common.dart';

class LicenseManagementPage extends StatefulWidget {
  const LicenseManagementPage({super.key});

  @override
  State<LicenseManagementPage> createState() => _LicenseManagementPageState();
}

class _LicenseManagementPageState extends State<LicenseManagementPage> {
  List<LicenseRow> _rows = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = await Backend.licenses();
    } on BackendException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _generate() async {
    var days = 30;
    var count = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: const Text('Buat token lisensi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masa aktif',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              DurationPicker(
                value: days,
                onChanged: (v) => setSt(() => days = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Jumlah'),
                  Expanded(
                    child: Slider(
                      value: count.toDouble(),
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: '$count',
                      onChanged: (v) => setSt(() => count = v.round()),
                    ),
                  ),
                  Text('$count'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Buat'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final tokens = await Backend.issueTokens(days, count);
      if (!mounted) return;
      await showTokenDialog(
        context,
        title: '$count token ($days hari)',
        tokens: tokens,
        extra: 'Bagikan ke pengguna; mereka memasukkannya di Beranda → "Masukkan token".',
      );
      _load();
    } on BackendException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _revoke(LicenseRow r) async {
    if (!await confirm(
      context,
      'Cabut token …${r.hint}?',
      'Token yang belum dipakai tidak akan bisa diaktifkan lagi.',
      ok: 'Cabut',
    ))
      return;
    try {
      await Backend.revokeLicense(r.id);
      _load();
    } on BackendException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows
        .where((r) => _filter == 'all' || r.status == _filter)
        .toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Token'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Manajemen lisensi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final f in const [
                  ('all', 'Semua'),
                  ('unused', 'Belum dipakai'),
                  ('redeemed', 'Terpakai'),
                  ('revoked', 'Dicabut'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) => setState(() => _filter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading && _rows.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            _error ?? 'Belum ada token.',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final color = switch (r.status) {
                          'unused' => AppColors.cyan,
                          'redeemed' => AppColors.ok,
                          _ => AppColors.danger,
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(Icons.vpn_key_rounded, color: color),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AISP-••••-${r.hint}  •  ${r.days == 365 ? '1 tahun' : '${r.days} hari'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${r.statusLabel}${r.username != null ? ' oleh @${r.username}' : ''} • ${r.createdAt != null ? fmtTime(r.createdAt!) : ''}',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (r.status == 'unused')
                                  IconButton(
                                    tooltip: 'Cabut',
                                    icon: const Icon(
                                      Icons.block_rounded,
                                      color: AppColors.danger,
                                    ),
                                    onPressed: () => _revoke(r),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
