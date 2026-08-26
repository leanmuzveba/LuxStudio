import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';

/// The mockup's `.chip`: a pill-shaped filter/selector/tab control.
/// Selected = gold-tinted background + gold border.
class LuxChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const LuxChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? LuxColors.gold : LuxColors.textSecondary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(LuxRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(LuxRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? LuxColors.gold.withValues(alpha: 0.14) : LuxColors.surfaceRaised,
            borderRadius: BorderRadius.circular(LuxRadii.pill),
            border: Border.all(
              color: selected ? LuxColors.gold : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
              ],
              Text(label, style: LuxText.manrope(size: 13, weight: FontWeight.w700, color: color)),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
