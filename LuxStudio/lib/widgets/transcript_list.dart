import 'package:flutter/material.dart';

import '../models/transcript_segment.dart';
import '../theme/app_theme.dart';

/// Scrollable transcript with inline editing actions, per segment:
/// tap the text to edit it, or use the trailing menu to mark/unmark a
/// line for removal.
class TranscriptList extends StatelessWidget {
  final List<TranscriptSegment> segments;
  final void Function(TranscriptSegment segment, String newText) onEdit;
  final void Function(TranscriptSegment segment) onToggleCut;

  const TranscriptList({
    super.key,
    required this.segments,
    required this.onEdit,
    required this.onToggleCut,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.sm),
      itemCount: segments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final segment = segments[index];
        if (segment.isSilence) {
          return _SilenceDivider(duration: segment.duration);
        }
        return _TranscriptRow(
          segment: segment,
          onEdit: (text) => onEdit(segment, text),
          onToggleCut: () => onToggleCut(segment),
        );
      },
    );
  }
}

class _SilenceDivider extends StatelessWidget {
  final Duration duration;

  const _SilenceDivider({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.sm),
            child: Text(
              'Silence trimmed · ${duration.inSeconds}s',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

class _TranscriptRow extends StatefulWidget {
  final TranscriptSegment segment;
  final ValueChanged<String> onEdit;
  final VoidCallback onToggleCut;

  const _TranscriptRow({
    required this.segment,
    required this.onEdit,
    required this.onToggleCut,
  });

  @override
  State<_TranscriptRow> createState() => _TranscriptRowState();
}

class _TranscriptRowState extends State<_TranscriptRow> {
  bool _editing = false;
  late final TextEditingController _controller =
      TextEditingController(text: widget.segment.text);

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
    return Container(
      padding: const EdgeInsets.all(Gaps.sm),
      decoration: BoxDecoration(
        color: segment.isMarkedForCut
            ? AppColors.surfaceSunken
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              segment.timeLabel.split(' – ').first,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: null,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _commit(),
                  )
                : GestureDetector(
                    onTap: () => setState(() => _editing = true),
                    child: Text(
                      segment.text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: segment.isMarkedForCut
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: segment.isMarkedForCut
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          if (_editing)
            IconButton(
              icon: const Icon(Icons.check_rounded, size: 18, color: AppColors.success),
              onPressed: _commit,
              visualDensity: VisualDensity.compact,
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted),
              color: AppColors.surfaceRaised,
              onSelected: (value) {
                if (value == 'edit') setState(() => _editing = true);
                if (value == 'cut') widget.onToggleCut();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit text')),
                PopupMenuItem(
                  value: 'cut',
                  child: Text(segment.isMarkedForCut ? 'Restore line' : 'Mark for cut'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
