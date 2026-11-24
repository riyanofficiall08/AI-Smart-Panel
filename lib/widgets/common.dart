import 'package:flutter/material.dart';

import '../core/theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (borderColor ?? Colors.white).withOpacity(
            borderColor == null ? .07 : .4,
          ),
        ),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: box,
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : .55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: danger
                ? const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                  )
                : AppColors.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (danger ? AppColors.danger : AppColors.cyan).withOpacity(
                  .25,
                ),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, color: Colors.white, size: 20),
                  if (loading || icon != null) const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
    ),
  );
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: AppColors.gradient,
      boxShadow: [
        BoxShadow(color: AppColors.cyan.withOpacity(.4), blurRadius: 18),
      ],
    ),
    child: Icon(
      Icons.auto_awesome_rounded,
      color: Colors.white,
      size: size * .52,
    ),
  );
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFF7F1D1D) : AppColors.surface2,
        duration: Duration(seconds: error ? 5 : 3),
      ),
    );
}
