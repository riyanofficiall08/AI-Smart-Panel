import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/backend.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/common.dart';

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  int _days = 30;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _name.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _generatePassword() {
    const a = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    setState(() {
      _pass.text = List.generate(12, (_) => a[r.nextInt(a.length)]).join();
      _obscure = false;
    });
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final r = await Backend.createUser(
        username: _user.text.trim().toLowerCase(),
        password: _pass.text,
        days: _days,
        displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (!mounted) return;
      await showTokenDialog(
        context,
        title: 'Akun berhasil dibuat',
        tokens: [r.token],
        extra:
            'Username: ${r.user.username}\nPassword: ${_pass.text}\nMasa aktif: $_days hari\n\nBagikan username, password, dan token ke pengguna.',
      );
      if (mounted) Navigator.pop(context);
    } on BackendException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat pengguna')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _user,
                autocorrect: false,
                validator: (v) =>
                    RegExp(r'^[a-z0-9_.]{3,32}$')
                        .hasMatch((v ?? '').trim().toLowerCase())
                    ? null
                    : '3-32 karakter: huruf, angka, titik, _',
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nama tampilan (opsional)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pass,
                obscureText: _obscure,
                validator: (v) =>
                    (v ?? '').length < 8 ? 'Minimal 8 karakter' : null,
                decoration: InputDecoration(
                  labelText: 'Password awal',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Acak',
                        icon: const Icon(Icons.casino_rounded),
                        onPressed: _generatePassword,
                      ),
                      IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Masa aktif token lisensi'),
              DurationPicker(
                value: _days,
                onChanged: (d) => setState(() => _days = d),
              ),
              const SizedBox(height: 10),
              const Text(
                'Token AISP-… dibuat acak (CSPRNG), disimpan sebagai hash, dan hanya tampil sekali.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Buat akun & token',
                icon: Icons.person_add_alt_1_rounded,
                loading: _busy,
                onPressed: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
