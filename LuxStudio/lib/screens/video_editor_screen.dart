import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/timeline_strip.dart';
import '../widgets/transcript_list.dart';

/// Screen 2 — Video Editor.
///
/// Vertical preview pane up top, a 4-tab tool bar (Captions / Audio /
/// AI Cuts / Overlays) driving a swappable bottom panel, a scrubber
/// timeline showing audio chunks & silence gaps, and — in the Captions
/// tab — the full editable transcript.
///
/// Owns the [VideoPlayerController] for the project's [VideoProject.workingPath]
/// (recreated if that path changes, e.g. once silence removal produces a
/// new trimmed file) so play/pause and timeline-tap-to-seek both work
/// against one real, live player.
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
    _controller?.seekTo(position);
  }

  /// The transcript segment containing the current playback position, so
  /// the timeline strip can highlight it.
  String? _currentSegmentId(List<TranscriptSegment> segments) {
    for (final segment in segments) {
      if (_position >= segment.start && _position < segment.end) return segment.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.clips),
            child: const Text('Next: AI Clips'),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final project = appState.project;
          if (project == null) {
            return const Center(
              child: Text(
                'No project loaded yet — go import a video first.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          _ensureController(project.workingPath);
          return Column(
            children: [
              Expanded(
                child: _PreviewPane(
                  project: project,
                  controller: _controller,
                  onTogglePlay: _togglePlayback,
                ),
              ),
              _buildTimelineArea(context, appState, project),
              _ToolBar(
                active: appState.activeTool,
                onSelect: appState.setActiveTool,
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineArea(BuildContext context, AppState appState, VideoProject project) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimelineStrip(
            segments: appState.transcript,
            totalDuration: project.processedDuration,
            highlightedSegmentId: _currentSegmentId(appState.transcript),
            onTapSegment: (segment) => _seekTo(segment.start),
          ),
          const SizedBox(height: Gaps.sm),
          SizedBox(
            height: 260,
            child: _ToolPanel(appState: appState),
          ),
        ],
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  final VideoProject project;
  final VideoPlayerController? controller;
  final VoidCallback onTogglePlay;

  const _PreviewPane({
    required this.project,
    required this.controller,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    final playerController = controller;
    final ready = playerController?.value.isInitialized ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
      child: Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
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
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF23212B), Color(0xFF14131A)],
                        ),
                      ),
                    ),
                  if (!ready)
                    const CircularProgressIndicator(color: Colors.white70)
                  else if (!playerController!.value.isPlaying)
                    const Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white70),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        project.fileName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
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

class _ToolBar extends StatelessWidget {
  final EditorTool active;
  final ValueChanged<EditorTool> onSelect;

  const _ToolBar({required this.active, required this.onSelect});

  static const _items = [
    (EditorTool.captions, Icons.closed_caption_rounded, 'Captions'),
    (EditorTool.audio, Icons.graphic_eq_rounded, 'Audio'),
    (EditorTool.aiCuts, Icons.auto_awesome_rounded, 'AI Cuts'),
    (EditorTool.overlays, Icons.layers_rounded, 'Overlays'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: _items.map((item) {
          final (tool, icon, label) = item;
          final isActive = tool == active;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(tool),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isActive ? AppColors.accent : AppColors.textMuted,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ToolPanel extends StatelessWidget {
  final AppState appState;

  const _ToolPanel({required this.appState});

  @override
  Widget build(BuildContext context) {
    switch (appState.activeTool) {
      case EditorTool.captions:
        return _CaptionsPanel(appState: appState);
      case EditorTool.audio:
        return _AudioPanel(appState: appState);
      case EditorTool.aiCuts:
        return _AiCutsPanel(appState: appState);
      case EditorTool.overlays:
        return const _OverlaysPanel();
    }
  }
}

/// Transcribe (via Gemini) → real, editable transcript. [TranscriptList]
/// already supports correcting text and marking lines for removal — this
/// just decides which state to show it in.
class _CaptionsPanel extends StatelessWidget {
  final AppState appState;

  const _CaptionsPanel({required this.appState});

  @override
  Widget build(BuildContext context) {
    if (appState.isTranscribing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: Gaps.sm),
            Text('Transcribing…', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    if (appState.transcript.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.closed_caption_rounded, size: 32, color: AppColors.textMuted),
            const SizedBox(height: Gaps.sm),
            const Text(
              'Transcribe this recording to generate editable captions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            if (appState.transcriptionError != null) ...[
              const SizedBox(height: Gaps.sm),
              Text(
                appState.transcriptionError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: Gaps.md),
            GradientButton(
              label: 'Transcribe',
              icon: Icons.mic_rounded,
              expand: false,
              onPressed: appState.transcribeAudio,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${appState.transcript.length} lines',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: appState.transcribeAudio,
                child: const Text('Re-transcribe'),
              ),
            ],
          ),
        ),
        Expanded(
          child: TranscriptList(
            segments: appState.transcript,
            onEdit: (segment, text) => appState.updateTranscriptText(segment.id, text),
            onToggleCut: (segment) => appState.toggleMarkForCut(segment.id),
          ),
        ),
      ],
    );
  }
}

/// The real silence-detection review flow: scan → accept/reject each
/// detected gap → apply (cut them out and close the gaps) → optionally
/// restore the untouched original.
class _AudioPanel extends StatelessWidget {
  final AppState appState;

  const _AudioPanel({required this.appState});

  @override
  Widget build(BuildContext context) {
    final project = appState.project;
    if (project == null) return const SizedBox.shrink();

    if (appState.isDetectingSilence) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: Gaps.sm),
            Text('Analyzing audio…', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    if (appState.silenceRanges.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildReviewList(context, project);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.graphic_eq_rounded, size: 32, color: AppColors.textMuted),
          const SizedBox(height: Gaps.sm),
          const Text(
            'Scan this recording for silent or near-silent gaps to trim.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          if (appState.silenceError != null) ...[
            const SizedBox(height: Gaps.sm),
            Text(
              appState.silenceError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: Gaps.md),
          GradientButton(
            label: 'Detect silence',
            icon: Icons.search_rounded,
            expand: false,
            onPressed: appState.detectSilence,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList(BuildContext context, VideoProject project) {
    final ranges = appState.silenceRanges;
    final acceptedCount = ranges.where((r) => r.accepted).length;
    final applied = project.workingPath != project.sourcePath;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$acceptedCount of ${ranges.length} gaps selected',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: appState.isDetectingSilence ? null : appState.detectSilence,
                child: const Text('Re-scan'),
              ),
            ],
          ),
        ),
        if (appState.silenceError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
            child: Text(
              appState.silenceError!,
              style: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
            itemCount: ranges.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final range = ranges[index];
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: range.accepted,
                onChanged: (_) => appState.toggleSilenceRangeAccepted(index),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.accent,
                title: Text(
                  '${_fmt(range.start)} – ${_fmt(range.end)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  '${(range.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.sm),
          child: Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: appState.isApplyingSilenceRemoval
                      ? 'Removing…'
                      : 'Apply — remove silence',
                  icon: Icons.content_cut_rounded,
                  onPressed: appState.isApplyingSilenceRemoval || acceptedCount == 0
                      ? null
                      : appState.applySilenceRemoval,
                ),
              ),
              if (applied) ...[
                const SizedBox(width: Gaps.sm),
                TextButton(
                  onPressed: appState.restoreOriginalAudio,
                  child: const Text('Restore'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _AiCutsPanel extends StatelessWidget {
  final AppState appState;

  const _AiCutsPanel({required this.appState});

  @override
  Widget build(BuildContext context) {
    final hasTranscript = appState.transcript.isNotEmpty;
    final hasClips = appState.suggestedClips.isNotEmpty;

    if (appState.isGeneratingClips) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: Gaps.sm),
            Text('Finding your best moments…', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.sm),
          child: Text(
            !hasTranscript
                ? 'Transcribe captions first — the AI reads the transcript to find '
                    'complete, engaging moments.'
                : hasClips
                    ? 'The AI already scored every moment in this sermon. Review '
                        'the full ranked list on the next screen.'
                    : 'Ready to scan this transcript for short, shareable moments.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        if (appState.clipGenerationError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
            child: Text(
              appState.clipGenerationError!,
              style: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasClips) ...[
                  GradientButton(
                    label: 'View ${appState.suggestedClips.length} AI-suggested clips',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.clips),
                  ),
                  const SizedBox(height: Gaps.sm),
                ],
                GradientButton(
                  label: hasClips ? 'Regenerate clips' : 'Generate clips',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: hasTranscript ? appState.generateClipSuggestions : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlaysPanel extends StatelessWidget {
  const _OverlaysPanel();

  @override
  Widget build(BuildContext context) {
    const overlays = [
      ('Lower third', Icons.text_fields_rounded),
      ('Logo watermark', Icons.workspace_premium_rounded),
      ('Verse reference', Icons.menu_book_rounded),
      ('Progress bar', Icons.linear_scale_rounded),
    ];

    return GridView.count(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
      crossAxisCount: 2,
      mainAxisSpacing: Gaps.sm,
      crossAxisSpacing: Gaps.sm,
      childAspectRatio: 2.4,
      children: overlays.map((o) {
        final (label, icon) = o;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
