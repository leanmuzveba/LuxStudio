import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The single recurring call-to-action style across LuxStudio: a pill
/// button filled with the brand gradient.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    final child = Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: disabled ? null : AppColors.accentGradient,
        color: disabled ? AppColors.surfaceRaised : null,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: Gaps.sm),
          ],
          Text(
            label,
            style: TextStyle(
              color: disabled ? AppColors.textMuted : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onPressed,
        child: expand ? SizedBox(width: double.infinity, child: child) : child,
      ),
    );
  }
}
