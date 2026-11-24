import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/backend.dart';
import '../../widgets/common.dart';

class ModelConfigPage extends StatefulWidget {
  const ModelConfigPage({super.key});

  @override
  State<ModelConfigPage> createState() => _ModelConfigPageState();
}

class _ModelConfigPageState extends State<ModelConfigPage> {
  final _fast = TextEditingController();
  final _accurate = TextEditingController();
  final _study = TextEditingController();
  final _daily = TextEditingController();
  final _rate = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  static const _suggestions = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4.1',
    'gpt-4.1-mini',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_fast, _accurate, _study, _daily, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await Backend.getSettings();
      _fast.text = s.fast;
      _accurate.text = s.accurate;
      _study.text = s.study;
      _daily.text = '${s.dailyLimit}';
      _rate.text = '${s.rateLimit}';
    } on BackendException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final daily = int.tryParse(_daily.text.trim());
    final rate = int.tryParse(_rate.text.trim());
    if (daily == null || rate == null) {
      showSnack(context, 'Batas harian & rate limit harus angka.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Backend.setSettings({
        'models': {
          'fast': _fast.text.trim(),
          'accurate': _accurate.text.trim(),
          'study': _study.text.trim(),
        },
        'daily_limit': daily,
        'rate_limit_per_minute': rate,
      });
      if (mounted)
        showSnack(context, 'Tersimpan. Berlaku langsung tanpa update APK.');
    } on BackendException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _model(String label, TextEditingController c, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: c,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final m in _suggestions)
                  ActionChip(
                    label: Text(m, style: const TextStyle(fontSize: 11.5)),
                    onPressed: () => setState(() => c.text = m),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Configuration')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Pilih model OpenAI Vision untuk tiap mode. Nama harus sesuai model yang tersedia di akun OpenAI Anda (gunakan "Tes key & model" di API Configuration).',
                    style: TextStyle(
                      color: AppColors.muted,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _model('Mode Cepat', _fast, Icons.bolt_rounded),
                  _model('Mode Akurat', _accurate, Icons.track_changes_rounded),
                  _model('Mode Belajar', _study, Icons.school_rounded),
                  const SectionTitle('Pembatasan penggunaan'),
                  TextField(
                    controller: _daily,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Batas harian default per pengguna',
                      prefixIcon: Icon(Icons.today_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _rate,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Maks. permintaan per menit per pengguna',
                      prefixIcon: Icon(Icons.speed_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Batas per pengguna dapat diganti individual di Manajemen Pengguna → Edit.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 22),
                  GradientButton(
                    label: 'Simpan',
                    icon: Icons.save_rounded,
                    loading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
      ),
    );
  }
}
