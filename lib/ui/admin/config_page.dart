import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'api_config_page.dart';
import 'model_config_page.dart';
import 'usage_logs_page.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String sub, Widget page) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => page),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.cyan, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Text(
          'Konfigurasi',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        item(
          Icons.key_rounded,
          'API Configuration',
          'OpenAI API Key (tersimpan terenkripsi di server)',
          const ApiConfigPage(),
        ),
        item(
          Icons.memory_rounded,
          'Model Configuration',
          'Model per mode, batas harian & rate limit',
          const ModelConfigPage(),
        ),
        item(
          Icons.receipt_long_rounded,
          'Log penggunaan',
          'Seluruh aktivitas analisis & administrasi',
          const UsageLogsPage(),
        ),
      ],
    );
  }
}
