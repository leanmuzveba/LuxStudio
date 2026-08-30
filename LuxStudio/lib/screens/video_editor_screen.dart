import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_icon_button.dart';

/// Screen 2 — Editor. Matches `ui_kit/editor/index.html` — most of its
/// spec is inline Tailwind classes in that file, not its (47-line)
/// style.css, which only supplies the custom bits (gold-gradient, glass,
/// active-dot glow, timeline-chunk, silence-gap hatch, editing-overlay
/// scrim); read the HTML directly for layout/spacing if revisiting this.
///
/// The preview frame is 9:16 (not the source recording's native 16:9) —
/// every export is center-cropped to 1080x1920 (see
/// backend/app/services/ffmpeg_client.py's export_clip), so cropping the
/// live preview to the same aspect is an accurate WYSIWYG of the final
/// output, not a mismatch with the mockup.
///
/// The transcript list (with per-line SPLIT/DELETE/HIGHLIGHT actions) is
/// new here — captions_screen.dart, which used to own inline transcript
/// editing, was retired in Phase 9 with nothing replacing it until now.
/// Only DELETE (-> [AppState.toggleMarkForCut], already real) is wired up;
/// SPLIT and HIGHLIGHT have no backing implementation yet and show a
/// "not available" message rather than pretending to work. Inline text
/// editing (fixing a transcription error) that the old screen had isn't
/// rebuilt here — a gap worth revisiting, not silently dropped.
class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _controller;
  String? _controllerUrl;
  Duration _position = Duration.zero;
  String? _seekedForClipId;

  /// Jumps playback to [start] the first time [clipId] is selected (e.g.
  /// via "Edit Clip" on the AI Clips screen) — doesn't fight the user by
  /// re-seeking on every rebuild once they've moved the playhead.
  void _seekToSelectedClipOnce(String? clipId, Duration? start) {
    if (clipId == null || start == null) return;
    if (_seekedForClipId == clipId) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _seekedForClipId = clipId;
    _seekTo(start);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _ensureController(String url) {
    if (_controllerUrl == url) return;
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();

    _controllerUrl = url;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.addListener(_onControllerUpdate);
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object _) {
      // Preview stays in its not-yet-initialized state (spinner) rather
      // than crashing the editor on an unsupported/corrupt file.
      if (mounted) setState(() {});
    });
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    setState(() => _position = controller.value.position);
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _seekTo(Duration position) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > controller.value.duration ? controller.value.duration : position);
    controller.seekTo(clamped);
  }

  /// The transcript segment containing the current playback position —
  /// drives the caption overlay text and which transcript line shows as
  /// active (with its SPLIT/DELETE/HIGHLIGHT row).
  TranscriptSegment? _currentSegment(List<TranscriptSegment> segments) {
    for (final segment in segments) {
      if (_position >= segment.start && _position < segment.end) return segment;
    }
    return null;
  }

  void _notAvailableYet(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label isn\'t available in this build yet.')),
    );
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
            if (videoUrl != null) _ensureController(videoUrl);
            _seekToSelectedClipOnce(appState.selectedClip?.id, appState.selectedClip?.start);
            final currentSegment = _currentSegment(appState.transcript);

            return Column(
              children: [
                _buildHeader(context, project),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _PreviewPane(
                    project: project,
                    controller: _controller,
                    position: _position,
                    captionText: currentSegment?.text,
                    onTogglePlay: _togglePlayback,
                  ),
                ),
                _buildToolRow(context),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF151515),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border(top: BorderSide(color: LuxColors.border)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _TimelineArea(
                          segments: appState.transcript,
                          totalDuration: project.processedDuration,
                          position: _position,
                          highlightedSegmentId: currentSegment?.id,
                          onTapSegment: (s) => _seekTo(s.start),
                        ),
                        Expanded(
                          child: appState.transcript.isEmpty
                              ? Center(
                                  child: Text(
                                    'No transcript yet.',
                                    style: LuxText.manrope(size: 12.5, color: LuxColors.textMuted),
                                  ),
                                )
                              : ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    for (final segment in appState.transcript.where((s) => !s.isSilence)) ...[
                                      _TranscriptLine(
                                        segment: segment,
                                        active: segment.id == currentSegment?.id,
                                        onTap: () => _seekTo(segment.start),
                                        onDelete: () => appState.toggleMarkForCut(segment.id),
                                        onSplit: () => _notAvailableYet('Split'),
                                        onHighlight: () => _notAvailableYet('Highlight'),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VideoProject project) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          LuxIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 16,
            size: 32,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 14, weight: FontWeight.w700),
                ),
                Text(
                  'LUXSTUDIO EDITOR',
                  style: LuxText.manrope(
                    size: 9,
                    weight: FontWeight.w700,
                    color: LuxColors.gold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(LuxRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(LuxRadii.pill),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.export),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LuxColors.goldGradient,
                  borderRadius: BorderRadius.all(Radius.circular(LuxRadii.pill)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'EXPORT',
                  style: LuxText.manrope(size: 10, weight: FontWeight.w800, color: LuxColors.background),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(child: _ToolChip(icon: Icons.text_fields_rounded, label: 'Captions', active: true, onTap: () {})),
          const SizedBox(width: 8),
          Expanded(
            child: _ToolChip(
              icon: Icons.graphic_eq_rounded,
              label: 'Audio',
              active: false,
              onTap: () => _notAvailableYet('Audio tools'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToolChip(
              icon: Icons.auto_fix_high_rounded,
              label: 'AI Cuts',
              active: false,
              onTap: () => _notAvailableYet('AI Cuts'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToolChip(
              icon: Icons.layers_outlined,
              label: 'Overlay',
              active: false,
              onTap: () => _notAvailableYet('Overlays'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToolChip({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? LuxColors.gold.withValues(alpha: 0.3) : Colors.transparent),
          ),
          child: Opacity(
            opacity: active ? 1 : 0.6,
            child: Column(
              children: [
                Icon(icon, size: 18, color: active ? LuxColors.gold : LuxColors.textSecondary),
                const SizedBox(height: 4),
                Text(
                  label.toUpperCase(),
                  style: LuxText.manrope(size: 9, weight: FontWeight.w700, color: LuxColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  final VideoProject project;
  final VideoPlayerController? controller;
  final Duration position;
  final String? captionText;
  final VoidCallback onTogglePlay;

  const _PreviewPane({
    required this.project,
    required this.controller,
    required this.position,
    required this.captionText,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    final playerController = controller;
    final ready = playerController?.value.isInitialized ?? false;
    final duration = ready ? playerController!.value.duration : project.processedDuration;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: GestureDetector(
            onTap: ready ? onTogglePlay : null,
            child: Container(
              decoration: BoxDecoration(
                color: LuxColors.playerSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: LuxColors.border),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 10))],
              ),
              clipBehavior: Clip.antiAlias,
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
                    Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white.withValues(alpha: 0.8)),
                  if (captionText != null && captionText!.trim().isNotEmpty)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 40,
                      child: Text(
                        captionText!.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: LuxText.sora(
                          size: 20,
                          weight: FontWeight.w900,
                          color: LuxColors.gold,
                          height: 1.1,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        children: [
                          Container(color: Colors.white.withValues(alpha: 0.2)),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(color: LuxColors.gold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineArea extends StatelessWidget {
  final List<TranscriptSegment> segments;
  final Duration totalDuration;
  final Duration position;
  final String? highlightedSegmentId;
  final ValueChanged<TranscriptSegment> onTapSegment;

  const _TimelineArea({
    required this.segments,
    required this.totalDuration,
    required this.position,
    required this.highlightedSegmentId,
    required this.onTapSegment,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = totalDuration.inMilliseconds == 0 ? 1 : totalDuration.inMilliseconds;
    final playheadFraction = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIMELINE',
                style: LuxText.manrope(size: 9, weight: FontWeight.w700, color: LuxColors.gold, letterSpacing: 1.2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: LuxColors.surfaceRaised, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  _fmt(position),
                  style: LuxText.manrope(size: 10, weight: FontWeight.w600, color: LuxColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (segments.isEmpty)
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  'No timeline yet.',
                  style: LuxText.manrope(size: 11.5, color: LuxColors.textMuted),
                ),
              ),
            )
          else
            SizedBox(
              height: 40,
              child: Stack(
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
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: segment.isSilence
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1A1A1A), Color(0xFF252525)],
                                      stops: [0.5, 0.5],
                                      tileMode: TileMode.repeated,
                                    ),
                                  )
                                : BoxDecoration(
                                    color: segment.isMarkedForCut
                                        ? LuxColors.textMuted.withValues(alpha: 0.35)
                                        : LuxColors.gold.withValues(alpha: isHighlighted ? 1 : 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                    border: isHighlighted ? Border.all(color: LuxColors.gold, width: 1.5) : null,
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
                        child: Container(
                          width: 2,
                          color: LuxColors.gold,
                          margin: const EdgeInsets.symmetric(vertical: -2),
                        ),
                      ),
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

class _TranscriptLine extends StatelessWidget {
  final TranscriptSegment segment;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onSplit;
  final VoidCallback onHighlight;

  const _TranscriptLine({
    required this.segment,
    required this.active,
    required this.onTap,
    required this.onDelete,
    required this.onSplit,
    required this.onHighlight,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cutStyle = segment.isMarkedForCut ? TextDecoration.lineThrough : TextDecoration.none;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(active ? 10 : 0),
        decoration: active
            ? BoxDecoration(
                color: LuxColors.gold.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: LuxColors.gold, width: 2)),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  _fmt(segment.start),
                  style: LuxText.manrope(
                    size: 9,
                    weight: FontWeight.w600,
                    color: active ? LuxColors.gold : LuxColors.textMuted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.text,
                    style: LuxText.manrope(
                      size: 13,
                      weight: active ? FontWeight.w500 : FontWeight.w400,
                      color: active ? LuxColors.textPrimary : LuxColors.textSecondary,
                    ).copyWith(decoration: cutStyle),
                  ),
                  if (active) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _ActionLabel(label: 'SPLIT', onTap: onSplit),
                        const SizedBox(width: 14),
                        _ActionLabel(
                          label: segment.isMarkedForCut ? 'UNDO' : 'DELETE',
                          onTap: onDelete,
                        ),
                        const SizedBox(width: 14),
                        _ActionLabel(label: 'HIGHLIGHT', onTap: onHighlight),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionLabel({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: LuxText.manrope(size: 9, weight: FontWeight.w700, color: LuxColors.gold)),
    );
  }
}
