import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';

/// The mockup's `.btn-primary`: solid gold, dark text, full-width by
/// default (matches the CSS `width: 100%`).
class LuxPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;

  const LuxPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final fg = disabled ? LuxColors.textMuted : LuxColors.background;

    final child = Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: LuxText.manrope(size: 15, weight: FontWeight.w700, color: fg),
                  ),
                ),
              ],
            ),
    );

    final button = Material(
      color: disabled ? LuxColors.surfaceRaised : LuxColors.gold,
      borderRadius: BorderRadius.circular(LuxRadii.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(LuxRadii.button),
        onTap: disabled ? null : onPressed,
        child: child,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// The mockup's `.btn-secondary`: surface-raised fill with a border.
class LuxSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  const LuxSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LuxColors.surfaceRaised,
        borderRadius: BorderRadius.circular(LuxRadii.button),
        border: Border.all(color: LuxColors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: disabled ? LuxColors.textMuted : LuxColors.textPrimary),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: LuxText.manrope(
              size: 14,
              weight: FontWeight.w600,
              color: disabled ? LuxColors.textMuted : LuxColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(LuxRadii.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(LuxRadii.button),
        onTap: onPressed,
        child: child,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// The mockup's `.btn-ghost`: transparent, tan text, used for small
/// inline actions ("Select All", "Edit Clip", "Change").
class LuxGhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const LuxGhostButton({super.key, required this.label, this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(LuxRadii.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(LuxRadii.button),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: LuxText.manrope(size: 13, weight: FontWeight.w700, color: LuxColors.tan)),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 14, color: LuxColors.tan),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
