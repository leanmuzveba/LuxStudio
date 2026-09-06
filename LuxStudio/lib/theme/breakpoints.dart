import 'package:flutter/widgets.dart';

/// The single width threshold that decides mobile (phone-shell, bottom nav)
/// vs. desktop (wide, sidebar nav) layout across the whole app — see
/// PIVOT_PLAN_V2.md Phase 24. Chosen above common tablet-portrait widths
/// (the ui_kit desktop mockups assume a real desktop-class window, not a
/// tablet) so a tablet in portrait still gets the mobile phone-shell layout.
class Breakpoints {
  Breakpoints._();

  static const desktop = 900.0;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}
