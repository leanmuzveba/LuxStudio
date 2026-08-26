import 'package:flutter/material.dart';

import '../main.dart';
import '../services/project_dashboard.dart';
import '../services/project_store.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_buttons.dart';
import '../widgets/lux_card.dart';
import '../widgets/lux_chip.dart';
import '../widgets/lux_icon_button.dart';
import '../widgets/lux_pill.dart';

enum _ProjectFilter { all, drafts, exported }

/// The Home dashboard — the app's new landing tab. Shows a "New Project"
/// CTA and every saved project (from [AppState.recentProjects]) with a
/// status pill, filterable by All / Drafts / Exported and searchable by
/// title.
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
                _buildAppBar(context, appState),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      Text(
                        'Welcome back,',
                        style: LuxText.manrope(size: 13, weight: FontWeight.w600, color: LuxColors.textSecondary),
                      ),
                      Text(
                        appState.brandSettings.organizationName.trim().isEmpty
                            ? 'there'
                            : appState.brandSettings.organizationName.trim(),
                        style: LuxText.sora(size: 25, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 20),
                      LuxPrimaryButton(
                        label: 'New Project',
                        icon: Icons.add_rounded,
                        onPressed: () => _newProject(appState),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Projects', style: LuxText.manrope(size: 16, weight: FontWeight.w700)),
                          LuxIconButton(
                            icon: Icons.search_rounded,
                            variant: LuxIconButtonVariant.subtle,
                            size: 32,
                            iconSize: 18,
                            tooltip: 'Search projects',
                            onPressed: () => setState(() => _searching = !_searching),
                          ),
                        ],
                      ),
                      if (_searching) ...[
                        const SizedBox(height: 12),
                        _SearchField(controller: _searchController, onChanged: (_) => setState(() {})),
                      ],
                      const SizedBox(height: 14),
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
                              _ProjectCard(
                                snapshot: snapshot,
                                onTap: () => _openProject(appState, snapshot),
                              ),
                              const SizedBox(height: 12),
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

  Widget _buildAppBar(BuildContext context, AppState appState) {
    final initials = appState.brandSettings.organizationName.trim().isEmpty
        ? 'LX'
        : appState.brandSettings.organizationName.trim().substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: LuxColors.avatarGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 15, color: LuxColors.background),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'LuxStudio',
              style: LuxText.sora(size: 17, weight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          LuxIconButton(
            icon: Icons.notifications_outlined,
            variant: LuxIconButtonVariant.subtle,
            tooltip: 'Notifications',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No notifications yet.')),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(gradient: LuxColors.avatarGradient, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: LuxText.sora(size: 13, weight: FontWeight.w700, color: LuxColors.background),
            ),
          ),
        ],
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
        hintText: 'Search projects',
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
              ? 'No projects match this filter.'
              : 'No projects yet — tap New Project to get started.',
          textAlign: TextAlign.center,
          style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectSnapshot snapshot;
  final VoidCallback onTap;
  const _ProjectCard({required this.snapshot, required this.onTap});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: LuxColors.slate,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.movie_creation_outlined, size: 26, color: LuxColors.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 14.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    LuxPill(label: label, tone: tone),
                    const SizedBox(width: 8),
                    Text(
                      formatProjectDuration(snapshot.project.processedDuration),
                      style: LuxText.manrope(size: 12, weight: FontWeight.w600, color: LuxColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  relativeUpdatedLabel(snapshot.project.updatedAt),
                  style: LuxText.manrope(size: 11.5, weight: FontWeight.w600, color: LuxColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
