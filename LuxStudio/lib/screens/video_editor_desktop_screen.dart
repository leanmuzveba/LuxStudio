import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/ai_clip.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../utils/error_presenter.dart';
import '../widgets/video_scrub_mixin.dart';

/// Desktop-shaped Editor — matches `ui_kit/editor_desktop/index.html`'s
/// tool-rail / preview+timeline / AI-insights three-pane layout, wired to
/// the same [AppState] as the mobile [VideoEditorScreen] rather than
/// reimplementing playback (shares [VideoScrubMixin]).
///
/// Deliberate scope cuts vs. the mockup (see PIVOT_PLAN_V2.md Phase 26):
/// - Tool rail: only "Select" (the do-nothing default mode) is real; Cut/
///   Crop/Pan show a "not available" message, same treatment as mobile's
///   inert Audio/AI Cuts/Overlay tool chips.
/// - Timeline: only the VIDEO track is real (transcript-driven, like
///   mobile's timeline). AUDIO/SUBS rows are drawn empty for visual parity
///   with the mockup, not wired to anything — no real multi-track editing
///   is scoped yet.
/// - The mockup's fake "12 clips" AI panel is replaced with the project's
///   *real* [AppState.suggestedClips]; "ADD TO CLIP" (a toggle with no
///   backend meaning) is replaced with a real "Edit Clip" action —
///   [AppState.chooseClip] plus a seek, same as the mobile AI Clips screen.
/// - The mockup's preview area is a wide placeholder box; the real preview
///   stays 9:16 (see [VideoEditorScreen]'s own note — every export is
///   center-cropped to 1080x1920) so it's an accurate WYSIWYG, just sized
///   to fit the wider desktop pane instead of stretched to match the mock.
class VideoEditorDesktopScreen extends StatefulWidget {
  const VideoEditorDesktopScreen({super.key});

  @override
  State<VideoEditorDesktopScreen> createState() => _VideoEditorDesktopScreenState();
}

class _VideoEditorDesktopScreenState extends State<VideoEditorDesktopScreen>
    with VideoScrubMixin<VideoEditorDesktopScreen> {
  String? _seekedForClipId;
  double _volume = 1.0;

  void _seekToSelectedClipOnce(String? clipId, Duration? start) {
    if (clipId == null || start == null) return;
    if (_seekedForClipId == clipId) return;
    if (controller == null || !controller!.value.isInitialized) return;
    _seekedForClipId = clipId;
    seekTo(start);
  }

  @override
  void dispose() {
    disposeVideoScrub();
    super.dispose();
  }

  TranscriptSegment? _currentSegment(List<TranscriptSegment> segments) {
    for (final segment in segments) {
      if (position >= segment.start && position < segment.end) return segment;
    }
    return null;
  }

  void _notAvailableYet(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label isn\'t available in this build yet.')),
    );
  }

  void _setVolume(double value) {
    setState(() => _volume = value);
    controller?.setVolume(value);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return ColoredBox(
      color: LuxColors.background,
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final project = appState.project;
          if (project == null) {
            return Center(
              child: Text(
                'No project loaded yet — go import a video first.',
                style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
              ),
            );
          }
          final videoUrl = appState.currentVideoUrl;
          if (videoUrl != null) ensureController(videoUrl);
          _seekToSelectedClipOnce(appState.selectedClip?.id, appState.selectedClip?.start);
          final currentSegment = _currentSegment(appState.transcript);

          return Column(
            children: [
              _Header(project: project, analyseStatus: appState.analyseStatus),
              Expanded(
                child: Row(
                  children: [
                    _ToolRail(onInertTap: _notAvailableYet),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Expanded(
                              child: _DesktopPreviewPane(
                                controller: controller,
                                position: position,
                                captionText: currentSegment?.text,
                                volume: _volume,
                                onTogglePlay: togglePlayback,
                                onVolumeChanged: _setVolume,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _DesktopTimeline(
                              segments: appState.transcript,
                              totalDuration: project.processedDuration,
                              position: position,
                              highlightedSegmentId: currentSegment?.id,
                              onTapSegment: (s) => seekTo(s.start),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _InsightsPanel(
                      clips: appState.suggestedClips,
                      loading: appState.isGeneratingClips,
                      hasTranscript: appState.transcript.isNotEmpty,
                      error: appState.clipGenerationError,
                      onRescan: appState.isGeneratingClips ? null : appState.generateClipSuggestions,
                      onEditClip: (clip) => appState.chooseClip(clip),
                    ),
                  ],
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
  final VideoProject project;
  final String analyseStatus;

  const _Header({required this.project, required this.analyseStatus});

  @override
  Widget build(BuildContext context) {
    final badgeLabel = switch (analyseStatus) {
      'running' => 'ANALYSING',
      'done' => 'READY',
      'error' => 'ANALYSE FAILED',
      _ => 'DRAFT',
    };

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.border))),
      child: Row(
        children: [
          Flexible(
            child: Text(
              project.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LuxText.manrope(size: 15.5, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: LuxColors.gold.withValues(alpha: 0.08),
              border: Border.all(color: LuxColors.gold.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              badgeLabel,
              style: LuxText.manrope(size: 10.5, weight: FontWeight.w700, color: LuxColors.gold2, letterSpacing: 0.5),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.share),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: const BoxDecoration(
                  gradient: LuxColors.goldGradient,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.ios_share_rounded, size: 15, color: LuxColors.background),
                    const SizedBox(width: 7),
                    Text(
                      'Export',
                      style: LuxText.manrope(size: 13.5, weight: FontWeight.w700, color: LuxColors.background),
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

class _ToolRail extends StatelessWidget {
  final void Function(String label) onInertTap;
  const _ToolRail({required this.onInertTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: LuxColors.borderDashed))),
      child: Column(
        children: [
          _ToolRailButton(icon: Icons.near_me_rounded, active: true, tooltip: 'Select', onTap: () {}),
          const SizedBox(height: 8),
          _ToolRailButton(
            icon: Icons.content_cut_rounded,
            active: false,
            tooltip: 'Cut',
            onTap: () => onInertTap('Cut'),
          ),
          const SizedBox(height: 8),
          _ToolRailButton(
            icon: Icons.crop_rounded,
            active: false,
            tooltip: 'Crop / Select region',
            onTap: () => onInertTap('Crop'),
          ),
          const SizedBox(height: 8),
          _ToolRailButton(
            icon: Icons.pan_tool_alt_outlined,
            active: false,
            tooltip: 'Pan',
            onTap: () => onInertTap('Pan'),
          ),
        ],
      ),
    );
  }
}

class _ToolRailButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolRailButton({required this.icon, required this.active, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? LuxColors.gold.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 17, color: active ? LuxColors.gold2 : LuxColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _DesktopPreviewPane extends StatelessWidget {
  final VideoPlayerController? controller;
  final Duration position;
  final String? captionText;
  final double volume;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onVolumeChanged;

  const _DesktopPreviewPane({
    required this.controller,
    required this.position,
    required this.captionText,
    required this.volume,
    required this.onTogglePlay,
    required this.onVolumeChanged,
  });

  String _timecode(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final playerController = controller;
    final ready = playerController?.value.isInitialized ?? false;
    final duration = ready ? playerController!.value.duration : Duration.zero;

    return Container(
      decoration: BoxDecoration(
        color: LuxColors.surfaceRaised,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: GestureDetector(
                  onTap: ready ? onTogglePlay : null,
                  child: Container(
                    color: LuxColors.playerSurface,
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        if (ready)
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: playerController!.value.size.width,
                              height: playerController.value.size.height,
                              child: VideoPlayer(playerController),
                            ),
                          )
                        else
                          const Icon(Icons.movie_creation_outlined, size: 40, color: LuxColors.borderStrong),
                        if (!ready)
                          const CircularProgressIndicator(color: LuxColors.gold)
                        else if (!playerController!.value.isPlaying)
                          Icon(Icons.play_arrow_rounded, size: 48, color: Colors.white.withValues(alpha: 0.8)),
                        if (captionText != null && captionText!.trim().isNotEmpty)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 36,
                            child: Text(
                              captionText!.toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: LuxText.sora(
                                size: 18,
                                weight: FontWeight.w900,
                                color: LuxColors.gold,
                                height: 1.1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: LuxColors.borderDashed))),
            child: Row(
              children: [
                IconButton(
                  onPressed: ready ? onTogglePlay : null,
                  icon: Icon(
                    (playerController?.value.isPlaying ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: LuxColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    border: Border.all(color: LuxColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_timecode(position)} / ${_timecode(duration)}',
                    style: LuxText.manrope(size: 12, weight: FontWeight.w600, color: LuxColors.textPrimary),
                  ),
                ),
                const Spacer(),
                Icon(
                  volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 18,
                  color: LuxColors.textSecondary,
                ),
                SizedBox(
                  width: 110,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: LuxColors.gold,
                      inactiveTrackColor: LuxColors.border,
                      thumbColor: LuxColors.gold2,
                    ),
                    child: Slider(value: volume, onChanged: onVolumeChanged),
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

class _DesktopTimeline extends StatelessWidget {
  final List<TranscriptSegment> segments;
  final Duration totalDuration;
  final Duration position;
  final String? highlightedSegmentId;
  final ValueChanged<TranscriptSegment> onTapSegment;

  const _DesktopTimeline({
    required this.segments,
    required this.totalDuration,
    required this.position,
    required this.highlightedSegmentId,
    required this.onTapSegment,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = totalDuration.inMilliseconds == 0 ? 1 : totalDuration.inMilliseconds;
    final playheadFraction = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: LuxColors.background,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.borderDashed))),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 13, color: LuxColors.gold),
                const SizedBox(width: 6),
                Text('TIMELINE', style: LuxText.manrope(size: 11, weight: FontWeight.w700)),
                const Spacer(),
                Text(_fmt(position), style: LuxText.manrope(size: 11, color: LuxColors.textMuted)),
              ],
            ),
          ),
          _TrackRow(
            label: 'VIDEO 1',
            icon: Icons.movie_outlined,
            child: segments.isEmpty
                ? Center(
                    child: Text('No timeline yet.', style: LuxText.manrope(size: 11.5, color: LuxColors.textMuted)),
                  )
                : Stack(
                    children: [
                      Row(
                        children: segments.map((segment) {
                          final flex = ((segment.duration.inMilliseconds / totalMs) * 1000).clamp(4, 1000).round();
                          final isHighlighted = segment.id == highlightedSegmentId;
                          return Expanded(
                            flex: flex,
                            child: GestureDetector(
                              onTap: () => onTapSegment(segment),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 6),
                                decoration: segment.isSilence
                                    ? BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: LuxColors.surfaceDashed,
                                      )
                                    : BoxDecoration(
                                        color: segment.isMarkedForCut
                                            ? LuxColors.textMuted.withValues(alpha: 0.35)
                                            : LuxColors.gold.withValues(alpha: isHighlighted ? 1 : 0.28),
                                        borderRadius: BorderRadius.circular(4),
                                        border:
                                            isHighlighted ? Border.all(color: LuxColors.gold, width: 1.5) : null,
                                      ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: playheadFraction,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(width: 2, color: LuxColors.gold2),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const _TrackRow(label: 'AUDIO 1', icon: Icons.graphic_eq_rounded, child: SizedBox.shrink()),
          const _TrackRow(label: 'SUBS', icon: Icons.subtitles_outlined, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _TrackRow({required this.label, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Container(
            width: 96,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: LuxColors.surfaceRaised,
              border: Border(
                right: BorderSide(color: LuxColors.borderDashed),
                bottom: BorderSide(color: LuxColors.borderDashed),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: LuxColors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: LuxText.manrope(size: 10.5, weight: FontWeight.w700, color: LuxColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.borderDashed))),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  final List<AiClip> clips;
  final bool loading;
  final bool hasTranscript;
  final String? error;
  final VoidCallback? onRescan;
  final ValueChanged<AiClip> onEditClip;

  const _InsightsPanel({
    required this.clips,
    required this.loading,
    required this.hasTranscript,
    required this.error,
    required this.onRescan,
    required this.onEditClip,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<AiClip>.from(clips)..sort((a, b) => b.viralScore.compareTo(a.viralScore));

    return Container(
      width: 280,
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: LuxColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 16, color: LuxColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('AI Clip Insights', style: LuxText.manrope(size: 14.5, weight: FontWeight.w700)),
                    ),
                    if (onRescan != null)
                      TextButton.icon(
                        onPressed: onRescan,
                        icon: const Icon(Icons.refresh_rounded, size: 13, color: LuxColors.gold2),
                        label: Text('Re-scan', style: LuxText.manrope(size: 12.5, weight: FontWeight.w700, color: LuxColors.gold2)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  clips.isEmpty
                      ? "We'll surface viral-ready segments here once analysis finds some."
                      : "We've identified ${clips.length} viral-ready segment${clips.length == 1 ? '' : 's'}.",
                  style: LuxText.manrope(size: 12.5, color: LuxColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: LuxColors.borderDashed),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
                : sorted.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasTranscript
                                  ? 'No clips yet — try Re-scan once analysis finishes.'
                                  : 'Run Analyse on this project first.',
                              textAlign: TextAlign.center,
                              style: LuxText.manrope(size: 12.5, color: LuxColors.textSecondary),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                friendlyError(error),
                                textAlign: TextAlign.center,
                                style: LuxText.manrope(size: 11.5, color: LuxColors.error),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, i) => _ClipInsightCard(
                          clip: sorted[i],
                          index: i + 1,
                          onEditClip: () => onEditClip(sorted[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ClipInsightCard extends StatelessWidget {
  final AiClip clip;
  final int index;
  final VoidCallback onEditClip;

  const _ClipInsightCard({required this.clip, required this.index, required this.onEditClip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LuxColors.surface,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            decoration: const BoxDecoration(color: LuxColors.surfaceDashed),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    'S$index',
                    style: LuxText.sora(size: 26, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.12)),
                  ),
                ),
                if (clip.category.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: LuxColors.gold, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        clip.category.toUpperCase(),
                        style: LuxText.manrope(size: 9, weight: FontWeight.w800, color: LuxColors.background),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      clip.durationLabel,
                      style: LuxText.manrope(size: 10.5, weight: FontWeight.w700, color: LuxColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clip.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: LuxText.manrope(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  clip.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 11.5, color: LuxColors.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        clip.timeRangeLabel,
                        overflow: TextOverflow.ellipsis,
                        style: LuxText.manrope(size: 10.5, color: LuxColors.tan),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: LuxColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: onEditClip,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            'Edit Clip',
                            style: LuxText.manrope(size: 10.5, weight: FontWeight.w700, color: LuxColors.textPrimary),
                          ),
                        ),
                      ),
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
