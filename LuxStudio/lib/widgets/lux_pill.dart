import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';

/// The mockup's `.pill`: a small uppercase status tag (e.g. "Editing",
/// "Clips Ready", "Strong Hook", "Done").
enum LuxPillTone { gold, amber, tan, neutral }

class LuxPill extends StatelessWidget {
  final String label;
  final LuxPillTone tone;

  const LuxPill({super.key, required this.label, this.tone = LuxPillTone.neutral});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      LuxPillTone.gold => (LuxColors.gold.withValues(alpha: 0.16), LuxColors.gold),
      LuxPillTone.amber => (LuxColors.amber.withValues(alpha: 0.16), LuxColors.amber),
      LuxPillTone.tan => (LuxColors.tan.withValues(alpha: 0.16), LuxColors.tan),
      LuxPillTone.neutral => (LuxColors.surfaceRaised, LuxColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(LuxRadii.pill)),
      child: Text(
        label.toUpperCase(),
        style: LuxText.manrope(size: 10.5, weight: FontWeight.w800, color: fg, letterSpacing: 0.4),
      ),
    );
  }
}
