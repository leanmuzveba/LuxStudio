import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';

/// The `.icon-btn` shape from the mockup: a circular tap target (e.g.
/// `border-radius: 999px` / `rounded-full`) in one of four fills.
enum LuxIconButtonVariant { standard, subtle, onSurface, filledGold }

class LuxIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final LuxIconButtonVariant variant;
  final double size;
  final double iconSize;
  final String? tooltip;

  const LuxIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.variant = LuxIconButtonVariant.standard,
    this.size = 38,
    this.iconSize = 20,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (variant) {
      case LuxIconButtonVariant.standard:
        bg = Colors.transparent;
        fg = LuxColors.textPrimary;
      case LuxIconButtonVariant.subtle:
        bg = Colors.transparent;
        fg = LuxColors.iconSubtle;
      case LuxIconButtonVariant.onSurface:
        bg = LuxColors.surfaceRaised;
        fg = LuxColors.textPrimary;
      case LuxIconButtonVariant.filledGold:
        bg = LuxColors.gold;
        fg = LuxColors.background;
    }

    final button = Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: fg),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
