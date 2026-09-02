import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../utils/error_presenter.dart';
import '../widgets/lux_icon_button.dart';

/// The four stages the backend's automatic `/analyse` pipeline reports
/// progress against — see backend/app/routers/analyse.py's step-to-UI
/// mapping doc comment for how these line up with the actual execution
/// order (clip identification needs a transcript, so "Auto-Captioning"
/// here is really just confirming the already-fetched transcript is
/// attached, not doing the heavy lifting).
const _steps = <(String key, String title, String subtitle)>[
  ('silence_removal', 'Silence Removal', 'Trimming dead air from the recording'),
  ('audio_enhancement', 'Audio Enhancement', 'Normalizing voice clarity'),
  ('clip_identification', 'AI Clip Identification', 'Scanning for high-impact segments'),
  ('captioning', 'Auto-Captioning', 'Preparing the transcript for editing'),
];

/// Screen 2 — Analyse. Matches `ui_kit/analyse/index.html`: a circular
/// progress ring + linear bar + 4-step checklist, all driven by
/// [AppState.runAnalysePipeline]'s polled status. Replaces the old
/// separate Silence/Captions screens with one automatic backend job.
class AnalyseScreen extends StatefulWidget {
  const AnalyseScreen({super.key});

  @override
  State<AnalyseScreen> createState() => _AnalyseScreenState();
}

class _AnalyseScreenState extends State<AnalyseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStateScope.of(context).runAnalysePipeline();
    });
  }

  int get _currentStepIndex {
    final appState = AppStateScope.of(context);
    if (appState.analyseStatus == 'done') return _steps.length;
    final index = _steps.indexWhere((s) => s.$1 == appState.analyseStep);
    return index;
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
            final currentIndex = _currentStepIndex;
            final percent = appState.analysePercent.clamp(0, 100);
            final isDone = appState.analyseStatus == 'done';
            final isError = appState.analyseStatus == 'error';

            return Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    children: [
                      _StatusCard(
                        percent: percent,
                        isDone: isDone,
                        isError: isError,
                        error: appState.analyseError,
                      ),
                      const SizedBox(height: 24),
                      for (var i = 0; i < _steps.length; i++) ...[
                        _StepRow(
                          title: _steps[i].$2,
                          subtitle: _steps[i].$3,
                          state: isError && i == currentIndex
                              ? _StepState.error
                              : i < currentIndex || isDone
                                  ? _StepState.done
                                  : i == currentIndex
                                      ? _StepState.active
                                      : _StepState.pending,
                        ),
                        if (i != _steps.length - 1) const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                _buildFooter(context, appState, isDone: isDone, isError: isError),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Text('LuxStudio', style: LuxText.sora(size: 18, weight: FontWeight.w700)),
          ),
          LuxIconButton(
            icon: Icons.close_rounded,
            variant: LuxIconButtonVariant.onSurface,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppState appState, {required bool isDone, required bool isError}) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final (String label, VoidCallback? onPressed) = switch ((isDone, isError)) {
      (true, _) => ('Open Editor', () => Navigator.of(context).pushReplacementNamed(AppRoutes.editor)),
      (_, true) => ('Retry', appState.runAnalysePipeline),
      _ => ('Finalizing Workspace', null),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 20 + bottomInset),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: isDone ? null : LuxColors.surfaceRaised,
            foregroundColor: isDone ? LuxColors.background : LuxColors.textSecondary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LuxRadii.button)),
            textStyle: LuxText.manrope(size: 14, weight: FontWeight.w700),
          ).merge(
            isDone
                ? ButtonStyle(backgroundColor: WidgetStateProperty.all(LuxColors.gold))
                : const ButtonStyle(),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final int percent;
  final bool isDone;
  final bool isError;
  final String? error;

  const _StatusCard({required this.percent, required this.isDone, required this.isError, this.error});

  @override
  Widget build(BuildContext context) {
    final displayPercent = isDone ? 100 : percent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: LuxColors.surface,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 128,
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 3,
                    color: LuxColors.surfaceRaised,
                  ),
                ),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: displayPercent / 100,
                    strokeWidth: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(isError ? LuxColors.error : LuxColors.gold),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$displayPercent%', style: LuxText.sora(size: 30, weight: FontWeight.w900)),
                    Text(
                      isError ? 'Error' : (isDone ? 'Done' : 'Processing'),
                      style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: LuxColors.gold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isError ? 'Analysis Failed' : 'Analyzing Sermon',
            style: LuxText.sora(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isError
                ? friendlyError(error)
                : 'Our AI is extracting the most powerful moments for you.',
            textAlign: TextAlign.center,
            style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: math.max(displayPercent / 100, 0.02),
              minHeight: 6,
              backgroundColor: LuxColors.surfaceRaised,
              valueColor: AlwaysStoppedAnimation(isError ? LuxColors.error : LuxColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending, error }

class _StepRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final _StepState state;

  const _StepRow({required this.title, required this.subtitle, required this.state});

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    final Color textColor;
    switch (state) {
      case _StepState.done:
        icon = const Icon(Icons.check_circle_rounded, color: LuxColors.gold, size: 22);
        textColor = LuxColors.textPrimary;
      case _StepState.active:
        icon = const SizedBox(
          width: 10,
          height: 10,
          child: DecoratedBox(decoration: BoxDecoration(color: LuxColors.gold, shape: BoxShape.circle)),
        );
        textColor = LuxColors.gold;
      case _StepState.error:
        icon = const Icon(Icons.error_rounded, color: LuxColors.error, size: 22);
        textColor = LuxColors.error;
      case _StepState.pending:
        icon = const Icon(Icons.circle_outlined, color: LuxColors.textMuted, size: 20);
        textColor = LuxColors.textMuted;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: state == _StepState.done
                  ? LuxColors.gold.withValues(alpha: 0.1)
                  : LuxColors.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Center(child: icon),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: LuxText.manrope(size: 14, weight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: LuxText.manrope(size: 12, weight: FontWeight.w500, color: LuxColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
