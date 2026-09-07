import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/export_history_entry.dart';
import '../services/project_dashboard.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../utils/error_presenter.dart';

/// Desktop Exports — a real export history, scoped above individual
/// projects (V2 Decision #3), matching `ui_kit/exports_desktop/`'s
/// two-pane shape but not its content: see the doc comment below for what
/// was deliberately not rebuilt.
///
/// Scope cuts vs. the mockup, same pattern as Phases 26-29:
/// - **No File Name / Format / Preset / Resolution & Frame Rate
///   controls.** Every export is a fixed 1080x1920 H.264 MP4
///   (`backend/app/services/ffmpeg_client.py`'s `export_clip`) — there is
///   no 4K option, no configurable fps, no alternate codec. Building
///   dropdowns for settings the backend would silently ignore would be
///   actively misleading, not just decorative.
/// - **No Publish Destinations (YouTube/Instagram/TikTok/Drive).** No
///   OAuth or publish integration exists anywhere in this app — same
///   category of gap the mobile Share screen already documents for its
///   own (equally cosmetic) platform picker.
/// - **No fake Disk Space readout, no fake per-item render
///   percentage/ETA.** A Flutter Web app can't read real system disk
///   space, and the backend's export is one synchronous call with no
///   progress reporting — not multiple concurrent jobs with individual
///   completion percentages. The one real in-flight state
///   ([AppState.isExportingClip]) is shown as a single spinner row, not a
///   fabricated queue.
/// - "Render Queue" (mockup's header button) is dropped — there's nothing
///   queued to start; exporting happens from the Editor/AI
///   Highlights/Share screens' own real "Export"/"Edit & Export" actions.
///   This screen is the history of what already ran, plus re-download.
class ExportsDesktopScreen extends StatefulWidget {
  const ExportsDesktopScreen({super.key});

  @override
  State<ExportsDesktopScreen> createState() => _ExportsDesktopScreenState();
}

class _ExportsDesktopScreenState extends State<ExportsDesktopScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame — see MediaLibraryDesktopScreen's
    // identical note: calling this straight from build() would trigger
    // AppState.notifyListeners() while the framework is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppStateScope.of(context).loadExportHistory();
    });
  }

  Future<void> _download(BuildContext context, AppState appState, ExportHistoryEntry entry) async {
    final url = entry.downloadUrl;
    if (url == null) return;
    try {
      final bytes = await appState.downloadExport(url);
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, name: '${entry.clipTitle}.mp4', mimeType: 'video/mp4')],
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${friendlyError(e.toString())}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return ColoredBox(
      color: LuxColors.background,
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return Column(
            children: [
              _Header(
                busy: appState.isLoadingExportHistory,
                onRefresh: appState.loadExportHistory,
              ),
              Expanded(
                child: appState.isLoadingExportHistory
                    ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (appState.exportHistoryError != null) ...[
                              Text(
                                friendlyError(appState.exportHistoryError),
                                style: LuxText.manrope(size: 12, color: LuxColors.error),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              'EXPORT HISTORY',
                              style: LuxText.manrope(size: 11, weight: FontWeight.w700, color: LuxColors.textMuted, letterSpacing: 1),
                            ),
                            const SizedBox(height: 16),
                            if (appState.isExportingClip)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _InFlightCard(title: appState.selectedClip?.title ?? 'Exporting clip'),
                              ),
                            if (appState.exportHistory.isEmpty && !appState.isExportingClip)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    'No exports yet — export a clip from the Editor, AI Highlights, or Share to see it here.',
                                    textAlign: TextAlign.center,
                                    style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              for (final entry in appState.exportHistory) ...[
                                _HistoryCard(
                                  entry: entry,
                                  onDownload: () => _download(context, appState, entry),
                                  onDelete: () => appState.deleteExportHistoryEntry(entry.id),
                                ),
                                const SizedBox(height: 12),
                              ],
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool busy;
  final VoidCallback onRefresh;

  const _Header({required this.busy, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.border))),
      child: Row(
        children: [
          const Icon(Icons.ios_share_rounded, size: 18, color: LuxColors.gold),
          const SizedBox(width: 8),
          Text('Export Center', style: LuxText.manrope(size: 15.5, weight: FontWeight.w700)),
          const Spacer(),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: busy ? null : onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(color: LuxColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 15, color: busy ? LuxColors.textMuted : LuxColors.textPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Refresh',
                      style: LuxText.manrope(size: 12.5, weight: FontWeight.w600, color: busy ? LuxColors.textMuted : LuxColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InFlightCard extends StatelessWidget {
  final String title;
  const _InFlightCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: LuxColors.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: LuxColors.gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Exporting "$title"…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LuxText.manrope(size: 13.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ExportHistoryEntry entry;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _HistoryCard({required this.entry, required this.onDownload, required this.onDelete});

  String _relativeLabel(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Exported just now';
    if (diff.inMinutes < 60) return 'Exported ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Exported ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Exported yesterday';
    return 'Exported ${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final done = entry.isDone;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: LuxColors.surfaceDashed, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(
              done ? Icons.movie_creation_outlined : Icons.error_outline_rounded,
              size: 22,
              color: done ? LuxColors.borderStrong : LuxColors.error,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.clipTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 13.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.projectTitle} · ${_relativeLabel(entry.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 11.5, color: LuxColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (done ? LuxColors.success : LuxColors.error).withValues(alpha: 0.12),
                        border: Border.all(color: (done ? LuxColors.success : LuxColors.error).withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        done ? 'SUCCESS' : 'FAILED',
                        style: LuxText.manrope(
                          size: 9,
                          weight: FontWeight.w800,
                          color: done ? LuxColors.success : LuxColors.error,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (done && entry.sizeBytes != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${formatFileSize(entry.sizeBytes!)} · ${formatProjectDuration(entry.duration)}',
                        style: LuxText.manrope(size: 10.5, color: LuxColors.textMuted),
                      ),
                    ],
                  ],
                ),
                if (!done && entry.error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    friendlyError(entry.error),
                    style: LuxText.manrope(size: 10.5, color: LuxColors.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (done)
            IconButton(
              tooltip: 'Download / Share',
              icon: const Icon(Icons.ios_share_rounded, size: 17, color: LuxColors.textSecondary),
              onPressed: onDownload,
            ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, size: 17, color: LuxColors.textSecondary),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
