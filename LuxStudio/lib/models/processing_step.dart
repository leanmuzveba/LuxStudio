/// One stage of the AI import pipeline shown on the processing screen.
///
/// LuxStudio runs a raw sermon recording through a fixed pipeline before
/// the user ever sees the editor: strip dead air, clean up the audio,
/// find candidate short-form clips, then caption everything.
enum ProcessingStage {
  silenceRemoval,
  audioEnhancement,
  clipIdentification,
  autoCaptioning,
}

class ProcessingStep {
  final ProcessingStage stage;
  final String title;
  final String description;
  final Duration estimatedDuration;

  const ProcessingStep({
    required this.stage,
    required this.title,
    required this.description,
    required this.estimatedDuration,
  });

  static const List<ProcessingStep> pipeline = [
    ProcessingStep(
      stage: ProcessingStage.silenceRemoval,
      title: 'Removing silence',
      description: 'Trimming dead air and long pauses from the raw take.',
      estimatedDuration: Duration(seconds: 3),
    ),
    ProcessingStep(
      stage: ProcessingStage.audioEnhancement,
      title: 'Enhancing audio',
      description: 'Reducing room noise and levelling out the mic gain.',
      estimatedDuration: Duration(seconds: 3),
    ),
    ProcessingStep(
      stage: ProcessingStage.clipIdentification,
      title: 'Finding key moments',
      description: 'Scoring segments for pacing, energy, and quotability.',
      estimatedDuration: Duration(seconds: 4),
    ),
    ProcessingStep(
      stage: ProcessingStage.autoCaptioning,
      title: 'Auto-captioning',
      description: 'Transcribing speech and aligning word-level timing.',
      estimatedDuration: Duration(seconds: 3),
    ),
  ];
}
