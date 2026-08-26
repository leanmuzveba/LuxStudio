import 'package:flutter/material.dart';

import '../main.dart';
import '../models/caption_style.dart';
import '../models/transcript_segment.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';
import '../widgets/lux_buttons.dart';
import '../widgets/lux_card.dart';
import '../widgets/lux_chip.dart';
import '../widgets/lux_icon_button.dart';
import '../widgets/sticky_cta_bar.dart';

const _fontChoices = ['Sans Serif', 'Serif', 'Monospace'];
const _colorChoices = [0xFFF5EFE6, 0xFFF4B315, 0xFFE59312, 0xFFD3AF85, 0xFF8E5915, 0xFFFFFFFF];

/// Captions — transcribe, edit the transcript, and pick how burned-in
/// captions look at export (template, font, size, colors).
class CaptionsScreen extends StatelessWidget {
  const CaptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      appBar: const LuxAppBar(title: 'Captions'),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (appState.isTranscribing) {
            return const Center(child: CircularProgressIndicator(color: LuxColors.gold));
          }
          if (appState.transcript.isEmpty) {
            return _EmptyState(
              error: appState.transcriptionError,
              onTranscribe: appState.transcribeAudio,
            );
          }

          final previewText = _previewText(appState.transcript);
          final wordCount =
              appState.transcript.where((s) => !s.isSilence).fold<int>(0, (sum, s) => sum + s.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _PreviewFrame(text: previewText, style: appState.captionStyle),
                    const SizedBox(height: 20),
                    Text('Caption Style', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: CaptionTemplate.values.map((template) {
                        final selected = appState.captionStyle.template == template;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _TemplateSwatch(
                              template: template,
                              selected: selected,
                              onTap: () => appState.updateCaptionStyle(
                                appState.captionStyle.copyWith(template: template),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: PopupMenuButton<String>(
                            color: LuxColors.surfaceRaised,
                            onSelected: (font) =>
                                appState.updateCaptionStyle(appState.captionStyle.copyWith(fontFamily: font)),
                            itemBuilder: (context) => _fontChoices
                                .map((f) => PopupMenuItem(value: f, child: Text(f, style: LuxText.manrope(size: 13))))
                                .toList(),
                            child: LuxChip(
                              label: appState.captionStyle.fontFamily,
                              trailing: const Icon(Icons.expand_more_rounded, size: 16, color: LuxColors.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SizeStepper(
                          size: appState.captionStyle.fontSize,
                          onChanged: (size) =>
                              appState.updateCaptionStyle(appState.captionStyle.copyWith(fontSize: size)),
                        ),
                        const SizedBox(width: 10),
                        _ColorSwatch(
                          color: Color(appState.captionStyle.textColor),
                          onPick: (c) =>
                              appState.updateCaptionStyle(appState.captionStyle.copyWith(textColor: c.toARGB32())),
                        ),
                        const SizedBox(width: 8),
                        _ColorSwatch(
                          color: Color(appState.captionStyle.highlightColor),
                          onPick: (c) => appState
                              .updateCaptionStyle(appState.captionStyle.copyWith(highlightColor: c.toARGB32())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Transcript', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                        Text('$wordCount words', style: LuxText.manrope(size: 11.5, weight: FontWeight.w600, color: LuxColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final segment in appState.transcript.where((s) => !s.isSilence)) ...[
                      _TranscriptRow(
                        segment: segment,
                        onEdit: (text) => appState.updateTranscriptText(segment.id, text),
                        onToggleCut: () => appState.toggleMarkForCut(segment.id),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              StickyCtaBar(
                child: LuxPrimaryButton(
                  label: appState.isGeneratingClips ? 'Finding clips…' : 'Continue to Clips',
                  icon: Icons.arrow_forward_rounded,
                  loading: appState.isGeneratingClips,
                  onPressed: appState.isGeneratingClips
                      ? null
                      : () async {
                          if (appState.suggestedClips.isEmpty) {
                            await appState.generateClipSuggestions();
                          }
                          if (context.mounted) Navigator.of(context).pushNamed(AppRoutes.clips);
                        },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _previewText(List<TranscriptSegment> transcript) {
    for (final s in transcript) {
      if (!s.isSilence && s.text.trim().isNotEmpty) return s.text.trim();
    }
    return '';
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  final VoidCallback onTranscribe;
  const _EmptyState({required this.error, required this.onTranscribe});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.closed_caption_rounded, size: 32, color: LuxColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'Transcribe this recording to generate editable captions.',
              textAlign: TextAlign.center,
              style: LuxText.manrope(size: 12.5, color: LuxColors.textSecondary),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center, style: LuxText.manrope(size: 11.5, color: LuxColors.error)),
            ],
            const SizedBox(height: 16),
            LuxSecondaryButton(label: 'Transcribe', icon: Icons.mic_rounded, onPressed: onTranscribe),
          ],
        ),
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  final String text;
  final CaptionStyle style;
  const _PreviewFrame({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: LuxColors.playerSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LuxColors.border),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.movie_creation_outlined, size: 36, color: LuxColors.borderStrong),
            if (text.isNotEmpty)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      text.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: LuxText.sora(
                        size: 14,
                        weight: style.template == CaptionTemplate.boldPop ? FontWeight.w800 : FontWeight.w600,
                        color: Color(style.textColor),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateSwatch extends StatelessWidget {
  final CaptionTemplate template;
  final bool selected;
  final VoidCallback onTap;
  const _TemplateSwatch({required this.template, required this.selected, required this.onTap});

  String get _label => switch (template) {
        CaptionTemplate.boldPop => 'Bold Pop',
        CaptionTemplate.minimal => 'Minimal',
        CaptionTemplate.karaoke => 'Karaoke',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LuxCard(
          onTap: onTap,
          borderColor: selected ? LuxColors.gold : null,
          borderWidth: selected ? 2 : 1,
          backgroundColor: LuxColors.surfaceDashed,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(
                _label,
                style: LuxText.manrope(
                  size: 11,
                  weight: FontWeight.w800,
                  color: selected ? LuxColors.gold : LuxColors.tan,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        LuxChip(label: _label, selected: selected, onTap: onTap),
      ],
    );
  }
}

class _SizeStepper extends StatelessWidget {
  final double size;
  final ValueChanged<double> onChanged;
  const _SizeStepper({required this.size, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: LuxColors.surfaceRaised, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(icon: Icons.remove_rounded, onTap: () => onChanged((size - 1).clamp(12, 40))),
          SizedBox(
            width: 24,
            child: Text(
              size.round().toString(),
              textAlign: TextAlign.center,
              style: LuxText.manrope(size: 12.5, weight: FontWeight.w700),
            ),
          ),
          _StepperButton(icon: Icons.add_rounded, onTap: () => onChanged((size + 1).clamp(12, 40))),
        ],
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: LuxColors.textPrimary),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onPick;
  const _ColorSwatch({required this.color, required this.onPick});

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: LuxColors.surfaceRaised,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _colorChoices.map((c) {
              final option = Color(c);
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(option),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: option,
                    shape: BoxShape.circle,
                    border: Border.all(color: LuxColors.borderStrong, width: 2),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: LuxColors.borderStrong, width: 2),
        ),
      ),
    );
  }
}

class _TranscriptRow extends StatefulWidget {
  final TranscriptSegment segment;
  final ValueChanged<String> onEdit;
  final VoidCallback onToggleCut;

  const _TranscriptRow({required this.segment, required this.onEdit, required this.onToggleCut});

  @override
  State<_TranscriptRow> createState() => _TranscriptRowState();
}

class _TranscriptRowState extends State<_TranscriptRow> {
  bool _editing = false;
  late final TextEditingController _controller = TextEditingController(text: widget.segment.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    widget.onEdit(_controller.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final segment = widget.segment;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 38,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              segment.timeLabel.split(' – ').first,
              style: LuxText.sora(size: 11, weight: FontWeight.w700, color: LuxColors.textMuted),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _editing
              ? TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  style: LuxText.manrope(size: 13.5, color: LuxColors.transcriptBody, height: 1.5),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  onSubmitted: (_) => _commit(),
                )
              : GestureDetector(
                  onTap: () => setState(() => _editing = true),
                  child: Text(
                    segment.text,
                    style: LuxText.manrope(
                      size: 13.5,
                      height: 1.5,
                      color: segment.isMarkedForCut ? LuxColors.textMuted : LuxColors.transcriptBody,
                      weight: FontWeight.w500,
                    ).copyWith(decoration: segment.isMarkedForCut ? TextDecoration.lineThrough : TextDecoration.none),
                  ),
                ),
        ),
        const SizedBox(width: 4),
        if (_editing)
          LuxIconButton(icon: Icons.check_rounded, size: 28, iconSize: 15, onPressed: _commit)
        else
          PopupMenuButton<String>(
            color: LuxColors.surfaceRaised,
            icon: const Icon(Icons.edit_outlined, size: 15, color: LuxColors.iconSubtle),
            onSelected: (value) {
              if (value == 'edit') setState(() => _editing = true);
              if (value == 'cut') widget.onToggleCut();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text('Edit text', style: LuxText.manrope(size: 13))),
              PopupMenuItem(
                value: 'cut',
                child: Text(segment.isMarkedForCut ? 'Restore line' : 'Mark for cut', style: LuxText.manrope(size: 13)),
              ),
            ],
          ),
      ],
    );
  }
}
