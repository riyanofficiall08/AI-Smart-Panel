import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin_models.dart';
import '../../services/backend.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/common.dart';
import 'create_user_page.dart';
import 'usage_logs_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _users = await Backend.listUsers();
    } on BackendException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run(Future<void> Function() job, String ok) async {
    try {
      await job();
      if (mounted) showSnack(context, ok);
      await _load();
    } on BackendException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  List<AdminUser> get _filtered => _users.where((u) {
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty &&
        !u.username.contains(q) &&
        !(u.displayName ?? '').toLowerCase().contains(q))
      return false;
    return _filter == 'all' || u.state == _filter;
  }).toList();

  void _actions(AdminUser u) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: Text(
                '@${u.username}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${u.stateLabel} • hingga ${u.expiresAt == null ? '-' : fmtFull(u.expiresAt!)}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit akun / ganti password'),
              onTap: () {
                Navigator.pop(c);
                _edit(u);
              },
            ),
            ListTile(
              leading: const Icon(Icons.more_time_rounded),
              title: const Text('Perpanjang masa aktif'),
              onTap: () {
                Navigator.pop(c);
                _extend(u);
              },
            ),
            ListTile(
              leading: Icon(
                u.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
              ),
              title: Text(u.isActive ? 'Nonaktifkan akun' : 'Aktifkan akun'),
              onTap: () {
                Navigator.pop(c);
                _run(
                  () => Backend.setActive(u.id, !u.isActive),
                  u.isActive ? 'Akun dinonaktifkan' : 'Akun diaktifkan',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('Riwayat penggunaan'),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UsageLogsPage(userId: u.id, title: '@${u.username}'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Hapus akun',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () async {
                Navigator.pop(c);
                if (await confirm(
                  context,
                  'Hapus @${u.username}?',
                  'Akun, lisensi, dan riwayat analisisnya akan dihapus permanen.',
                  ok: 'Hapus',
                )) {
                  _run(() => Backend.deleteUser(u.id), 'Akun dihapus');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _extend(AdminUser u) async {
    var d = 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: Text('Perpanjang @${u.username}'),
          content: DurationPicker(
            value: d,
            onChanged: (v) => setSt(() => d = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Perpanjang'),
            ),
          ],
        ),
      ),
    );
    if (ok == true)
      _run(() => Backend.extend(u.id, d), 'Masa aktif diperpanjang $d hari');
  }

  Future<void> _edit(AdminUser u) async {
    final name = TextEditingController(text: u.displayName ?? '');
    final username = TextEditingController(text: u.username);
    final pass = TextEditingController();
    final limit = TextEditingController(text: u.dailyLimit?.toString() ?? '');
    var force = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: const Text('Edit akun'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: username,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama tampilan'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Batas harian (kosong = default global)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pass,
                  decoration: const InputDecoration(
                    labelText: 'Password baru (kosongkan bila tidak diubah)',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: force,
                  onChanged: (v) => setSt(() => force = v ?? true),
                  title: const Text(
                    'Wajib ganti saat login berikutnya',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    final patch = <String, dynamic>{
      'username': username.text.trim().toLowerCase(),
      'display_name': name.text.trim(),
      'daily_limit': limit.text.trim().isEmpty
          ? null
          : int.tryParse(limit.text.trim()),
      if (pass.text.isNotEmpty) 'password': pass.text,
      if (pass.text.isNotEmpty) 'force_change': force,
    };
    for (final c in [name, username, pass, limit]) {
      c.dispose();
    }
    if (ok == true)
      _run(() => Backend.updateUser(u.id, patch), 'Akun diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateUserPage()),
          );
          _load();
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Buat'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Manajemen pengguna',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Cari username / nama…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final f in const [
                  ('all', 'Semua'),
                  ('active', 'Aktif'),
                  ('expired', 'Kedaluwarsa'),
                  ('no_license', 'Tanpa lisensi'),
                  ('disabled', 'Nonaktif'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) => setState(() => _filter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading && _users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            _error ?? 'Tidak ada pengguna.',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final u = list[i];
                        final color = switch (u.state) {
                          'active' => AppColors.ok,
                          'expired' || 'disabled' => AppColors.danger,
                          _ => AppColors.warn,
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            onTap: () => _actions(u),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: color.withOpacity(.18),
                                  child: Text(
                                    u.username[0].toUpperCase(),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.displayName?.isNotEmpty == true
                                            ? '${u.displayName} (@${u.username})'
                                            : '@${u.username}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${u.expiresAt == null ? 'Tanpa masa aktif' : 'Hingga ${fmtFull(u.expiresAt!)}'} • hari ini ${u.usedToday}${u.dailyLimit != null ? '/${u.dailyLimit}' : ''}',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(.16),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    u.stateLabel,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
