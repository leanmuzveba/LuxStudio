import 'package:flutter/material.dart';

import '../main.dart';
import '../services/project_dashboard.dart';
import '../services/project_store.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_card.dart';
import '../widgets/lux_chip.dart';
import '../widgets/lux_icon_button.dart';
import '../widgets/lux_pill.dart';

enum _ProjectFilter { all, drafts, exported }

/// The Home dashboard — matches `ui_kit/home/index.html`: brand header,
/// a big "New Sermon Project" CTA, and a "Recent Teachings" list. Search
/// and filter-by-status aren't in the static mockup (it only shows one
/// state), but stay here as real functionality for a growing library —
/// restyled to fit, tucked below the section title rather than changing
/// the mockup's own layout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _ProjectFilter _filter = _ProjectFilter.all;
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStateScope.of(context).loadRecentProjects();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _newProject(AppState appState) async {
    await Navigator.of(context).pushNamed(AppRoutes.import);
    if (!mounted) return;
    appState.loadRecentProjects();
  }

  Future<void> _openProject(AppState appState, ProjectSnapshot snapshot) async {
    appState.openProject(snapshot);
    await Navigator.of(context).pushNamed(AppRoutes.editor);
    if (!mounted) return;
    appState.loadRecentProjects();
  }

  List<ProjectSnapshot> _filtered(List<ProjectSnapshot> all) {
    var list = all;
    switch (_filter) {
      case _ProjectFilter.all:
        break;
      case _ProjectFilter.drafts:
        list = list.where((s) => !s.project.hasExported).toList();
      case _ProjectFilter.exported:
        list = list.where((s) => s.project.hasExported).toList();
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((s) => s.project.title.toLowerCase().contains(query)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final projects = _filtered(appState.recentProjects);
            return Column(
              children: [
                _buildHeader(context, appState),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: [
                      Text('Welcome Back', style: LuxText.sora(size: 30, weight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        "Ready to edit today's teaching?",
                        style: LuxText.manrope(
                          size: 14,
                          weight: FontWeight.w500,
                          color: LuxColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _NewSermonCta(onTap: () => _newProject(appState)),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Teachings', style: LuxText.manrope(size: 16, weight: FontWeight.w600)),
                          LuxIconButton(
                            icon: Icons.search_rounded,
                            variant: LuxIconButtonVariant.subtle,
                            size: 32,
                            iconSize: 18,
                            tooltip: 'Search teachings',
                            onPressed: () => setState(() => _searching = !_searching),
                          ),
                        ],
                      ),
                      if (_searching) ...[
                        const SizedBox(height: 12),
                        _SearchField(controller: _searchController, onChanged: (_) => setState(() {})),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _filter == _ProjectFilter.all,
                            onTap: () => setState(() => _filter = _ProjectFilter.all),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Drafts',
                            selected: _filter == _ProjectFilter.drafts,
                            onTap: () => setState(() => _filter = _ProjectFilter.drafts),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Exported',
                            selected: _filter == _ProjectFilter.exported,
                            onTap: () => setState(() => _filter = _ProjectFilter.exported),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (appState.isLoadingRecentProjects)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: LuxColors.gold),
                            ),
                          ),
                        )
                      else if (projects.isEmpty)
                        _EmptyState(hasAnyProjects: appState.recentProjects.isNotEmpty)
                      else
                        Column(
                          children: [
                            for (final snapshot in projects) ...[
                              _TeachingCard(
                                snapshot: snapshot,
                                onTap: () => _openProject(appState, snapshot),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState appState) {
    final tagline = appState.brandSettings.organizationName.trim().isEmpty
        ? 'LUXSTUDIO'
        : appState.brandSettings.organizationName.trim().toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/branding/icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LuxStudio',
                  style: LuxText.sora(size: 18, weight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tagline,
                  style: LuxText.manrope(
                    size: 10,
                    weight: FontWeight.w600,
                    color: LuxColors.gold,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          LuxIconButton(
            icon: Icons.person_outline_rounded,
            variant: LuxIconButtonVariant.onSurface,
            tooltip: 'Profile',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile coming soon.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewSermonCta extends StatelessWidget {
  final VoidCallback onTap;
  const _NewSermonCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LuxColors.goldGradient,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 25)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: Color(0x1A000000), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.add_rounded, size: 30, color: LuxColors.background),
              ),
              const SizedBox(height: 16),
              Text(
                'New Sermon Project',
                style: LuxText.sora(size: 20, weight: FontWeight.w700, color: LuxColors.background),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: LuxText.manrope(size: 14, color: LuxColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: LuxColors.surfaceRaised,
        hintText: 'Search teachings',
        hintStyle: LuxText.manrope(size: 14, color: LuxColors.textMuted),
        prefixIcon: const Icon(Icons.search_rounded, color: LuxColors.textMuted, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LuxRadii.button),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LuxChip(label: label, selected: selected, onTap: onTap);
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasAnyProjects;
  const _EmptyState({required this.hasAnyProjects});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          hasAnyProjects
              ? 'No teachings match this filter.'
              : 'No teachings yet — tap New Sermon Project to get started.',
          textAlign: TextAlign.center,
          style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
        ),
      ),
    );
  }
}

class _TeachingCard extends StatelessWidget {
  final ProjectSnapshot snapshot;
  final VoidCallback onTap;
  const _TeachingCard({required this.snapshot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = deriveProjectStatus(snapshot);
    final (String label, LuxPillTone tone) = switch (status) {
      ProjectDashboardStatus.editing => ('Editing', LuxPillTone.amber),
      ProjectDashboardStatus.clipsReady => ('Clips Ready', LuxPillTone.gold),
      ProjectDashboardStatus.exported => ('Exported', LuxPillTone.tan),
    };

    return LuxCard(
      onTap: onTap,
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: LuxColors.background, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: const Icon(Icons.videocam_outlined, size: 24, color: LuxColors.textMuted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 15, weight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${relativeUpdatedLabel(snapshot.project.updatedAt)} • '
                        '${formatProjectDuration(snapshot.project.processedDuration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LuxText.manrope(
                          size: 12,
                          weight: FontWeight.w500,
                          color: LuxColors.textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LuxPill(label: label, tone: tone),
              ],
            ),
          ),
          const Icon(Icons.more_vert_rounded, size: 20, color: LuxColors.textSecondary),
        ],
      ),
    );
  }
}
