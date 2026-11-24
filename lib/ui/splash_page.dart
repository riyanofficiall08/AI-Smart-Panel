import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.3),
            radius: 1.1,
            colors: [Color(0xFF1B1F4B), AppColors.bg],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(
              opacity: v.clamp(0, 1),
              child: Transform.scale(scale: .6 + .4 * v, child: child),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LogoMark(size: 96),
                SizedBox(height: 22),
                Text(
                  'AI SMART PANEL',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Asisten belajar melayang',
                  style: TextStyle(color: AppColors.muted),
                ),
                SizedBox(height: 28),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
