import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/processing_step.dart';
import '../services/media_import_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/circular_step_progress.dart';
import '../widgets/gradient_button.dart';

/// Screen 1 — Import & AI Processing.
///
/// Two states in one screen: an idle "import a sermon" prompt, and once a
/// real file is picked, copied into the app sandbox, and probed, a live
/// progress view walking through the four-stage AI pipeline before
/// handing off to the editor.
class ImportProcessingScreen extends StatefulWidget {
  /// [mediaImportService] lets tests inject one with fake pick/probe
  /// steps (real `file_picker`/ffprobe calls need platform channels with
  /// no implementation under plain `flutter test`). Defaults to real.
  const ImportProcessingScreen({super.key, MediaImportService? mediaImportService})
      : _injectedMediaImportService = mediaImportService;

  final MediaImportService? _injectedMediaImportService;

  @override
  State<ImportProcessingScreen> createState() => _ImportProcessingScreenState();
}

class _ImportProcessingScreenState extends State<ImportProcessingScreen> {
  late final MediaImportService _mediaImportService =
      widget._injectedMediaImportService ?? MediaImportService();
  Timer? _tickTimer;
  double _stageProgress = 0;
  bool _importing = false;
  String? _importError;

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _beginImport(AppState appState) async {
    setState(() => _importError = null);
    try {
      final project = await _mediaImportService.importVideo();
      if (!mounted) return;
      if (project == null) return; // user cancelled the picker

      setState(() => _importing = true);
      appState.startImport(project);
      _runStage(appState);
    } catch (e) {
      if (mounted) setState(() => _importError = e.toString());
    }
  }

  void _runStage(AppState appState) {
    _stageProgress = 0;
    final duration = ProcessingStep.pipeline[appState.processingStageIndex].estimatedDuration;
    const tick = Duration(milliseconds: 60);
    final totalTicks = duration.inMilliseconds / tick.inMilliseconds;
    var elapsedTicks = 0;

    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(tick, (timer) {
      elapsedTicks++;
      setState(() => _stageProgress = (elapsedTicks / totalTicks).clamp(0.0, 1.0));
      if (elapsedTicks >= totalTicks) {
        timer.cancel();
        final isLastStage =
            appState.processingStageIndex == ProcessingStep.pipeline.length - 1;
        appState.advanceProcessingStage();
        if (!isLastStage) {
          _runStage(appState);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            if (!_importing) return _buildIdleState(context, appState);
            if (appState.processingComplete) {
              return _buildCompleteState(context, appState);
            }
            return _buildProcessingState(context, appState);
          },
        ),
      ),
    );
  }

  Widget _buildIdleState(BuildContext context, AppState appState) {
    return _CenteredScrollable(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(Icons.video_call_rounded, color: Colors.white, size: 44),
        ),
        const SizedBox(height: Gaps.lg),
        Text('Import your sermon', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Gaps.sm),
        Text(
          'Drop in the raw recording. LuxStudio removes silence, '
          'cleans the audio, and finds your best short-form moments '
          'automatically.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Gaps.xl),
        _buildDropZone(context),
        const SizedBox(height: Gaps.xl),
        GradientButton(
          label: 'Choose video from device',
          icon: Icons.upload_rounded,
          onPressed: () => _beginImport(appState),
        ),
        if (_importError != null) ...[
          const SizedBox(height: Gaps.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
              const SizedBox(width: Gaps.sm),
              Flexible(
                child: Text(
                  'Import failed: $_importError',
                  style: const TextStyle(fontSize: 12.5, color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDropZone(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          const Icon(Icons.movie_creation_outlined, color: AppColors.textMuted, size: 32),
          const SizedBox(height: Gaps.sm),
          Text(
            'MP4, MOV up to 4GB',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingState(BuildContext context, AppState appState) {
    final step = ProcessingStep.pipeline[appState.processingStageIndex];

    return _CenteredScrollable(
      children: [
        Text('Processing your video', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          appState.project?.fileName ?? '',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: Gaps.xl),
        CircularStepProgress(
          progress:
              (appState.processingStageIndex + _stageProgress) / ProcessingStep.pipeline.length,
          currentStep: appState.processingStageIndex + 1,
          totalSteps: ProcessingStep.pipeline.length,
        ),
        const SizedBox(height: Gaps.lg),
        Text(step.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
          child: Text(
            step.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: Gaps.xl),
        ...List.generate(ProcessingStep.pipeline.length, (i) {
          final s = ProcessingStep.pipeline[i];
          final state = i < appState.processingStageIndex
              ? _StepState.done
              : i == appState.processingStageIndex
                  ? _StepState.active
                  : _StepState.pending;
          return _StepRow(step: s, state: state);
        }),
      ],
    );
  }

  Widget _buildCompleteState(BuildContext context, AppState appState) {
    return _CenteredScrollable(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.black, size: 44),
        ),
        const SizedBox(height: Gaps.lg),
        Text('Your video is ready', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Gaps.sm),
        Text(
          '${appState.project!.fileName} is imported. Head to the editor to '
          'remove silence, generate captions, and find shareable clips.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Gaps.xl),
        GradientButton(
          label: 'Open editor',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.editor),
        ),
      ],
    );
  }
}

/// Centers [children] vertically within the available height, scrolling
/// instead of overflowing on short screens (small phones, split-screen,
/// or a keyboard eating vertical space).
class _CenteredScrollable extends StatelessWidget {
  final List<Widget> children;

  const _CenteredScrollable({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Gaps.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

enum _StepState { pending, active, done }

class _StepRow extends StatelessWidget {
  final ProcessingStep step;
  final _StepState state;

  const _StepRow({required this.step, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color iconColor = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.active => AppColors.accentEnd,
      _StepState.pending => AppColors.textMuted,
    };
    final IconData icon = switch (state) {
      _StepState.done => Icons.check_circle_rounded,
      _StepState.active => Icons.autorenew_rounded,
      _StepState.pending => Icons.radio_button_unchecked_rounded,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: Text(
              step.title,
              style: TextStyle(
                color: state == _StepState.pending
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                fontWeight: state == _StepState.active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
