import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/caption_style.dart';
import '../models/transcript_segment.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/video_scrub_mixin.dart';

const _templateLabels = <CaptionTemplate, String>{
  CaptionTemplate.boldPop: 'Bold Word',
  CaptionTemplate.minimal: 'Clean Line',
  CaptionTemplate.karaoke: 'Highlight',
};

const _fontOptions = <String>['Montserrat', 'Inter', 'Poppins', 'Oswald', 'Bebas Neue'];

const _colorSwatches = <int>[0xFFFFFFFF, 0xFFF4A823, 0xFF000000, 0xFFD4B48C];

/// Desktop Subtitles — real standalone subtitle styling controls (V2
/// Decision #4: font/style, position, timing), genuinely new functionality
/// rather than a reskin of the Editor's transcript panel. [CaptionStyle]
/// already existed and already drove real export styling
/// (AppState._renderClip -> assForceStyle) — nothing in the app ever
/// exposed it in a UI before this. Font/size/color/template controls just
/// needed a real screen; italic, [SubtitlePosition], and
/// [CaptionStyle.timingOffsetMs] are new fields added this phase.
///
/// Scope cuts vs. `ui_kit/subtitles_desktop/`, matching the pattern from
/// Phases 26-28: the mockup's inline-editable transcript panel and
/// draggable dual-track (audio waveform + resizable caption blocks)
/// timeline aren't rebuilt here — inline transcript editing is a known,
/// separately-tracked gap (see video_editor_screen.dart's own doc note),
/// and a real per-caption drag-resize timeline has no backing data model
/// (captions are transcript-segment-driven, not independently
/// positionable) and the waveform is entirely fabricated in the mockup.
/// The transcript list here is real but read-only (click a line to seek,
/// same pattern as the Editor); the timeline below the preview is the same
/// real transcript-segment-driven single track the Editor already uses.
/// The mockup's language picker and "Re-Transcribe" button are dropped —
/// there's no real multi-language transcription or standalone re-transcribe
/// action in this backend (only a full re-analyse, which does much more
/// than re-transcribing). Preview stays 9:16, not the mockup's 16:9 box —
/// same reasoning as the Editor: every export is center-cropped to
/// 1080x1920, so that's the accurate WYSIWYG.
class SubtitlesDesktopScreen extends StatefulWidget {
  const SubtitlesDesktopScreen({super.key});

  @override
  State<SubtitlesDesktopScreen> createState() => _SubtitlesDesktopScreenState();
}

class _SubtitlesDesktopScreenState extends State<SubtitlesDesktopScreen>
    with VideoScrubMixin<SubtitlesDesktopScreen> {
  /// The segment currently open for inline editing in [_TranscriptPane], if
  /// any — lifted up here (rather than local to a list item) so a split can
  /// move editing onto the newly created second segment.
  String? _editingSegmentId;

  @override
  void dispose() {
    disposeVideoScrub();
    super.dispose();
  }

  void _handleSplit(AppState appState, String segmentId, int splitIndex) {
    final newId = appState.splitTranscriptSegment(segmentId, splitIndex);
    setState(() => _editingSegmentId = newId);
  }

  TranscriptSegment? _currentSegment(List<TranscriptSegment> segments, int offsetMs) {
    final shifted = position - Duration(milliseconds: offsetMs);
    for (final segment in segments) {
      if (shifted >= segment.start && shifted < segment.end) return segment;
    }
    return null;
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
          final segments = appState.transcript.where((s) => !s.isSilence).toList();
          final style = appState.captionStyle;
          final currentSegment = _currentSegment(segments, style.timingOffsetMs);

          return Column(
            children: [
              _Header(onReset: () => appState.updateCaptionStyle(CaptionStyle.defaultStyle)),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 340,
                      child: _TranscriptPane(
                        segments: segments,
                        highlightedId: currentSegment?.id,
                        editingSegmentId: _editingSegmentId,
                        onStartEdit: (id) => setState(() => _editingSegmentId = id),
                        onStopEdit: () => setState(() => _editingSegmentId = null),
                        onTextChanged: appState.updateTranscriptText,
                        onSplit: (id, splitIndex) => _handleSplit(appState, id, splitIndex),
                      ),
                    ),
                    const VerticalDivider(width: 1, color: LuxColors.border),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: _PreviewWithStyle(
                                controller: controller,
                                captionText: currentSegment?.text,
                                style: style,
                                onTogglePlay: togglePlayback,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: _StyleToolbar(
                              style: style,
                              onChanged: appState.updateCaptionStyle,
                            ),
                          ),
                          _SubtitleTimeline(
                            segments: segments,
                            totalDuration: project.processedDuration,
                            position: position,
                            highlightedId: currentSegment?.id,
                            onTapSegment: (s) => seekTo(s.start),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _Footer(segmentCount: segments.length),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onReset;
  const _Header({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.border))),
      child: Row(
        children: [
          const Icon(Icons.text_fields_rounded, size: 18, color: LuxColors.gold),
          const SizedBox(width: 8),
          Text('Subtitle Styling', style: LuxText.manrope(size: 15.5, weight: FontWeight.w700)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Reset to Defaults'),
            style: OutlinedButton.styleFrom(
              foregroundColor: LuxColors.textPrimary,
              side: const BorderSide(color: LuxColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptPane extends StatelessWidget {
  final List<TranscriptSegment> segments;
  final String? highlightedId;
  final String? editingSegmentId;
  final ValueChanged<String> onStartEdit;
  final VoidCallback onStopEdit;
  final void Function(String segmentId, String text) onTextChanged;
  final void Function(String segmentId, int splitIndex) onSplit;

  const _TranscriptPane({
    required this.segments,
    required this.highlightedId,
    required this.editingSegmentId,
    required this.onStartEdit,
    required this.onStopEdit,
    required this.onTextChanged,
    required this.onSplit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.article_outlined, size: 15, color: LuxColors.gold),
              const SizedBox(width: 8),
              Text('TRANSCRIPTION', style: LuxText.manrope(size: 11, weight: FontWeight.w700, letterSpacing: 0.5)),
            ],
          ),
        ),
        const Divider(height: 1, color: LuxColors.borderDashed),
        Expanded(
          child: segments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No transcript yet — run Analyse on this project first.',
                      textAlign: TextAlign.center,
                      style: LuxText.manrope(size: 12.5, color: LuxColors.textSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: segments.length,
                  itemBuilder: (context, i) {
                    final segment = segments[i];
                    return _TranscriptLine(
                      key: ValueKey(segment.id),
                      segment: segment,
                      active: segment.id == highlightedId,
                      editing: segment.id == editingSegmentId,
                      onStartEdit: () => onStartEdit(segment.id),
                      onStopEdit: onStopEdit,
                      onTextChanged: (text) => onTextChanged(segment.id, text),
                      onSplit: (splitIndex) => onSplit(segment.id, splitIndex),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// One transcript line — a static label by default; tapping it opens an
/// inline, single-line [TextField] with a real cursor. Pressing Enter mid-
/// text splits the segment at the cursor (see
/// [AppState.splitTranscriptSegment]) rather than inserting a newline
/// (`maxLines: 1` on the field prevents that and routes Enter to
/// [TextField.onSubmitted] instead); the new second half is inserted right
/// below as its own line, matching "move the right side to the next line."
/// Pressing Enter at the very start/end (nothing to split) or tapping away
/// just commits and closes the field — every keystroke already autosaves
/// via [onTextChanged], same pattern as the Settings screens' text fields.
class _TranscriptLine extends StatefulWidget {
  final TranscriptSegment segment;
  final bool active;
  final bool editing;
  final VoidCallback onStartEdit;
  final VoidCallback onStopEdit;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<int> onSplit;

  const _TranscriptLine({
    required super.key,
    required this.segment,
    required this.active,
    required this.editing,
    required this.onStartEdit,
    required this.onStopEdit,
    required this.onTextChanged,
    required this.onSplit,
  });

  @override
  State<_TranscriptLine> createState() => _TranscriptLineState();
}

class _TranscriptLineState extends State<_TranscriptLine> {
  late final TextEditingController _controller = TextEditingController(text: widget.segment.text);
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.editing) _focusAtStart();
  }

  @override
  void didUpdateWidget(covariant _TranscriptLine old) {
    super.didUpdateWidget(old);
    if (widget.editing && !old.editing) {
      _controller.text = widget.segment.text;
      _focusAtStart();
    } else if (!widget.editing && widget.segment.text != _controller.text) {
      _controller.text = widget.segment.text;
    }
  }

  void _focusAtStart() {
    _controller.selection = const TextSelection.collapsed(offset: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmitted(String value) {
    final cursor = _controller.selection.baseOffset;
    final splitAt = cursor < 0 ? value.length : cursor;
    if (splitAt > 0 && splitAt < value.length) {
      widget.onSplit(splitAt);
    } else {
      widget.onStopEdit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final segment = widget.segment;
    final active = widget.active;
    return Material(
      color: active ? LuxColors.gold.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.editing ? null : widget.onStartEdit,
        child: Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: active ? const Border(left: BorderSide(color: LuxColors.gold, width: 2)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                segment.timeLabel,
                style: LuxText.manrope(
                  size: 9.5,
                  weight: FontWeight.w600,
                  color: active ? LuxColors.gold : LuxColors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              widget.editing
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 1,
                      style: LuxText.manrope(size: 12.5, color: LuxColors.textPrimary),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: widget.onTextChanged,
                      onSubmitted: _handleSubmitted,
                      onTapOutside: (_) => widget.onStopEdit(),
                    )
                  : Text(
                      segment.text,
                      style: LuxText.manrope(
                        size: 12.5,
                        color: active ? LuxColors.textPrimary : LuxColors.textSecondary,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewWithStyle extends StatelessWidget {
  final VideoPlayerController? controller;
  final String? captionText;
  final CaptionStyle style;
  final VoidCallback onTogglePlay;

  const _PreviewWithStyle({
    required this.controller,
    required this.captionText,
    required this.style,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    final playerController = controller;
    final ready = playerController?.value.isInitialized ?? false;

    TextStyle captionTextStyle;
    try {
      captionTextStyle = GoogleFonts.getFont(
        style.fontFamily,
        fontSize: style.fontSize,
        fontWeight: style.template == CaptionTemplate.boldPop ? FontWeight.w900 : FontWeight.w600,
        fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
        color: Color(style.textColor),
        height: 1.1,
      );
    } catch (_) {
      // Falls back to the app's own font if [style.fontFamily] isn't a
      // recognized Google Fonts family (shouldn't happen via the curated
      // dropdown, but persisted data could predate it).
      captionTextStyle = LuxText.sora(size: style.fontSize, color: Color(style.textColor));
    }

    final alignment = switch (style.position) {
      SubtitlePosition.top => const Alignment(0, -0.72),
      SubtitlePosition.middle => Alignment.center,
      SubtitlePosition.bottom => const Alignment(0, 0.78),
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: GestureDetector(
            onTap: ready ? onTogglePlay : null,
            child: Container(
              decoration: BoxDecoration(
                color: LuxColors.playerSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LuxColors.border),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 10))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
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
                    const Center(child: Icon(Icons.movie_creation_outlined, size: 40, color: LuxColors.borderStrong)),
                  if (!ready)
                    const Center(child: CircularProgressIndicator(color: LuxColors.gold))
                  else if (!playerController!.value.isPlaying)
                    Center(child: Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white.withValues(alpha: 0.8))),
                  if (captionText != null && captionText!.trim().isNotEmpty)
                    Align(
                      alignment: alignment,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          color: Colors.black.withValues(alpha: 0.35),
                          child: Text(
                            captionText!.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: captionTextStyle,
                          ),
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

class _StyleToolbar extends StatelessWidget {
  final CaptionStyle style;
  final ValueChanged<CaptionStyle> onChanged;

  const _StyleToolbar({required this.style, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LuxColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ToolbarGroup(
            label: 'TEMPLATE',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in _templateLabels.entries) ...[
                  _Chip(
                    label: entry.value,
                    selected: style.template == entry.key,
                    onTap: () => onChanged(style.copyWith(template: entry.key)),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          _ToolbarGroup(
            label: 'STYLE',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconToggle(
                  icon: Icons.format_italic_rounded,
                  active: style.italic,
                  tooltip: 'Italic',
                  onTap: () => onChanged(style.copyWith(italic: !style.italic)),
                ),
              ],
            ),
          ),
          _ToolbarGroup(
            label: 'FONT',
            child: DropdownButton<String>(
              value: style.fontFamily,
              underline: const SizedBox.shrink(),
              dropdownColor: LuxColors.surfaceRaised,
              style: LuxText.manrope(size: 12.5, color: LuxColors.textPrimary),
              items: [
                for (final font in _fontOptions) DropdownMenuItem(value: font, child: Text(font)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(style.copyWith(fontFamily: v));
              },
            ),
          ),
          _ToolbarGroup(
            label: 'SIZE',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onTap: () => onChanged(style.copyWith(fontSize: (style.fontSize - 2).clamp(12, 48))),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    style.fontSize.round().toString(),
                    textAlign: TextAlign.center,
                    style: LuxText.manrope(size: 12.5, weight: FontWeight.w600, color: LuxColors.textPrimary),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onTap: () => onChanged(style.copyWith(fontSize: (style.fontSize + 2).clamp(12, 48))),
                ),
              ],
            ),
          ),
          _ToolbarGroup(
            label: 'COLOR',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in _colorSwatches) ...[
                  _ColorSwatch(
                    color: color,
                    selected: style.textColor == color,
                    onTap: () => onChanged(style.copyWith(textColor: color)),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          _ToolbarGroup(
            label: 'POSITION',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconToggle(
                  icon: Icons.vertical_align_top_rounded,
                  active: style.position == SubtitlePosition.top,
                  tooltip: 'Top',
                  onTap: () => onChanged(style.copyWith(position: SubtitlePosition.top)),
                ),
                _IconToggle(
                  icon: Icons.vertical_align_center_rounded,
                  active: style.position == SubtitlePosition.middle,
                  tooltip: 'Middle',
                  onTap: () => onChanged(style.copyWith(position: SubtitlePosition.middle)),
                ),
                _IconToggle(
                  icon: Icons.vertical_align_bottom_rounded,
                  active: style.position == SubtitlePosition.bottom,
                  tooltip: 'Bottom',
                  onTap: () => onChanged(style.copyWith(position: SubtitlePosition.bottom)),
                ),
              ],
            ),
          ),
          _ToolbarGroup(
            label: 'TIMING',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onTap: () => onChanged(style.copyWith(timingOffsetMs: style.timingOffsetMs - 100)),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${style.timingOffsetMs}ms',
                    textAlign: TextAlign.center,
                    style: LuxText.manrope(size: 12, weight: FontWeight.w600, color: LuxColors.textPrimary),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onTap: () => onChanged(style.copyWith(timingOffsetMs: style.timingOffsetMs + 100)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarGroup extends StatelessWidget {
  final String label;
  final Widget child;
  const _ToolbarGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: LuxText.manrope(size: 8.5, weight: FontWeight.w700, color: LuxColors.textMuted, letterSpacing: 0.6)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? LuxColors.gold.withValues(alpha: 0.16) : LuxColors.surfaceRaised,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: selected ? LuxColors.gold.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Text(
            label,
            style: LuxText.manrope(size: 11, weight: FontWeight.w600, color: selected ? LuxColors.gold2 : LuxColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  const _IconToggle({required this.icon, required this.active, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? LuxColors.gold.withValues(alpha: 0.18) : LuxColors.surfaceRaised,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 15, color: active ? LuxColors.gold2 : LuxColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.surfaceRaised,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(width: 22, height: 22, child: Icon(icon, size: 13, color: LuxColors.textSecondary)),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final int color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorSwatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Color(color),
          shape: BoxShape.circle,
          border: Border.all(color: selected ? LuxColors.gold : LuxColors.border, width: selected ? 2 : 1),
        ),
      ),
    );
  }
}

class _SubtitleTimeline extends StatelessWidget {
  final List<TranscriptSegment> segments;
  final Duration totalDuration;
  final Duration position;
  final String? highlightedId;
  final ValueChanged<TranscriptSegment> onTapSegment;

  const _SubtitleTimeline({
    required this.segments,
    required this.totalDuration,
    required this.position,
    required this.highlightedId,
    required this.onTapSegment,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = totalDuration.inMilliseconds == 0 ? 1 : totalDuration.inMilliseconds;
    final playheadFraction = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LuxColors.background,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: segments.isEmpty
          ? Center(child: Text('No captions to sync yet.', style: LuxText.manrope(size: 11.5, color: LuxColors.textMuted)))
          : Stack(
              children: [
                Row(
                  children: segments.map((segment) {
                    final flex = ((segment.duration.inMilliseconds / totalMs) * 1000).clamp(4, 1000).round();
                    final active = segment.id == highlightedId;
                    return Expanded(
                      flex: flex,
                      child: GestureDetector(
                        onTap: () => onTapSegment(segment),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active ? LuxColors.gold : LuxColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(4),
                            border: active ? Border.all(color: LuxColors.gold, width: 1.5) : null,
                          ),
                          child: Text(
                            segment.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LuxText.manrope(
                              size: 9.5,
                              weight: FontWeight.w600,
                              color: active ? LuxColors.background : LuxColors.textMuted,
                            ),
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
    );
  }
}

class _Footer extends StatelessWidget {
  final int segmentCount;
  const _Footer({required this.segmentCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: LuxColors.border))),
      child: Row(
        children: [
          Text(
            '$segmentCount caption${segmentCount == 1 ? '' : 's'}',
            style: LuxText.manrope(size: 10.5, color: LuxColors.textSecondary),
          ),
          const Spacer(),
          const Icon(Icons.check_circle_outline_rounded, size: 13, color: LuxColors.textMuted),
          const SizedBox(width: 6),
          Text('Styling saves automatically', style: LuxText.manrope(size: 10, color: LuxColors.textMuted)),
        ],
      ),
    );
  }
}
