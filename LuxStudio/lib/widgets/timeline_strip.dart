import 'package:flutter/material.dart';

import '../models/transcript_segment.dart';
import '../theme/app_theme.dart';

/// Horizontal scrubber strip: a waveform-style block per transcript
/// segment, with silence gaps rendered as thin dark notches — mirroring
/// the "timeline strip with audio chunks and silence gaps" from the
/// editor screen spec.
class TimelineStrip extends StatelessWidget {
  final List<TranscriptSegment> segments;
  final Duration totalDuration;
  final String? highlightedSegmentId;
  final ValueChanged<TranscriptSegment>? onTapSegment;

  const TimelineStrip({
    super.key,
    required this.segments,
    required this.totalDuration,
    this.highlightedSegmentId,
    this.onTapSegment,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = totalDuration.inMilliseconds == 0 ? 1 : totalDuration.inMilliseconds;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: segments.map((segment) {
          final flex = ((segment.duration.inMilliseconds / totalMs) * 1000)
              .clamp(4, 1000)
              .round();
          final isHighlighted = segment.id == highlightedSegmentId;

          return Expanded(
            flex: flex,
            child: GestureDetector(
              onTap: onTapSegment == null ? null : () => onTapSegment!(segment),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: segment.isSilence
                      ? AppColors.silenceGap
                      : segment.isMarkedForCut
                          ? AppColors.textMuted.withOpacity(0.4)
                          : AppColors.waveform.withOpacity(isHighlighted ? 1 : 0.75),
                  borderRadius: BorderRadius.circular(4),
                  border: isHighlighted
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                ),
                child: segment.isSilence
                    ? null
                    : CustomPaint(painter: _MiniWaveformPainter(seed: segment.id.hashCode)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Cheap deterministic "fake waveform" so each block looks distinct
/// without shipping real audio-amplitude data.
class _MiniWaveformPainter extends CustomPainter {
  final int seed;

  _MiniWaveformPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final barCount = (size.width / 4).clamp(3, 30).floor();
    for (var i = 0; i < barCount; i++) {
      final pseudoRandom = ((seed + i * 37) % 100) / 100;
      final barHeight = size.height * (0.25 + pseudoRandom * 0.6);
      final x = i * (size.width / barCount) + 2;
      final centerY = size.height / 2;
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniWaveformPainter oldDelegate) => false;
}
