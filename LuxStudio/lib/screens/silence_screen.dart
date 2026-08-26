import 'package:flutter/material.dart';

import '../main.dart';
import '../models/silence_range.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';
import '../widgets/lux_buttons.dart';
import '../widgets/lux_card.dart';
import '../widgets/sticky_cta_bar.dart';

/// Remove Silence — scan the recording for quiet gaps, review each one,
/// then cut the accepted ones out and close the gaps.
class SilenceScreen extends StatefulWidget {
  const SilenceScreen({super.key});

  @override
  State<SilenceScreen> createState() => _SilenceScreenState();
}

class _SilenceScreenState extends State<SilenceScreen> {
  double _noiseFloorDb = -30;
  Duration _minDuration = const Duration(milliseconds: 500);

  void _rescan(AppState appState) {
    appState.detectSilence(noiseFloorDb: _noiseFloorDb, minDuration: _minDuration);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      appBar: const LuxAppBar(title: 'Remove Silence'),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final ranges = appState.silenceRanges;
          final acceptedCount = ranges.where((r) => r.accepted).length;
          final savedDuration = ranges
              .where((r) => r.accepted)
              .fold<Duration>(Duration.zero, (sum, r) => sum + r.duration);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    LuxCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SliderRow(
                            label: 'Silence Threshold',
                            valueLabel: '${_noiseFloorDb.round()} dB',
                            value: _noiseFloorDb,
                            min: -60,
                            max: -10,
                            onChanged: (v) => setState(() => _noiseFloorDb = v),
                            onChangeEnd: (_) => _rescan(appState),
                          ),
                          const SizedBox(height: 18),
                          _SliderRow(
                            label: 'Minimum Duration',
                            valueLabel: '${(_minDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                            value: _minDuration.inMilliseconds.toDouble(),
                            min: 100,
                            max: 2000,
                            onChanged: (v) => setState(() => _minDuration = Duration(milliseconds: v.round())),
                            onChangeEnd: (_) => _rescan(appState),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Detects gaps quieter than the threshold for longer than the minimum duration.',
                            style: LuxText.manrope(size: 11.5, weight: FontWeight.w500, color: LuxColors.textMuted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (appState.isDetectingSilence)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator(color: LuxColors.gold)),
                      )
                    else if (ranges.isEmpty)
                      _EmptyState(onScan: () => _rescan(appState), error: appState.silenceError)
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Detected Gaps (${ranges.length})', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                          LuxGhostButton(
                            label: acceptedCount == ranges.length ? 'Select None' : 'Select All',
                            onPressed: () => appState.setAllSilenceRangesAccepted(acceptedCount != ranges.length),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < ranges.length; i++) ...[
                        _GapRow(range: ranges[i], onTap: () => appState.toggleSilenceRangeAccepted(i)),
                        const SizedBox(height: 12),
                      ],
                      if (appState.silenceError != null) ...[
                        const SizedBox(height: 8),
                        Text(appState.silenceError!, style: LuxText.manrope(size: 12, color: LuxColors.error)),
                      ],
                    ],
                  ],
                ),
              ),
              if (ranges.isNotEmpty)
                StickyCtaBar(
                  note: 'Total time saved: ${(savedDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  child: LuxPrimaryButton(
                    label: appState.isApplyingSilenceRemoval
                        ? 'Removing…'
                        : 'Remove $acceptedCount Selected Gap${acceptedCount == 1 ? '' : 's'}',
                    icon: Icons.content_cut_rounded,
                    loading: appState.isApplyingSilenceRemoval,
                    onPressed: appState.isApplyingSilenceRemoval || acceptedCount == 0
                        ? null
                        : appState.applySilenceRemoval,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: LuxText.manrope(size: 13, weight: FontWeight.w700)),
            Text(valueLabel, style: LuxText.manrope(size: 13, weight: FontWeight.w700, color: LuxColors.gold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: LuxColors.gold,
            inactiveTrackColor: LuxColors.borderStrong,
            thumbColor: LuxColors.gold,
            overlayColor: LuxColors.gold.withValues(alpha: 0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;
  final String? error;
  const _EmptyState({required this.onScan, required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.graphic_eq_rounded, size: 32, color: LuxColors.textMuted),
          const SizedBox(height: 10),
          Text(
            'Scan this recording for silent or near-silent gaps to trim.',
            textAlign: TextAlign.center,
            style: LuxText.manrope(size: 12.5, color: LuxColors.textSecondary),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center, style: LuxText.manrope(size: 11.5, color: LuxColors.error)),
          ],
          const SizedBox(height: 16),
          LuxSecondaryButton(label: 'Detect Silence', icon: Icons.search_rounded, onPressed: onScan),
        ],
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  final SilenceRange range;
  final VoidCallback onTap;
  const _GapRow({required this.range, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LuxCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            range.accepted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: range.accepted ? LuxColors.gold : LuxColors.textMuted,
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 26,
            decoration: BoxDecoration(color: LuxColors.surfaceRaised, borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: CustomPaint(size: const Size(56, 18), painter: _GapWaveformPainter(seed: range.hashCode)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_label(range), style: LuxText.manrope(size: 13.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${(range.duration.inMilliseconds / 1000).toStringAsFixed(1)}s silent',
                  style: LuxText.manrope(size: 11.5, weight: FontWeight.w600, color: LuxColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(SilenceRange r) => '${_fmt(r.start)} – ${_fmt(r.end)}';

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _GapWaveformPainter extends CustomPainter {
  final int seed;
  const _GapWaveformPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LuxColors.bronze
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path();
    const points = 8;
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      final pseudo = ((seed + i * 53) % 100) / 100;
      final y = size.height / 2 + (pseudo - 0.5) * size.height * 0.9;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GapWaveformPainter oldDelegate) => oldDelegate.seed != seed;
}
