import 'package:flutter/material.dart';

import '../main.dart';
import '../models/ai_clip.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../utils/error_presenter.dart';
import '../widgets/desktop_shell_scaffold.dart';

/// Desktop AI Highlights — matches `ui_kit/ai_highlights_desktop/`'s
/// segments-grid + reels-panel layout, wired to the same
/// [AppState.suggestedClips] as the mobile [AiClipsScreen] rather than the
/// mockup's hardcoded 4-card demo.
///
/// Scope cuts vs. the mockup (documented, not silently dropped):
/// - **"Smart Highlight Reels"** has no real backing feature (no clip-
///   grouping/reel-stitching entity exists anywhere in this app) — rather
///   than fabricate fake "6 clips · 03:45 · 96% Conf." cards, the panel
///   groups the *real* [AppState.suggestedClips] by their real Gemini-
///   provided [AiClip.category] tag, with real per-group clip count/total
///   duration/top score. "Preview Reel" opens the group's top clip in the
///   Editor (same real action as a card's edit button) rather than
///   pretending to stitch and play a combined video.
/// - The footer's fake CPU/GPU/RAM telemetry is dropped — nothing in a
///   Flutter Web app can read real system stats — replaced with real
///   analyse-pipeline status and clip count.
/// - The right-panel drag-to-resize handle is a static divider here, not
///   draggable — cosmetic-only in the mockup itself, not worth the extra
///   gesture-handling surface for this pass.
/// - "Refresh Analysis" and "Generate All Clips" are the same one real
///   action ([AppState.generateClipSuggestions]) in this backend — kept as
///   a single button rather than two that would do the same thing.
class AiHighlightsDesktopScreen extends StatelessWidget {
  const AiHighlightsDesktopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return ColoredBox(
      color: LuxColors.background,
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final clips = List<AiClip>.from(appState.suggestedClips)
            ..sort((a, b) => b.viralScore.compareTo(a.viralScore));
          final reels = _groupIntoReels(clips);

          return Column(
            children: [
              _Header(
                projectTitle: appState.project?.title,
                busy: appState.isGeneratingClips,
                onRefresh: appState.project == null || appState.isGeneratingClips
                    ? null
                    : appState.generateClipSuggestions,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: appState.isGeneratingClips
                          ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
                          : clips.isEmpty
                              ? _EmptyState(
                                  hasTranscript: appState.transcript.isNotEmpty,
                                  error: appState.clipGenerationError,
                                )
                              : _SegmentsPane(
                                  clips: clips,
                                  onEdit: (clip) => _openInEditor(context, appState, clip),
                                  onAddToShare: (clip) => _openInShare(context, appState, clip),
                                ),
                    ),
                    const VerticalDivider(width: 1, color: LuxColors.border),
                    SizedBox(
                      width: 380,
                      child: _ReelsPane(
                        reels: reels,
                        onPreview: (reel) => _openInEditor(context, appState, reel.topClip),
                      ),
                    ),
                  ],
                ),
              ),
              _Footer(
                engineActive: appState.isGeneratingClips,
                clipCount: clips.length,
                projectDuration: appState.project?.processedDuration,
              ),
            ],
          );
        },
      ),
    );
  }

  void _openInEditor(BuildContext context, AppState appState, AiClip clip) {
    appState.chooseClip(clip);
    final selectTab = DesktopShellScope.maybeSelectTabOf(context);
    if (selectTab != null) {
      selectTab(DesktopShellScope.editorTabIndex);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.editor);
    }
  }

  void _openInShare(BuildContext context, AppState appState, AiClip clip) {
    appState.chooseClip(clip);
    Navigator.of(context).pushNamed(AppRoutes.share);
  }

  List<_Reel> _groupIntoReels(List<AiClip> clips) {
    final byCategory = <String, List<AiClip>>{};
    for (final clip in clips) {
      final key = clip.category.trim().isEmpty ? 'AI Picks' : clip.category.trim();
      byCategory.putIfAbsent(key, () => []).add(clip);
    }
    final reels = byCategory.entries.map((e) => _Reel(label: e.key, clips: e.value)).toList();
    reels.sort((a, b) => b.topScore.compareTo(a.topScore));
    return reels;
  }
}

/// A real derived grouping of [AppState.suggestedClips] by category — see
/// [AiHighlightsDesktopScreen]'s scope-cut note.
class _Reel {
  final String label;
  final List<AiClip> clips;

  _Reel({required this.label, required this.clips});

  Duration get totalDuration => clips.fold(Duration.zero, (sum, c) => sum + c.duration);
  int get topScore => clips.isEmpty ? 0 : clips.map((c) => c.viralScore).reduce((a, b) => a > b ? a : b);
  AiClip get topClip => clips.reduce((a, b) => a.viralScore >= b.viralScore ? a : b);
}

class _Header extends StatelessWidget {
  final String? projectTitle;
  final bool busy;
  final VoidCallback? onRefresh;

  const _Header({required this.projectTitle, required this.busy, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.border))),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 18, color: LuxColors.gold),
          const SizedBox(width: 8),
          Text('AI Highlights Engine', style: LuxText.manrope(size: 15.5, weight: FontWeight.w700)),
          if (projectTitle != null) ...[
            const SizedBox(width: 16),
            Container(width: 1, height: 16, color: LuxColors.border),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                'Processing: $projectTitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LuxText.manrope(size: 12, color: LuxColors.textSecondary),
              ),
            ),
          ],
          const Spacer(),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: onRefresh == null ? null : LuxColors.goldGradient,
                  color: onRefresh == null ? LuxColors.surfaceRaised : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: LuxColors.background),
                      )
                    else
                      Icon(Icons.refresh_rounded, size: 16, color: onRefresh == null ? LuxColors.textMuted : LuxColors.background),
                    const SizedBox(width: 7),
                    Text(
                      busy ? 'Analysing…' : 'Refresh Analysis',
                      style: LuxText.manrope(
                        size: 13,
                        weight: FontWeight.w700,
                        color: onRefresh == null ? LuxColors.textMuted : LuxColors.background,
                      ),
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

class _EmptyState extends StatelessWidget {
  final bool hasTranscript;
  final String? error;
  const _EmptyState({required this.hasTranscript, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 36, color: LuxColors.borderStrong),
            const SizedBox(height: 16),
            Text(
              hasTranscript
                  ? 'No clips yet — Refresh Analysis once analysis finishes.'
                  : 'Run Analyse on this project first — the AI reads the transcript to find complete, engaging moments.',
              textAlign: TextAlign.center,
              style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(friendlyError(error), textAlign: TextAlign.center, style: LuxText.manrope(size: 12, color: LuxColors.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentsPane extends StatelessWidget {
  final List<AiClip> clips;
  final ValueChanged<AiClip> onEdit;
  final ValueChanged<AiClip> onAddToShare;

  const _SegmentsPane({required this.clips, required this.onEdit, required this.onAddToShare});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detected Viral Segments', style: LuxText.sora(size: 19, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            "Our AI analyzed the transcript for emotional peaks and key transitions to find these ${clips.length} clip${clips.length == 1 ? '' : 's'}.",
            style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1.55,
            ),
            itemCount: clips.length,
            itemBuilder: (context, i) => _SegmentCard(
              clip: clips[i],
              index: i + 1,
              onEdit: () => onEdit(clips[i]),
              onAddToShare: () => onAddToShare(clips[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final AiClip clip;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onAddToShare;

  const _SegmentCard({required this.clip, required this.index, required this.onEdit, required this.onAddToShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LuxColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: LuxColors.playerSurface, borderRadius: BorderRadius.circular(10)),
                ),
                Center(
                  child: Text('S$index', style: LuxText.sora(size: 26, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.1))),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                    child: Text(clip.durationLabel, style: LuxText.manrope(size: 9.5, color: LuxColors.textPrimary)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: LuxColors.gold.withValues(alpha: 0.1),
                          border: Border.all(color: LuxColors.gold.withValues(alpha: 0.25)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (clip.category.isEmpty ? 'AI Pick' : clip.category).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LuxText.manrope(size: 9, weight: FontWeight.w700, color: LuxColors.gold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ConfidenceRing(score: clip.viralScore),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  clip.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 13.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    clip.reason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: LuxText.manrope(size: 11.5, color: LuxColors.textSecondary, height: 1.35),
                  ),
                ),
                const Divider(height: 16, color: LuxColors.borderDashed),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clip.timeRangeLabel,
                        style: LuxText.manrope(size: 10, color: LuxColors.tan),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.edit_outlined, size: 15, color: LuxColors.textSecondary),
                      tooltip: 'Edit Clip',
                      onPressed: onEdit,
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.ios_share_rounded, size: 15, color: LuxColors.textSecondary),
                      tooltip: 'Add to Share',
                      onPressed: onAddToShare,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceRing extends StatelessWidget {
  final int score;
  const _ConfidenceRing({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 3,
            backgroundColor: LuxColors.surfaceRaised,
            color: LuxColors.gold,
          ),
          Text('$score', style: LuxText.manrope(size: 9.5, weight: FontWeight.w700, color: LuxColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ReelsPane extends StatelessWidget {
  final List<_Reel> reels;
  final ValueChanged<_Reel> onPreview;

  const _ReelsPane({required this.reels, required this.onPreview});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LuxColors.surfaceRaised.withValues(alpha: 0.15),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up_rounded, size: 16, color: LuxColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Highlight Reels by Theme',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LuxText.manrope(size: 13.5, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Real suggested clips grouped by the AI\'s own category tags.',
              style: LuxText.manrope(size: 11, color: LuxColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (reels.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Reels appear once clips are found.',
                  style: LuxText.manrope(size: 12, color: LuxColors.textSecondary),
                ),
              )
            else
              for (final reel in reels) ...[
                _ReelCard(reel: reel, onPreview: () => onPreview(reel)),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _ReelCard extends StatelessWidget {
  final _Reel reel;
  final VoidCallback onPreview;

  const _ReelCard({required this.reel, required this.onPreview});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LuxColors.background.withValues(alpha: 0.6),
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: LuxColors.gold.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Icon(Icons.movie_filter_outlined, size: 16, color: LuxColors.gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reel.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: LuxText.manrope(size: 12.5, weight: FontWeight.w700)),
                    Text(
                      '${reel.clips.length} clip${reel.clips.length == 1 ? '' : 's'} · ${_fmt(reel.totalDuration)} total',
                      style: LuxText.manrope(size: 10, color: LuxColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${reel.topScore}%', style: LuxText.manrope(size: 11, weight: FontWeight.w700, color: LuxColors.gold)),
                  Text('TOP SCORE', style: LuxText.manrope(size: 7.5, weight: FontWeight.w700, color: LuxColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < reel.clips.length; i++) ...[
                Expanded(
                  flex: (reel.clips[i].viralScore).clamp(1, 100),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: LuxColors.gold.withValues(alpha: 0.3 + (reel.clips[i].viralScore / 100) * 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (i != reel.clips.length - 1) const SizedBox(width: 3),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: LuxColors.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onPreview,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                child: Text(
                  'PREVIEW TOP CLIP',
                  style: LuxText.manrope(size: 10.5, weight: FontWeight.w700, color: LuxColors.textPrimary, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool engineActive;
  final int clipCount;
  final Duration? projectDuration;

  const _Footer({required this.engineActive, required this.clipCount, required this.projectDuration});

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: LuxColors.border))),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: engineActive ? LuxColors.gold : LuxColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            engineActive ? 'ENGINE ACTIVE' : 'ENGINE IDLE',
            style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: LuxColors.textPrimary, letterSpacing: 1),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 14, color: LuxColors.border),
          const SizedBox(width: 16),
          Text(
            '$clipCount clip${clipCount == 1 ? '' : 's'} found',
            style: LuxText.manrope(size: 10.5, color: LuxColors.textSecondary),
          ),
          const Spacer(),
          if (projectDuration != null)
            Text(
              'Project Duration: ${_fmt(projectDuration!)}',
              style: LuxText.manrope(size: 10.5, color: LuxColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
