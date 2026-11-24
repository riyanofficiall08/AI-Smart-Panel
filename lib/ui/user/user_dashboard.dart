import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/account_status.dart';
import '../../services/backend.dart';
import '../../services/native_bridge.dart';
import '../../state/auth_controller.dart';
import '../../state/panel_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/selectors.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  bool _starting = false;

  Future<void> _toggle(AccountStatus st) async {
    final panel = context.read<PanelController>();
    if (panel.running) {
      await panel.stop();
      return;
    }
    // Validasi ulang ke server sebelum panel dijalankan (masa aktif / status akun)
    await context.read<AuthController>().refreshStatus();
    if (!mounted) return;
    final fresh = context.read<AuthController>().status ?? st;
    if (!fresh.canUseAi) {
      showSnack(context, _blockedReason(fresh), error: true);
      return;
    }
    setState(() => _starting = true);
    final err = await panel.start();
    if (!mounted) return;
    setState(() => _starting = false);
    if (err != null) showSnack(context, err, error: true);
  }

  String _blockedReason(AccountStatus s) => switch (s.licenseState) {
    'expired' => 'Masa aktif habis. Masukkan token baru atau hubungi admin.',
    'no_license' => 'Akun belum punya masa aktif. Masukkan token lisensi.',
    'disabled' => 'Akun dinonaktifkan. Hubungi admin.',
    _ => 'Akun belum dapat memakai AI.',
  };

  Future<void> _redeem() async {
    final c = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan token lisensi'),
        content: TextField(
          controller: c,
          autofocus: true,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'AISP-XXXXX-XXXXX-XXXXX-XXXXX',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
    c.dispose();
    if (token == null || token.trim().isEmpty || !mounted) return;
    final auth = context.read<AuthController>();
    try {
      final st = await Backend.redeem(token);
      auth.setStatus(st);
      if (mounted)
        showSnack(
          context,
          'Token berhasil diaktifkan. Masa aktif diperpanjang.',
        );
    } on BackendException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AuthController>().status;
    final panel = context.watch<PanelController>();
    final settings = context.watch<SettingsController>().s;
    if (st == null) return const SizedBox.shrink();

    final stateColor = switch (st.licenseState) {
      'active' => AppColors.ok,
      'expired' || 'disabled' => AppColors.danger,
      _ => AppColors.warn,
    };
    final quotaFrac = st.dailyLimit == 0
        ? 1.0
        : (st.usedToday / st.dailyLimit).clamp(0.0, 1.0);
    final lifeFrac = st.tokenDays == null
        ? (st.daysLeft / 30).clamp(0.0, 1.0)
        : (st.daysLeft / st.tokenDays!).clamp(0.0, 1.0);

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<AuthController>().refreshStatus();
        await panel.refresh();
      },
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
                    Text(
                      'Halo, ${st.shownName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Asisten belajar melayang',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassCard(
            borderColor: stateColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.cyan,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Lisensi & masa aktif',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        st.stateLabel,
                        style: TextStyle(
                          color: stateColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  st.expiresAt == null
                      ? 'Belum ada masa aktif'
                      : 'Berlaku hingga ${fmtFull(st.expiresAt!)}',
                  style: const TextStyle(fontSize: 14.5),
                ),
                const SizedBox(height: 4),
                Text(
                  st.licenseState == 'active'
                      ? 'Sisa ${st.daysLeft} hari'
                      : _blockedReason(st),
                  style: TextStyle(color: stateColor, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: lifeFrac,
                    minHeight: 7,
                    backgroundColor: AppColors.surface2,
                    color: stateColor,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  st.tokenHint == null
                      ? 'Token: belum ada'
                      : 'Token terakhir: AISP-••••-${st.tokenHint} (${st.tokenDays ?? '-'} hari • ${st.tokenStatus == 'redeemed' ? 'aktif dipakai' : st.tokenStatus})',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pemakaian hari ini: ${st.usedToday} / ${st.dailyLimit}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: quotaFrac,
                    minHeight: 7,
                    backgroundColor: AppColors.surface2,
                    color: quotaFrac > .9 ? AppColors.warn : AppColors.cyan,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _redeem,
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: const Text('Masukkan / perpanjang dengan token'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            borderColor: panel.running ? AppColors.ok : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: panel.running ? AppColors.ok : AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      panel.running
                          ? 'Panel sedang aktif'
                          : 'Panel belum aktif',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  panel.running
                      ? 'Panel melayang di atas aplikasi lain. Tombol — mengecilkan jadi handle bulat, 👁 menyembunyikan penuh (buka lewat notifikasi${settings.volumeShortcut ? ' atau Volume+' : ''}).'
                      : 'Tekan mulai, beri izin perekaman layar (pilih "Seluruh layar"), lalu buka halaman soal di browser.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.45,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: panel.running
                      ? 'Hentikan Panel'
                      : 'Mulai Panel Melayang',
                  icon: panel.running
                      ? Icons.stop_circle_outlined
                      : Icons.play_arrow_rounded,
                  danger: panel.running,
                  loading: _starting,
                  onPressed: () => _toggle(st),
                ),
              ],
            ),
          ),
          const SectionTitle('Status sistem'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Column(
              children: [
                _Row(
                  Icons.layers_rounded,
                  'Tampil di atas aplikasi lain',
                  panel.overlay,
                  panel.overlay ? 'Diizinkan' : 'Belum diizinkan',
                  action: panel.overlay ? null : 'Atur',
                  onAction: NativeBridge.openOverlaySettings,
                ),
                _Row(
                  Icons.volume_up_rounded,
                  'Pintasan Volume+',
                  panel.accessibility && settings.volumeShortcut,
                  !settings.volumeShortcut
                      ? 'Dimatikan (opsional)'
                      : (panel.accessibility
                            ? 'Aktif'
                            : 'Layanan aksesibilitas belum aktif'),
                  action: (settings.volumeShortcut && !panel.accessibility)
                      ? 'Aktifkan'
                      : null,
                  onAction: NativeBridge.openAccessibilitySettings,
                  last: true,
                ),
              ],
            ),
          ),
          const SectionTitle('Mode respons'),
          const ModeSelector(),
          const SectionTitle('Tingkat kehati-hatian'),
          const GlassCard(child: ConfidenceSelector()),
          const SectionTitle('Catatan penting'),
          const GlassCard(
            child: Text(
              'Gunakan hanya untuk belajar, latihan, dan simulasi yang diizinkan; patuhi aturan ujian. Screenshot dikirim ke server lalu OpenAI hanya saat Anda menekan Analisis AI. Layar dengan proteksi screenshot akan tampil hitam. Jawaban AI dapat keliru.',
              style: TextStyle(
                color: AppColors.muted,
                height: 1.5,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
    this.icon,
    this.title,
    this.ok,
    this.text, {
    this.action,
    this.onAction,
    this.last = false,
  });
  final IconData icon;
  final String title, text;
  final bool ok, last;
  final String? action;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.ok : AppColors.muted;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(text, style: TextStyle(fontSize: 12, color: color)),
                  ],
                ),
              ),
              if (action != null)
                TextButton(onPressed: onAction, child: Text(action!)),
            ],
          ),
        ),
        if (!last) const Divider(height: 1, color: Color(0x14FFFFFF)),
      ],
    );
  }
}
