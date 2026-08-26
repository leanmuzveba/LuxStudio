import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';
import 'lux_icon_button.dart';

/// The mockup's app bar: back arrow, title (optionally with a small
/// status subtitle underneath, e.g. "Saved just now"), trailing actions.
class LuxAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? subtitleIcon;
  final List<Widget>? actions;
  final bool showBack;

  const LuxAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleIcon,
    this.actions,
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showBack
          ? LuxIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 18,
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      leadingWidth: showBack ? 52 : 0,
      titleSpacing: showBack ? 0 : NavigationToolbar.kMiddleSpacing,
      title: subtitle == null
          ? Text(title, style: LuxText.manrope(size: 17, weight: FontWeight.w700))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: LuxText.manrope(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (subtitleIcon != null) ...[subtitleIcon!, const SizedBox(width: 4)],
                    Text(
                      subtitle!,
                      style: LuxText.manrope(
                        size: 12,
                        weight: FontWeight.w500,
                        color: LuxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      actions: actions,
    );
  }
}
