import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/admin_models.dart';
import '../../services/backend.dart';
import 'admin_dashboard.dart';

class UsageLogsPage extends StatefulWidget {
  const UsageLogsPage({super.key, this.userId, this.title = 'Semua pengguna'});
  final String? userId;
  final String title;

  @override
  State<UsageLogsPage> createState() => _UsageLogsPageState();
}

class _UsageLogsPageState extends State<UsageLogsPage> {
  List<UsageLog> _logs = [];
  bool _loading = true;
  String? _error;

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
      _logs = await Backend.usageLogs(userId: widget.userId, limit: 200);
    } on BackendException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Riwayat penggunaan • ${widget.title}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _logs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Text(
                      _error ?? 'Belum ada data.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _logs.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0x14FFFFFF)),
                itemBuilder: (_, i) => LogTile(log: _logs[i]),
              ),
      ),
    );
  }
}
