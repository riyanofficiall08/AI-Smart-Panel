import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/theme.dart';
import 'state/auth_controller.dart';
import 'state/history_controller.dart';
import 'state/panel_controller.dart';
import 'state/settings_controller.dart';
import 'ui/admin/admin_shell.dart';
import 'ui/change_password_page.dart';
import 'ui/login_page.dart';
import 'ui/onboarding_page.dart';
import 'ui/splash_page.dart';
import 'ui/user/user_shell.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.configured) {
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.anonKey);
  }
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final SettingsController _settings = SettingsController();
  final AuthController _auth = AuthController();
  final HistoryController _history = HistoryController();
  late final PanelController _panel = PanelController(_settings);
  bool _minSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _minSplash = false);
    });
    _boot();
  }

  Future<void> _boot() async {
    await _settings.init();
    if (!Env.configured) return;
    _panel.init();
    await _panel.syncFromNative();
    await _auth.init();
    await _panel.pushSession();
    await _panel.refresh();
  }

  /// Saat kembali ke aplikasi: sinkronkan token dari native, status lisensi, status panel.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        Env.configured &&
        _auth.status != null) {
      () async {
        await _panel.syncFromNative();
        await _panel.refresh();
        await _auth.refreshStatus();
      }();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.dispose();
    _auth.dispose();
    _history.dispose();
    _panel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settings),
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _history),
        ChangeNotifierProvider.value(value: _panel),
      ],
      child: MaterialApp(
        title: 'AI Smart Panel',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Env.configured
            ? _Gate(minSplash: _minSplash)
            : const _ConfigMissing(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.minSplash});
  final bool minSplash;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final auth = context.watch<AuthController>();

    if (minSplash || !settings.loaded || auth.booting)
      return const SplashPage();
    if (!settings.s.onboarded) return const OnboardingPage();

    final st = auth.status;
    if (st == null) {
      if (auth.hasSession && auth.bootError != null) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 14),
                  Text(auth.bootError!, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  GradientButton(
                    label: 'Coba lagi',
                    icon: Icons.refresh_rounded,
                    onPressed: auth.retry,
                  ),
                  TextButton(
                    onPressed: auth.signOut,
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const LoginPage();
    }
    if (st.mustChangePassword) return const ChangePasswordPage(forced: true);
    return st.isAdmin ? const AdminShell() : const UserShell();
  }
}

class _ConfigMissing extends StatelessWidget {
  const _ConfigMissing();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Konfigurasi Supabase belum diisi.\n\nBuild ulang dengan:\nflutter build apk --release --dart-define-from-file=config/dart_defines.json',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5),
        ),
      ),
    ),
  );
}
