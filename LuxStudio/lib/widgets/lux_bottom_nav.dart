import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';

class LuxBottomNavItem {
  final IconData icon;
  final String label;

  const LuxBottomNavItem({required this.icon, required this.label});
}

/// The mockup's persistent bottom nav (Home / Branding / Settings):
/// gold when active, muted otherwise, with a top divider.
class LuxBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LuxBottomNavItem> items;

  const LuxBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: LuxColors.bottomNavBg,
        border: Border(top: BorderSide(color: LuxColors.divider)),
      ),
      padding: EdgeInsets.only(top: 8, bottom: 8 + bottomInset),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < items.length; i++) _buildItem(context, i),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = items[index];
    final active = index == currentIndex;
    final color = active ? LuxColors.gold : LuxColors.textMutedAlt;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: LuxText.manrope(size: 11, weight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
