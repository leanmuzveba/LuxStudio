import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';

/// The mockup's sticky bottom action bar: top divider, optional small
/// note above the primary action (e.g. "3 clips selected"), safe-area
/// aware bottom padding.
class StickyCtaBar extends StatelessWidget {
  final String? note;
  final Widget child;

  const StickyCtaBar({super.key, this.note, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: LuxColors.background,
        border: Border(top: BorderSide(color: LuxColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note != null) ...[
            Text(
              note!,
              textAlign: TextAlign.center,
              style: LuxText.manrope(size: 12.5, weight: FontWeight.w500, color: LuxColors.textSecondary),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}
