import 'package:flutter/material.dart';

import 'history_page.dart';
import 'user_dashboard.dart';
import 'user_settings_page.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [UserDashboard(), HistoryPage(), UserSettingsPage()];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
