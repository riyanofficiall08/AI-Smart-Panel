import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/native_bridge.dart';
import '../state/settings_controller.dart';
import '../widgets/common.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pc = PageController();
  int _i = 0;
  bool _notifOk = false;
  static const _total = 4;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() => context.read<SettingsController>().update(
    (s) => s.copyWith(onboarded: true),
  );

  Future<void> _next() async {
    if (_i < _total - 1) {
      await _pc.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      await _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _Slide(
        icon: Icons.auto_awesome_rounded,
        title: 'AI Smart Panel',
        body: 'Asisten belajar berbentuk panel melayang. Buka halaman latihan di browser, ambil screenshot, dan dapatkan analisis beserta penjelasan yang mudah dipahami.\n\nDirancang untuk belajar, latihan, dan simulasi yang diizinkan. Patuhi aturan sekolah, kampus, atau penyelenggara ujian.',
      ),
      _Slide(
        icon: Icons.layers_rounded,
        title: 'Tampil di atas aplikasi lain',
        body: 'Panel berjalan sebagai layanan Android sendiri sehingga tetap tampil di atas Chrome atau aplikasi lain, walau aplikasi ini ditutup atau Anda menekan Home.\n\nAndroid mewajibkan Anda memberi izin ini secara manual.',
        actionLabel: 'Buka pengaturan izin',
        onAction: () => NativeBridge.openOverlaySettings(),
      ),
      _Slide(
        icon: Icons.screenshot_monitor_rounded,
        title: 'Screenshot & notifikasi',
        body: 'Saat panel dimulai, Android menampilkan dialog perekaman layar. Pilih "Seluruh layar" agar browser dapat ditangkap. Gambar hanya diambil saat Anda menekan Screenshot.\n\nLayar yang diproteksi aplikasi (FLAG_SECURE) akan tampil hitam. Notifikasi dibutuhkan agar layanan tetap berjalan.',
        actionLabel: _notifOk ? 'Notifikasi aktif ✓' : 'Izinkan notifikasi',
        onAction: _notifOk
            ? null
            : () async {
                final st = await Permission.notification.request();
                if (mounted) setState(() => _notifOk = st.isGranted);
              },
      ),
      _Slide(
        icon: Icons.volume_up_rounded,
        title: 'Pintasan Volume+ (opsional)',
        body: 'Volume + dapat menampilkan/menyembunyikan panel lewat layanan aksesibilitas yang HANYA membaca tombol Volume+.\n\nKeterbatasan: tidak berfungsi universal — tergantung perangkat/OEM, tidak aktif saat layar terkunci, dan dapat diblokir aplikasi tertentu. Handle bulat tetap tersedia sebagai cara utama.',
        actionLabel: 'Buka pengaturan aksesibilitas',
        onAction: () => NativeBridge.openAccessibilitySettings(),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'Lewati',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (v) => setState(() => _i = v),
                children: pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < _total; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: k == _i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: k == _i ? AppColors.cyan : AppColors.surface2,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: GradientButton(
                label: _i == _total - 1 ? 'Mulai' : 'Lanjut',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
    child: Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.cyan.withOpacity(.4)),
            boxShadow: [
              BoxShadow(
                color: AppColors.violet.withOpacity(.3),
                blurRadius: 36,
              ),
            ],
          ),
          child: Icon(icon, size: 50, color: AppColors.cyan),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            height: 1.55,
            fontSize: 14,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
