import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/backend.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';

/// [forced] = true: password awal wajib diganti (tanpa tombol kembali).
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.forced = false});
  final bool forced;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    try {
      await Backend.changePassword(_cur.text, _new.text);
      await auth.reauthenticate(_new.text);
      if (!mounted) return;
      showSnack(context, 'Password berhasil diganti.');
      if (!widget.forced && Navigator.canPop(context)) Navigator.pop(context);
    } on BackendException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Gagal mengganti password. Coba login ulang.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.forced,
          title: Text(widget.forced ? 'Ganti password awal' : 'Ganti password'),
          actions: [
            if (widget.forced)
              TextButton(
                onPressed: () => context.read<AuthController>().signOut(),
                child: const Text('Keluar'),
              ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.forced)
                  const GlassCard(
                    borderColor: AppColors.warn,
                    child: Text(
                      'Demi keamanan, password awal yang dibagikan admin wajib diganti sebelum Anda dapat melanjutkan.',
                      style: TextStyle(height: 1.45),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cur,
                  obscureText: _obscure,
                  validator: (v) => (v ?? '').isEmpty ? 'Wajib diisi' : null,
                  decoration: const InputDecoration(
                    labelText: 'Password saat ini',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _new,
                  obscureText: _obscure,
                  validator: (v) =>
                      (v ?? '').length < 8 ? 'Minimal 8 karakter' : null,
                  decoration: InputDecoration(
                    labelText: 'Password baru (min. 8 karakter)',
                    prefixIcon: const Icon(Icons.key_rounded),
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  validator: (v) =>
                      v != _new.text ? 'Konfirmasi tidak sama' : null,
                  decoration: const InputDecoration(
                    labelText: 'Ulangi password baru',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                const SizedBox(height: 22),
                GradientButton(
                  label: 'Simpan password',
                  icon: Icons.save_rounded,
                  loading: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
