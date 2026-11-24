import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin_models.dart';
import '../../services/backend.dart';
import '../../state/auth_controller.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/common.dart';
import 'create_user_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.onGoUsers});
  final VoidCallback onGoUsers;

  @override
  State<AdminDashboard> createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> {
  AdminStats? _stats;
  List<UsageLog> _logs = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([
        Backend.stats(),
        Backend.usageLogs(limit: 8),
      ]);
      _stats = r[0] as AdminStats;
      _logs = r[1] as List<UsageLog>;
    } on BackendException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().status;
    final s = _stats;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              const LogoMark(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Masuk sebagai @${me?.username ?? '-'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            GlassCard(borderColor: AppColors.danger, child: Text(_error!)),
          if (_loading && s == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (s != null) ...[
            if (!s.openaiConfigured)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  borderColor: AppColors.warn,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warn),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'OpenAI API Key belum diatur. Buka Konfigurasi → API Configuration agar AI dapat dipakai.',
                          style: TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                StatCard(
                  icon: Icons.people_alt_rounded,
                  label: 'Total pengguna',
                  value: '${s.totalUsers}',
                ),
                StatCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Akun aktif',
                  value: '${s.activeUsers}',
                  color: AppColors.ok,
                ),
                StatCard(
                  icon: Icons.hourglass_bottom_rounded,
                  label: 'Kedaluwarsa / tanpa lisensi',
                  value: '${s.expiredUsers}',
                  color: AppColors.warn,
                ),
                StatCard(
                  icon: Icons.block_rounded,
                  label: 'Dinonaktifkan',
                  value: '${s.disabledUsers}',
                  color: AppColors.danger,
                ),
                StatCard(
                  icon: Icons.bolt_rounded,
                  label: 'Analisis hari ini',
                  value: '${s.requestsToday}',
                  color: AppColors.violet,
                ),
                StatCard(
                  icon: Icons.query_stats_rounded,
                  label: 'Analisis 7 hari',
                  value: '${s.requests7d}',
                  color: AppColors.violet,
                ),
                StatCard(
                  icon: Icons.vpn_key_rounded,
                  label: 'Token belum dipakai',
                  value: '${s.unusedTokens}',
                ),
                StatCard(
                  icon: Icons.error_outline_rounded,
                  label: 'Error hari ini',
                  value: '${s.errorsToday}',
                  color: s.errorsToday > 0 ? AppColors.danger : AppColors.muted,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: 'Buat pengguna',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateUserPage()),
                    );
                    load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: widget.onGoUsers,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 16,
                  ),
                ),
                child: const Text('Kelola'),
              ),
            ],
          ),
          const SectionTitle('Aktivitas terbaru'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _logs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Belum ada aktivitas.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : Column(children: [for (final l in _logs) LogTile(log: l)]),
          ),
        ],
      ),
    );
  }
}

class LogTile extends StatelessWidget {
  const LogTile({super.key, required this.log});
  final UsageLog log;

  @override
  Widget build(BuildContext context) {
    final color = switch (log.status) {
      'ok' => AppColors.ok,
      'quota' || 'rate_limited' => AppColors.warn,
      _ => AppColors.danger,
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        log.status == 'ok' ? Icons.check_circle_rounded : Icons.error_rounded,
        color: color,
        size: 20,
      ),
      title: Text(
        '${log.username ?? '—'} • ${log.action}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (log.createdAt != null) fmtTime(log.createdAt!),
          log.status,
          if (log.mode != null) log.mode!,
          if (log.model != null) log.model!,
          if (log.latencyMs != null) '${log.latencyMs} ms',
          if (log.detail != null) log.detail!,
        ].join(' • '),
        maxLines: 2,
        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
      ),
    );
  }
}
