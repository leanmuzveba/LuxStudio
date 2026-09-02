import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';
import '../theme/phosphor_icons.dart';

class LuxBottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const LuxBottomNavItem({required this.icon, required this.activeIcon, required this.label});
}

/// The mockup's persistent bottom nav: a 96px glass bar with rounded top
/// corners, gold-filled icon when active, muted otherwise, and a raised
/// gold-gradient FAB (the "New Sermon Project" shortcut) centered between
/// the two middle tabs.
class LuxBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LuxBottomNavItem> items;
  final VoidCallback onFabTap;

  const LuxBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final half = (items.length / 2).ceil();
    final left = items.take(half).toList();
    final right = items.skip(half).toList();

    // The FAB is raised 24px above the bar, so it must live outside the
    // bar's own ClipRRect (which would otherwise slice off its top) — the
    // Stack below reserves that extra 24px as unclipped space and only
    // clips the bar itself, positioned at the bottom of the Stack.
    return SizedBox(
      height: 96 + bottomInset + 24,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 96 + bottomInset,
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: const BoxDecoration(
                color: LuxColors.bottomNavBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                border: Border(top: BorderSide(color: LuxColors.border)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < left.length; i++) _buildItem(left[i], i),
                    const SizedBox(width: 56),
                    for (var i = 0; i < right.length; i++) _buildItem(right[i], half + i),
                  ],
                ),
              ),
            ),
          ),
          _Fab(onTap: onFabTap),
        ],
      ),
    );
  }

  Widget _buildItem(LuxBottomNavItem item, int index) {
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
              Icon(active ? item.activeIcon : item.icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  final VoidCallback onTap;
  const _Fab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: LuxColors.goldGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0x66F4A823), blurRadius: 30, offset: Offset(0, 10)),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(PhosphorIcons.plusBold, size: 24, color: LuxColors.background),
        ),
      ),
    );
  }
}
