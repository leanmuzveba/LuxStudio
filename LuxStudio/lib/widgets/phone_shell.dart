import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';

/// Caps [child] to the ui_kit mockups' phone-shell width (max 430px,
/// centered — see ui_kit/*/styles.css's `.app { max-width: 430px; margin: 0
/// auto; }`), so it doesn't stretch full-width on a wide browser/desktop
/// window.
///
/// Used to wrap every mobile-shaped route individually (see main.dart)
/// instead of applying one blanket constraint to the whole app in
/// [MaterialApp.builder] — that would also squeeze [DesktopShellScaffold],
/// which is meant to fill the full window width once it's desktop-wide.
class PhoneShell extends StatelessWidget {
  final Widget child;
  const PhoneShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LuxColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child,
        ),
      ),
    );
  }
}
