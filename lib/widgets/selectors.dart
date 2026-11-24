import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/local_settings.dart';
import '../state/settings_controller.dart';

class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    return Column(
      children: [
        for (final m in ResponseMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => ctrl.update((s) => s.copyWith(mode: m)),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ctrl.s.mode == m
                        ? AppColors.cyan
                        : Colors.transparent,
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      switch (m) {
                        ResponseMode.fast => Icons.bolt_rounded,
                        ResponseMode.accurate => Icons.track_changes_rounded,
                        ResponseMode.study => Icons.school_rounded,
                      },
                      color: ctrl.s.mode == m
                          ? AppColors.cyan
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode ${m.label}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            m.description,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ctrl.s.mode == m)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.cyan,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ConfidenceSelector extends StatelessWidget {
  const ConfidenceSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final v in confidenceLevels)
                ButtonSegment(value: v, label: Text('$v%')),
            ],
            selected: {ctrl.s.confidence},
            onSelectionChanged: (set) =>
                ctrl.update((s) => s.copyWith(confidence: set.first)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          confidenceHint(ctrl.s.confidence),
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ini hanya preferensi tingkat kehati-hatian analisis AI, bukan jaminan jawaban benar.',
          style: TextStyle(fontSize: 12, color: AppColors.warn, height: 1.4),
        ),
      ],
    );
  }
}
