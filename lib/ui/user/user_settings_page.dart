import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/native_bridge.dart';
import '../../state/auth_controller.dart';
import '../../state/history_controller.dart';
import '../../state/panel_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/selectors.dart';
import '../change_password_page.dart';

class UserSettingsPage extends StatelessWidget {
  const UserSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final panel = context.watch<PanelController>();
    final st = context.watch<AuthController>().status;
    final s = ctrl.s;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Text(
          'Pengaturan',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SectionTitle('Akun'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.person_rounded,
                  color: AppColors.cyan,
                ),
                title: Text(st?.shownName ?? '-'),
                subtitle: Text('@${st?.username ?? '-'}'),
              ),
              ListTile(
                leading: const Icon(Icons.key_rounded, color: AppColors.cyan),
                title: const Text('Ganti password'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                ),
                title: const Text('Keluar'),
                onTap: () async {
                  await panel.stop();
                  if (!context.mounted) return;
                  context.read<HistoryController>().reset();
                  await context.read<AuthController>().signOut();
                },
              ),
            ],
          ),
        ),
        const SectionTitle('Respons AI'),
        const ModeSelector(),
        const SizedBox(height: 4),
        const GlassCard(child: ConfidenceSelector()),
        const SectionTitle('Panel melayang'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Handle saat diminimalkan'),
                subtitle: const Text(
                  'Matikan agar tombol 👁 menyembunyikan panel sepenuhnya (buka lewat notifikasi/Volume+)',
                ),
                value: s.showHandle,
                onChanged: (v) => ctrl.update((x) => x.copyWith(showHandle: v)),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Analisis otomatis'),
                subtitle: const Text(
                  'Langsung kirim ke AI setelah screenshot (pratinjau tetap tampil)',
                ),
                value: s.autoAnalyze,
                onChanged: (v) =>
                    ctrl.update((x) => x.copyWith(autoAnalyze: v)),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Pintasan tombol Volume +'),
                subtitle: Text(
                  panel.accessibility
                      ? 'Aktif saat panel berjalan. Tidak universal; bergantung perangkat.'
                      : 'Butuh layanan aksesibilitas "AI Smart Panel" aktif.',
                ),
                value: s.volumeShortcut,
                onChanged: (v) async {
                  await ctrl.update((x) => x.copyWith(volumeShortcut: v));
                  if (v && !panel.accessibility && context.mounted) {
                    showSnack(
                      context,
                      'Aktifkan layanan "AI Smart Panel" di pengaturan aksesibilitas.',
                    );
                    await NativeBridge.openAccessibilitySettings();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    const Text('Transparansi'),
                    Expanded(
                      child: Slider(
                        value: s.opacity,
                        min: 0.5,
                        max: 1.0,
                        onChanged: (v) =>
                            ctrl.update((x) => x.copyWith(opacity: v)),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Reset ukuran & posisi panel'),
                subtitle: const Text(
                  'Ukuran diubah dengan menyeret ◢ di pojok panel',
                ),
                trailing: const Icon(Icons.restart_alt_rounded),
                onTap: () async {
                  await panel.resetGeometry();
                  if (context.mounted)
                    showSnack(
                      context,
                      'Direset. Mulai ulang panel untuk menerapkan.',
                    );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Izin "Tampil di atas aplikasi lain"'),
                subtitle: Text(
                  panel.overlay ? 'Sudah diizinkan' : 'Belum diizinkan',
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: NativeBridge.openOverlaySettings,
              ),
            ],
          ),
        ),
        const SectionTitle('Tentang'),
        const GlassCard(
          child: Text(
            'AI Smart Panel v1.0.0\nPilihan 100%/80%/60% hanya mengatur tingkat kehati-hatian analisis, bukan menjamin kebenaran. Hormati batasan screenshot Android dan aturan ujian yang berlaku.',
            style: TextStyle(
              color: AppColors.muted,
              height: 1.5,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
