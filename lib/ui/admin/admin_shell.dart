import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'admin_settings_page.dart';
import 'config_page.dart';
import 'license_management.dart';
import 'user_management.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  final _dashKey = GlobalKey<AdminDashboardState>();

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminDashboard(key: _dashKey, onGoUsers: () => setState(() => _tab = 1)),
      const UserManagementPage(),
      const LicenseManagementPage(),
      const ConfigPage(),
      const AdminSettingsPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 0) _dashKey.currentState?.load();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_rounded),
            label: 'Pengguna',
          ),
          NavigationDestination(
            icon: Icon(Icons.vpn_key_rounded),
            label: 'Lisensi',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_suggest_rounded),
            label: 'Konfigurasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}
