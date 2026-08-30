import 'package:flutter/material.dart';

import '../main.dart';
import '../screens/ai_clips_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/video_editor_screen.dart';
import '../theme/phosphor_icons.dart';
import 'lux_bottom_nav.dart';

/// The app's root shell once past import/recovery: Home / Editor / Clips /
/// Settings as persistent bottom-nav tabs (matching the ui_kit's nav bar
/// on every screen) with a raised FAB shortcut to start a new project.
/// Branding lives inside Settings now (see Phase 13) rather than its own
/// tab. Editor/Clips both already handle a null [AppState.project]
/// gracefully (no project imported yet), so they're safe to keep mounted
/// even before the user starts one.
class BottomNavScaffold extends StatefulWidget {
  const BottomNavScaffold({super.key});

  @override
  State<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends State<BottomNavScaffold> {
  int _index = 0;

  static const _items = [
    LuxBottomNavItem(
      icon: PhosphorIcons.house,
      activeIcon: PhosphorIcons.houseFill,
      label: 'Home',
    ),
    LuxBottomNavItem(
      icon: PhosphorIcons.scissors,
      activeIcon: PhosphorIcons.scissorsFill,
      label: 'Editor',
    ),
    LuxBottomNavItem(
      icon: PhosphorIcons.sparkle,
      activeIcon: PhosphorIcons.sparkleFill,
      label: 'Clips',
    ),
    LuxBottomNavItem(
      icon: PhosphorIcons.gearSix,
      activeIcon: PhosphorIcons.gearSixFill,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          VideoEditorScreen(),
          AiClipsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: LuxBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _items,
        onFabTap: () => Navigator.of(context).pushNamed(AppRoutes.import),
      ),
    );
  }
}
