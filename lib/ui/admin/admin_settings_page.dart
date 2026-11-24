import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/common.dart';
import '../change_password_page.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AuthController>().status;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Text(
          'Akun admin',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.cyan,
                ),
                title: Text(st?.shownName ?? '-'),
                subtitle: Text('@${st?.username ?? '-'} • Administrator'),
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
                onTap: () => context.read<AuthController>().signOut(),
              ),
            ],
          ),
        ),
        const SectionTitle('Keamanan'),
        const GlassCard(
          child: Text(
            'Peran admin dan status akun diverifikasi di server pada setiap permintaan. Password disimpan oleh Supabase Auth (di-hash). Setelah setup awal, hapus fungsi "bootstrap" dan secret BOOTSTRAP_SECRET.',
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
