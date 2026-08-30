import 'package:flutter/material.dart';

import '../main.dart';
import '../services/media_import_service.dart';
import '../services/project_dashboard.dart';
import '../services/project_store.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_buttons.dart';
import '../widgets/lux_card.dart';
import '../widgets/lux_icon_button.dart';
import '../widgets/sticky_cta_bar.dart';

/// New Project — pick a fresh video (device picker, real copy+probe, then
/// straight into the editor) or continue a previously imported project
/// from Recent Files.
///
/// No animated processing pipeline: the real copy+probe is fast enough to
/// show as a brief spinner rather than a multi-stage fake timeline.
class ImportScreen extends StatefulWidget {
  /// [mediaImportService] lets tests inject one with fake pick/probe
  /// steps (real `file_picker`/ffprobe calls need platform channels with
  /// no implementation under plain `flutter test`). Defaults to real.
  const ImportScreen({super.key, MediaImportService? mediaImportService})
      : _injectedMediaImportService = mediaImportService;

  final MediaImportService? _injectedMediaImportService;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late final MediaImportService _mediaImportService =
      widget._injectedMediaImportService ?? MediaImportService();
  bool _importing = false;
  String? _importError;
  String? _selectedRecentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStateScope.of(context).loadRecentProjects();
    });
  }

  Future<void> _pickNewFile(AppState appState) async {
    setState(() => _importError = null);
    try {
      final project = await _mediaImportService.importVideo();
      if (!mounted) return;
      if (project == null) return; // user cancelled the picker

      setState(() => _importing = true);
      appState.startImport(project);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.analyse);
    } catch (e) {
      if (mounted) setState(() => _importError = e.toString());
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _notAvailableYet(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label isn\'t available in this build yet.')),
    );
  }

  void _continueWithSelected(AppState appState, List<ProjectSnapshot> recents) {
    ProjectSnapshot? selected;
    for (final s in recents) {
      if (s.project.id == _selectedRecentId) {
        selected = s;
        break;
      }
    }
    if (selected == null) return;
    appState.openProject(selected);
    // Already-analysed projects skip straight to the editor; anything
    // resumed before analysis ever ran (or that never finished) goes
    // through the automatic pipeline first, same as a fresh import.
    final destination =
        appState.analyseStatus == 'done' ? AppRoutes.editor : AppRoutes.analyse;
    Navigator.of(context).pushReplacementNamed(destination);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final recents = appState.recentProjects;
            final canContinue = _selectedRecentId != null;

            return Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          LuxDashedCard(
                            onTap: _importing ? null : () => _pickNewFile(appState),
                            child: Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: LuxColors.gold.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.cloud_upload_outlined, size: 28, color: LuxColors.gold),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Import Video',
                                  style: LuxText.sora(size: 16, weight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'MP4, MOV — up to 4GB',
                                  style: LuxText.manrope(size: 12.5, weight: FontWeight.w500, color: LuxColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (_importError != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: LuxColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Import failed: $_importError',
                                    style: LuxText.manrope(size: 12, color: LuxColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: LuxColors.divider)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'OR CHOOSE FROM',
                                  style: LuxText.manrope(size: 11.5, weight: FontWeight.w700, color: LuxColors.textMuted),
                                ),
                              ),
                              const Expanded(child: Divider(color: LuxColors.divider)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _SourceTile(
                                  icon: Icons.smartphone_rounded,
                                  label: 'Device',
                                  onTap: _importing ? null : () => _pickNewFile(appState),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SourceTile(
                                  icon: Icons.cloud_outlined,
                                  label: 'Cloud Drive',
                                  onTap: () => _notAvailableYet('Cloud Drive import'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SourceTile(
                                  icon: Icons.videocam_outlined,
                                  label: 'Camera',
                                  onTap: () => _notAvailableYet('Camera import'),
                                ),
                              ),
                            ],
                          ),
                          if (recents.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text('Recent Files', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            for (final snapshot in recents) ...[
                              _RecentFileRow(
                                snapshot: snapshot,
                                selected: _selectedRecentId == snapshot.project.id,
                                onTap: () => setState(() => _selectedRecentId = snapshot.project.id),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ),
                      if (_importing)
                        Container(
                          color: LuxColors.background.withValues(alpha: 0.85),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(color: LuxColors.gold),
                        ),
                    ],
                  ),
                ),
                if (canContinue)
                  StickyCtaBar(
                    child: LuxPrimaryButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => _continueWithSelected(appState, recents),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 14),
      child: Row(
        children: [
          LuxIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 18,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text('New Project', style: LuxText.manrope(size: 17, weight: FontWeight.w700)),
          ),
          LuxIconButton(
            icon: Icons.info_outline_rounded,
            variant: LuxIconButtonVariant.subtle,
            tooltip: 'About importing',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your file is copied privately into LuxStudio — the original is never modified.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SourceTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LuxCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 22, color: LuxColors.tan),
          const SizedBox(height: 8),
          Text(label, style: LuxText.manrope(size: 12, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecentFileRow extends StatelessWidget {
  final ProjectSnapshot snapshot;
  final bool selected;
  final VoidCallback onTap;
  const _RecentFileRow({required this.snapshot, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // File size used to come from a local sandbox copy — that no longer
    // exists now that media lives on the backend, so just show duration.
    final subtitle = formatProjectDuration(snapshot.project.processedDuration);

    return LuxCard(
      onTap: onTap,
      backgroundColor: selected ? LuxColors.gold.withValues(alpha: 0.08) : null,
      borderColor: selected ? LuxColors.gold : null,
      borderWidth: selected ? 1.5 : 1,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: LuxColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.movie_creation_outlined,
              size: 20,
              color: selected ? LuxColors.gold : LuxColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 13.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: LuxText.manrope(size: 11.5, weight: FontWeight.w600, color: LuxColors.textSecondary)),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: selected ? LuxColors.gold : LuxColors.textMuted,
          ),
        ],
      ),
    );
  }
}
