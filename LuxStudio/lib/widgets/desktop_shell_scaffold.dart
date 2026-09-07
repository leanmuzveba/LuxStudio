import 'package:flutter/material.dart';

import '../main.dart';
import '../screens/ai_clips_screen.dart';
import '../screens/media_library_desktop_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/video_editor_desktop_screen.dart';
import '../theme/lux_theme.dart';
import '../theme/phosphor_icons.dart';
import 'phone_shell.dart';

/// The desktop-viewport root shell (see PIVOT_PLAN_V2.md Phase 24): a fixed
/// 256px sidebar (logo, 5 nav destinations, a pinned Settings entry, and a
/// "Current Project" card — matching every `ui_kit/*_desktop/` mockup) next
/// to a wide content pane, replacing [BottomNavScaffold] once the window is
/// at least [Breakpoints.desktop] wide.
///
/// Editor ([VideoEditorDesktopScreen], Phase 26) and Media Library
/// ([MediaLibraryDesktopScreen], Phase 27) have their own desktop-shaped
/// widget trees, both sharing [AppState] with the rest of the app. AI
/// Highlights and Settings reuse the existing mobile screens as-is for now
/// (own desktop-shaped versions land in Phases 28/31) — shown at their
/// original phone-shell width, centered in the wide pane, rather than
/// stretched full-width. Subtitles and Exports don't exist as features at
/// all yet — each needs its own backend entity per the V2 decisions — so
/// they show a placeholder until their own functionality phase (29/30)
/// builds them for real.
class DesktopShellScaffold extends StatefulWidget {
  const DesktopShellScaffold({super.key});

  @override
  State<DesktopShellScaffold> createState() => _DesktopShellScaffoldState();
}

class _DesktopShellScaffoldState extends State<DesktopShellScaffold> {
  int _index = 0;

  static const _navItems = [
    _NavDestination(icon: PhosphorIcons.videoCameraBold, label: 'Editor'),
    _NavDestination(icon: PhosphorIcons.stackBold, label: 'Media Library'),
    _NavDestination(icon: PhosphorIcons.magicWandBold, label: 'AI Highlights'),
    _NavDestination(icon: PhosphorIcons.textTBold, label: 'Subtitles'),
    _NavDestination(icon: PhosphorIcons.exportBold, label: 'Exports'),
  ];
  static const _settingsIndex = 5;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _index,
            navItems: _navItems,
            settingsIndex: _settingsIndex,
            onSelect: (i) => setState(() => _index = i),
            projectTitle: appState.project?.title,
            progress: switch (appState.analyseStatus) {
              'done' => 1.0,
              'running' => (appState.analysePercent.clamp(0, 100)) / 100,
              _ => 0.0,
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                VideoEditorDesktopScreen(),
                MediaLibraryDesktopScreen(),
                PhoneShell(child: AiClipsScreen()),
                _ComingSoonPane(
                  icon: PhosphorIcons.textTBold,
                  title: 'Subtitles',
                  phaseNote: 'Lands in Phase 29, with real font/position/timing caption controls.',
                ),
                _ComingSoonPane(
                  icon: PhosphorIcons.exportBold,
                  title: 'Exports',
                  phaseNote: 'Lands in Phase 30, with a real export history/queue.',
                ),
                PhoneShell(child: SettingsScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDestination {
  final IconData icon;
  final String label;
  const _NavDestination({required this.icon, required this.label});
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavDestination> navItems;
  final int settingsIndex;
  final ValueChanged<int> onSelect;
  final String? projectTitle;
  final double progress;

  const _Sidebar({
    required this.selectedIndex,
    required this.navItems,
    required this.settingsIndex,
    required this.onSelect,
    required this.projectTitle,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: LuxColors.background,
        border: Border(right: BorderSide(color: LuxColors.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Image.asset('assets/branding/icon.png', width: 40, height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: LuxText.sora(size: 20, weight: FontWeight.w700),
                      children: const [
                        TextSpan(text: 'Lux'),
                        TextSpan(text: 'Studio', style: TextStyle(color: LuxColors.gold)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < navItems.length; i++)
                  _SidebarItem(
                    icon: navItems[i].icon,
                    label: navItems[i].label,
                    selected: i == selectedIndex,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SidebarItem(
                  icon: PhosphorIcons.gearBold,
                  label: 'Settings',
                  selected: selectedIndex == settingsIndex,
                  onTap: () => onSelect(settingsIndex),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LuxColors.surface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LuxColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT PROJECT',
                        style: LuxText.manrope(
                          size: 10,
                          weight: FontWeight.w700,
                          color: LuxColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        projectTitle ?? 'No project open',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LuxText.sora(size: 13.5, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: LuxColors.background,
                          color: LuxColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? LuxColors.textPrimary : LuxColors.textSecondary;
    return Material(
      color: selected ? LuxColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? LuxColors.gold : color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 14, weight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonPane extends StatelessWidget {
  final IconData icon;
  final String title;
  final String phaseNote;

  const _ComingSoonPane({required this.icon, required this.title, required this.phaseNote});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LuxColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: LuxColors.borderStrong),
              const SizedBox(height: 16),
              Text(title, style: LuxText.sora(size: 20, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                phaseNote,
                textAlign: TextAlign.center,
                style: LuxText.manrope(size: 13.5, color: LuxColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
