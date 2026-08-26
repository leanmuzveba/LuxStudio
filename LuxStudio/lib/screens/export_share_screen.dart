import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/ai_clip.dart';
import '../models/export_job.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';
import '../widgets/lux_buttons.dart';
import '../widgets/lux_card.dart';
import '../widgets/lux_icon_button.dart';
import '../widgets/lux_pill.dart';
import '../widgets/sticky_cta_bar.dart';

/// Export — every clip with [AiClip.includeInExport] set gets its own
/// queued/processing/done row (real progress from [AppState.exportJobs]),
/// exported one at a time, then shareable once done.
class ExportShareScreen extends StatelessWidget {
  const ExportShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      appBar: const LuxAppBar(title: 'Export'),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final clips = appState.suggestedClips.where((c) => c.includeInExport).toList();
          final doneCount = clips.where((c) => appState.exportJobs[c.id]?.status == ExportJobStatus.done).length;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: LuxColors.surface,
                        border: Border.all(color: LuxColors.border),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.movie_creation_outlined, size: 16, color: LuxColors.gold),
                          const SizedBox(width: 8),
                          Text(
                            '1080 × 1920 · MP4 · 9:16',
                            style: LuxText.manrope(size: 12.5, weight: FontWeight.w700, color: LuxColors.gold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (clips.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No clips selected — go back to AI Clips and include at least one.',
                            textAlign: TextAlign.center,
                            style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
                          ),
                        ),
                      )
                    else ...[
                      Text('Clips to Export', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      for (final clip in clips) ...[
                        _ExportRow(
                          clip: clip,
                          job: appState.exportJobs[clip.id],
                          onRetry: () => appState.retryClipExport(clip),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
              if (clips.isNotEmpty)
                StickyCtaBar(
                  note: appState.isBatchExporting
                      ? 'Exporting ${doneCount + 1} of ${clips.length}…'
                      : (doneCount == clips.length ? 'All clips exported.' : null),
                  child: LuxPrimaryButton(
                    label: appState.isBatchExporting ? 'Exporting…' : 'Export All (${clips.length})',
                    icon: Icons.file_download_outlined,
                    loading: appState.isBatchExporting,
                    onPressed: appState.isBatchExporting ? null : appState.exportBatch,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExportRow extends StatelessWidget {
  final AiClip clip;
  final ExportJob? job;
  final VoidCallback onRetry;

  const _ExportRow({required this.clip, required this.job, required this.onRetry});

  Future<void> _share(BuildContext context) async {
    final path = job?.outputPath;
    if (path == null) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }

  @override
  Widget build(BuildContext context) {
    final status = job?.status ?? ExportJobStatus.queued;

    return LuxCard(
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 20, color: LuxColors.gold),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: LuxColors.slate, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: const Icon(Icons.movie_creation_outlined, size: 18, color: LuxColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${clip.title}.mp4',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  clip.durationLabel,
                  style: LuxText.manrope(size: 11, weight: FontWeight.w600, color: LuxColors.textSecondary),
                ),
              ],
            ),
          ),
          _buildTrailing(context, status),
        ],
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, ExportJobStatus status) {
    switch (status) {
      case ExportJobStatus.queued:
        return const LuxPill(label: 'Queued', tone: LuxPillTone.neutral);
      case ExportJobStatus.processing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: LuxColors.gold),
        );
      case ExportJobStatus.done:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LuxPill(label: 'Done', tone: LuxPillTone.gold),
            const SizedBox(width: 6),
            LuxIconButton(
              icon: Icons.ios_share_rounded,
              variant: LuxIconButtonVariant.subtle,
              size: 28,
              iconSize: 15,
              onPressed: () => _share(context),
            ),
          ],
        );
      case ExportJobStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: LuxColors.error),
            const SizedBox(width: 6),
            LuxGhostButton(label: 'Retry', onPressed: onRetry),
          ],
        );
    }
  }
}
