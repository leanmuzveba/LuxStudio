import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';
import '../services/project_dashboard.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_chip.dart';
import '../widgets/lux_icon_button.dart';

/// Screen 2 — Video Editor.
///
/// A 16:9 preview of the source recording (transport controls + a live
/// burned-in-look caption overlay) over a segment timeline, with a sticky
/// row of chips handing off to the four dedicated tool screens (Remove
/// Silence / Captions / Generate Clips / Branding) instead of in-screen
/// tabs.
///
/// Owns the [VideoPlayerController] for the project's
/// [VideoProject.workingPath] (recreated if that path changes, e.g. once
/// silence removal produces a new trimmed file) so play/pause and
/// timeline-tap-to-seek both work against one real, live player.
class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _controller;
  String? _controllerPath;
  Duration _position = Duration.zero;

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _ensureController(String path) {
    if (_controllerPath == path) return;
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();

    _controllerPath = path;
    final controller = VideoPlayerController.file(File(path));
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

  void _skip(Duration delta) => _seekTo(_position + delta);

  /// The transcript segment containing the current playback position —
  /// drives the caption overlay text and the timeline's highlighted block.
  TranscriptSegment? _currentSegment(List<TranscriptSegment> segments) {
    for (final segment in segments) {
      if (_position >= segment.start && _position < segment.end) return segment;
    }
    return null;
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
            _ensureController(project.workingPath);
            final currentSegment = _currentSegment(appState.transcript);

            return Column(
              children: [
                _buildAppBar(context, project),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: _PreviewPane(
                            project: project,
                            controller: _controller,
                            position: _position,
                            captionText: currentSegment?.text,
                            onTogglePlay: _togglePlayback,
                          ),
                        ),
                        _buildTransport(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                          child: _TimelineArea(
                            segments: appState.transcript,
                            silenceRanges: appState.silenceRanges,
                            totalDuration: project.processedDuration,
                            highlightedSegmentId: currentSegment?.id,
                            onTapSegment: (s) => _seekTo(s.start),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildChipRow(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, VideoProject project) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 10),
      child: Row(
        children: [
          LuxIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 18,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 15, weight: FontWeight.w700),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: LuxColors.success),
                    const SizedBox(width: 4),
                    Text(
                      relativeUpdatedLabel(project.updatedAt).replaceFirst('Updated', 'Saved'),
                      style: LuxText.manrope(size: 12, weight: FontWeight.w500, color: LuxColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          LuxIconButton(
            icon: Icons.undo_rounded,
            variant: LuxIconButtonVariant.subtle,
            tooltip: 'Undo silence removal',
            onPressed: () {
              final appState = AppStateScope.of(context);
              if (appState.project?.workingPath == appState.project?.sourcePath) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Nothing to undo yet.')));
                return;
              }
              appState.restoreOriginalAudio();
            },
          ),
          LuxIconButton(
            icon: Icons.ios_share_rounded,
            variant: LuxIconButtonVariant.filledGold,
            tooltip: 'Export',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.export),
          ),
        ],
      ),
    );
  }

  Widget _buildTransport() {
    final controller = _controller;
    final ready = controller?.value.isInitialized ?? false;
    final duration = ready ? controller!.value.duration : Duration.zero;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: LuxColors.gold,
              inactiveTrackColor: LuxColors.borderStrong,
              thumbColor: LuxColors.gold,
              overlayColor: LuxColors.gold.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: (ready ? _position.inMilliseconds.toDouble() : 0.0)
                  .clamp(0.0, duration.inMilliseconds.toDouble().clamp(1.0, double.infinity)),
              max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
              onChanged: ready ? (v) => _seekTo(Duration(milliseconds: v.round())) : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LuxIconButton(
                icon: Icons.replay_10_rounded,
                onPressed: ready ? () => _skip(const Duration(seconds: -10)) : null,
              ),
              const SizedBox(width: 22),
              LuxIconButton(
                icon: (controller?.value.isPlaying ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                variant: LuxIconButtonVariant.filledGold,
                size: 46,
                iconSize: 22,
                onPressed: ready ? _togglePlayback : null,
              ),
              const SizedBox(width: 22),
              LuxIconButton(
                icon: Icons.forward_10_rounded,
                onPressed: ready ? () => _skip(const Duration(seconds: 10)) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipRow(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: LuxColors.background,
        border: Border(top: BorderSide(color: LuxColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            LuxChip(
              label: 'Remove Silence',
              icon: Icons.content_cut_rounded,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.silence),
            ),
            const SizedBox(width: 8),
            LuxChip(
              label: 'Captions',
              icon: Icons.closed_caption_rounded,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.captions),
            ),
            const SizedBox(width: 8),
            LuxChip(
              label: 'Generate Clips',
              icon: Icons.auto_awesome_rounded,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.clips),
            ),
            const SizedBox(width: 8),
            LuxChip(
              label: 'Branding',
              icon: Icons.palette_outlined,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.branding),
            ),
          ],
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

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: LuxColors.playerSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LuxColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onTap: ready ? onTogglePlay : null,
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
                const Icon(Icons.play_circle_fill_rounded, size: 52, color: Colors.white70),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_fmt(position)} / ${_fmt(duration)}',
                    style: LuxText.manrope(size: 11, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              if (captionText != null && captionText!.trim().isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        captionText!.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: LuxText.sora(size: 12.5, weight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _TimelineArea extends StatelessWidget {
  final List<TranscriptSegment> segments;
  final List<dynamic> silenceRanges;
  final Duration totalDuration;
  final String? highlightedSegmentId;
  final ValueChanged<TranscriptSegment> onTapSegment;

  const _TimelineArea({
    required this.segments,
    required this.silenceRanges,
    required this.totalDuration,
    required this.highlightedSegmentId,
    required this.onTapSegment,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Transcribe captions to see the segment timeline here.',
          textAlign: TextAlign.center,
          style: LuxText.manrope(size: 12.5, color: LuxColors.textMuted),
        ),
      );
    }

    final totalMs = totalDuration.inMilliseconds == 0 ? 1 : totalDuration.inMilliseconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: segments.map((segment) {
              final flex = ((segment.duration.inMilliseconds / totalMs) * 1000).clamp(4, 1000).round();
              final isHighlighted = segment.id == highlightedSegmentId;
              return Expanded(
                flex: flex,
                child: GestureDetector(
                  onTap: () => onTapSegment(segment),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: segment.isSilence
                          ? LuxColors.surfaceRaised
                          : segment.isMarkedForCut
                              ? LuxColors.textMuted.withValues(alpha: 0.35)
                              : LuxColors.amber.withValues(alpha: isHighlighted ? 1 : 0.7),
                      borderRadius: BorderRadius.circular(3),
                      border: isHighlighted ? Border.all(color: LuxColors.gold, width: 1.5) : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (silenceRanges.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${silenceRanges.length} silent gap${silenceRanges.length == 1 ? '' : 's'} detected',
            style: LuxText.manrope(size: 11, weight: FontWeight.w600, color: LuxColors.textMuted),
          ),
        ],
      ],
    );
  }
}
