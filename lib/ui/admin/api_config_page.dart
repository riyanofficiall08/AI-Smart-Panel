import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin_models.dart';
import '../../services/backend.dart';
import '../../widgets/common.dart';

class ApiConfigPage extends StatefulWidget {
  const ApiConfigPage({super.key});

  @override
  State<ApiConfigPage> createState() => _ApiConfigPageState();
}

class _ApiConfigPageState extends State<ApiConfigPage> {
  GlobalSettings? _s;
  final _key = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _testing = false;
  String? _testMsg;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await Backend.getSettings();
      if (mounted) setState(() => _s = s);
    } on BackendException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _save() async {
    final k = _key.text.trim();
    if (!k.startsWith('sk-') || k.length < 20) {
      showSnack(context, 'API key harus diawali "sk-".', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Backend.setOpenAIKey(k);
      _key.clear();
      if (mounted)
        showSnack(context, 'API key disimpan (terenkripsi di server).');
      await _load();
    } on BackendException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testMsg = null;
    });
    try {
      final r = await Backend.testOpenAI(null);
      setState(() {
        _testOk = r.valid;
        _testMsg = r.message;
      });
    } on BackendException catch (e) {
      setState(() {
        _testOk = false;
        _testMsg = e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: AppBar(title: const Text('API Configuration')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_rounded, color: AppColors.cyan),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Key dikirim sekali lewat HTTPS ke Edge Function, dienkripsi AES-256-GCM di server, dan tidak pernah dikirim balik ke aplikasi mana pun (hanya 4 karakter terakhir yang ditampilkan).',
                      style: TextStyle(
                        color: AppColors.muted,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              borderColor: s == null
                  ? null
                  : (s.openaiConfigured ? AppColors.ok : AppColors.warn),
              child: s == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              s.openaiConfigured
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_amber_rounded,
                              color: s.openaiConfigured
                                  ? AppColors.ok
                                  : AppColors.warn,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              s.openaiConfigured
                                  ? 'API key terpasang'
                                  : 'API key belum diatur',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            if (s.openaiHint != null) 'Key: ${s.openaiHint}',
                            'Sumber: ${switch (s.openaiSource) {
                              'database' => 'diatur dari aplikasi',
                              'env' => 'Edge Function Secrets (OPENAI_API_KEY)',
                              _ => '-',
                            }}',
                            if (s.openaiUpdatedAt != null)
                              'Diperbarui: ${fmtFull(s.openaiUpdatedAt!)}',
                          ].join('\n'),
                          style: const TextStyle(
                            color: AppColors.muted,
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
            const SectionTitle('Ganti / atur API key'),
            TextField(
              controller: _key,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'OpenAI API Key (sk-…)',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GradientButton(
              label: 'Simpan key',
              icon: Icons.save_rounded,
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: const Text('Tes key & model'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_testMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _testMsg!,
                  style: TextStyle(
                    color: _testOk ? AppColors.ok : AppColors.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
