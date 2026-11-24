import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _admin = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<AuthController>().signIn(
      _user.text,
      _pass.text,
      asAdmin: _admin,
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  children: [
                    const LogoMark(size: 78),
                    const SizedBox(height: 18),
                    const Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'AI Smart Panel',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Pengguna'),
                            icon: Icon(Icons.person_rounded),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Admin'),
                            icon: Icon(Icons.admin_panel_settings_rounded),
                          ),
                        ],
                        selected: {_admin},
                        onSelectionChanged: (s) => setState(() {
                          _admin = s.first;
                          _error = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _user,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v ?? '').trim().length < 3
                          ? 'Username minimal 3 karakter'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pass,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Password wajib diisi' : null,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      GlassCard(
                        borderColor: AppColors.danger,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.danger,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        label: _admin ? 'Masuk sebagai Admin' : 'Masuk',
                        icon: Icons.login_rounded,
                        loading: _busy,
                        onPressed: _submit,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Akun dibuat oleh admin. Peran dan masa aktif ditentukan server, bukan aplikasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
