import 'package:flutter/material.dart';

import '../screens/branding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import 'lux_bottom_nav.dart';

/// The app's root shell once past import/recovery: Home / Branding /
/// Settings as persistent bottom-nav tabs, matching the mockup's nav bar.
class BottomNavScaffold extends StatefulWidget {
  const BottomNavScaffold({super.key});

  @override
  State<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends State<BottomNavScaffold> {
  int _index = 0;

  static const _items = [
    LuxBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
    LuxBottomNavItem(icon: Icons.palette_outlined, label: 'Branding'),
    LuxBottomNavItem(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          BrandingScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: LuxBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _items,
      ),
    );
  }
}
