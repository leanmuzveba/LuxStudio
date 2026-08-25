import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ai_clip.dart';
import '../models/export_destination.dart';
import '../models/processing_step.dart';
import '../models/silence_range.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';
import '../services/ffmpeg_service.dart';
import '../services/project_store.dart';

/// App-wide state for the LuxStudio flow, shared across the four screens
/// via a single [ChangeNotifier] (see main.dart for how it's provided).
///
/// This intentionally avoids a state-management package — the flow is
/// linear and small enough that a plain ChangeNotifier plus
/// [AnimatedBuilder]/[ListenableBuilder] keeps the example dependency-free.
class AppState extends ChangeNotifier {
  AppState({ProjectStore? projectStore, FfmpegService? ffmpegService})
      : _projectStore = projectStore ?? ProjectStore(),
        _ffmpegService = ffmpegService ?? FfmpegService();

  final ProjectStore _projectStore;
  final FfmpegService _ffmpegService;

  VideoProject? project;

  /// Which pipeline stage the import screen is currently animating.
  int processingStageIndex = 0;
  bool processingComplete = false;

  final List<TranscriptSegment> transcript = [];
  final List<AiClip> suggestedClips = [];

  List<SilenceRange> silenceRanges = [];
  bool isDetectingSilence = false;
  bool isApplyingSilenceRemoval = false;
  String? silenceError;

  /// Currently active bottom tool on the editor screen.
  EditorTool activeTool = EditorTool.captions;

  /// The clip the user chose to edit & export.
  AiClip? selectedClip;

  final Set<ExportPlatform> selectedDestinations = {ExportPlatform.reels};
  int selectedCaptionIndex = 0;
  final List<BrandingPreset> brandingPresets = [
    BrandingPreset(
      id: 'watermark',
      label: 'Logo watermark',
      description: 'Small church logo, bottom-right corner.',
      enabled: true,
    ),
    BrandingPreset(
      id: 'lower_third',
      label: 'Lower third',
      description: 'Speaker name & sermon title on first 3s.',
      enabled: true,
    ),
    BrandingPreset(
      id: 'color_grade',
      label: 'Signature color grade',
      description: 'Warm, high-contrast look applied automatically.',
      enabled: false,
    ),
  ];

  List<String> generatedCaptions = [
    "You weren't made to carry this alone. 🙏 Full message linked in bio.",
    'This 45 seconds might change how you see this week. #faith #sermon',
    'Watch till the end — the last line hits different.',
  ];

  void startImport(VideoProject newProject) {
    project = newProject;
    processingStageIndex = 0;
    processingComplete = false;
    _notifyAndSave();
  }

  void advanceProcessingStage() {
    if (processingStageIndex < ProcessingStep.pipeline.length - 1) {
      processingStageIndex++;
    } else {
      processingComplete = true;
      _seedTranscriptAndClips();
    }
    _notifyAndSave();
  }

  void setActiveTool(EditorTool tool) {
    activeTool = tool;
    notifyListeners();
  }

  void updateTranscriptText(String segmentId, String newText) {
    final segment = transcript.firstWhere((s) => s.id == segmentId);
    segment.text = newText;
    _notifyAndSave();
  }

  void toggleMarkForCut(String segmentId) {
    final segment = transcript.firstWhere((s) => s.id == segmentId);
    segment.isMarkedForCut = !segment.isMarkedForCut;
    _notifyAndSave();
  }

  void chooseClip(AiClip clip) {
    selectedClip = clip;
    selectedDestinations
      ..clear()
      ..add(ExportPlatform.reels);
    selectedCaptionIndex = 0;
    _notifyAndSave();
  }

  void toggleDestination(ExportPlatform platform) {
    if (selectedDestinations.contains(platform)) {
      if (selectedDestinations.length > 1) {
        selectedDestinations.remove(platform);
      }
    } else {
      selectedDestinations.add(platform);
    }
    _notifyAndSave();
  }

  void selectCaption(int index) {
    selectedCaptionIndex = index;
    _notifyAndSave();
  }

  void toggleBranding(String id) {
    final preset = brandingPresets.firstWhere((p) => p.id == id);
    preset.enabled = !preset.enabled;
    _notifyAndSave();
  }

  /// Runs silence detection against the project's original sandboxed copy
  /// (not the current working file — always the same source timeline, so
  /// re-detecting after edits doesn't compound against a previous trim).
  Future<void> detectSilence() async {
    final currentProject = project;
    if (currentProject == null) return;
    isDetectingSilence = true;
    silenceError = null;
    notifyListeners();
    try {
      silenceRanges = await _ffmpegService.detectSilence(currentProject.sourcePath);
    } catch (e) {
      silenceError = e.toString();
    } finally {
      isDetectingSilence = false;
      _notifyAndSave();
    }
  }

  void toggleSilenceRangeAccepted(int index) {
    if (index < 0 || index >= silenceRanges.length) return;
    silenceRanges[index].accepted = !silenceRanges[index].accepted;
    _notifyAndSave();
  }

  /// Cuts every accepted range out of the original source, closes the
  /// gaps, and points the project at the resulting file. Re-running this
  /// (e.g. after toggling which ranges are accepted) overwrites the same
  /// trimmed output rather than trimming an already-trimmed file.
  Future<void> applySilenceRemoval() async {
    final currentProject = project;
    if (currentProject == null) return;
    final accepted = silenceRanges.where((r) => r.accepted).toList();

    isApplyingSilenceRemoval = true;
    silenceError = null;
    notifyListeners();
    try {
      final outputPath = _trimmedPath(currentProject.sourcePath);
      await _ffmpegService.removeRanges(
        sourcePath: currentProject.sourcePath,
        outputPath: outputPath,
        rangesToRemove: accepted,
      );
      final removed = accepted.fold<Duration>(Duration.zero, (sum, r) => sum + r.duration);
      currentProject.workingPath = outputPath;
      currentProject.processedDuration = currentProject.rawDuration - removed;
    } catch (e) {
      silenceError = e.toString();
    } finally {
      isApplyingSilenceRemoval = false;
      _notifyAndSave();
    }
  }

  /// Reverts to the untouched original — undoes a previously applied
  /// silence removal.
  void restoreOriginalAudio() {
    final currentProject = project;
    if (currentProject == null) return;
    currentProject.workingPath = currentProject.sourcePath;
    currentProject.processedDuration = currentProject.rawDuration;
    silenceRanges = [];
    _notifyAndSave();
  }

  String _trimmedPath(String sourcePath) {
    final dotIndex = sourcePath.lastIndexOf('.');
    if (dotIndex == -1) return '${sourcePath}_trimmed';
    return '${sourcePath.substring(0, dotIndex)}_trimmed${sourcePath.substring(dotIndex)}';
  }

  /// Loads the most recently active project (if any) from disk, so the
  /// user can pick up where they left off after an unexpected close.
  /// Silently does nothing if there's nothing to recover — see
  /// [ProjectStore]'s doc for why this never throws.
  Future<void> tryRecoverLastProject() async {
    final snapshot = await _projectStore.loadLast();
    if (snapshot == null) return;

    project = snapshot.project;
    transcript
      ..clear()
      ..addAll(snapshot.transcript);
    suggestedClips
      ..clear()
      ..addAll(snapshot.suggestedClips);
    silenceRanges = snapshot.silenceRanges;
    selectedClip = snapshot.selectedClipId == null
        ? null
        : _findClip(snapshot.selectedClipId!);
    brandingPresets
      ..clear()
      ..addAll(snapshot.brandingPresets);
    selectedCaptionIndex = snapshot.selectedCaptionIndex;
    generatedCaptions = snapshot.generatedCaptions;
    selectedDestinations
      ..clear()
      ..addAll(snapshot.selectedDestinations);
    processingStageIndex = snapshot.processingStageIndex;
    processingComplete = snapshot.processingComplete;
    notifyListeners();
  }

  AiClip? _findClip(String id) {
    for (final clip in suggestedClips) {
      if (clip.id == id) return clip;
    }
    return null;
  }

  void _notifyAndSave() {
    notifyListeners();
    unawaited(_autosave());
  }

  Future<void> _autosave() async {
    final currentProject = project;
    if (currentProject == null) return;
    await _projectStore.save(ProjectSnapshot(
      project: currentProject,
      transcript: transcript,
      suggestedClips: suggestedClips,
      silenceRanges: silenceRanges,
      selectedClipId: selectedClip?.id,
      brandingPresets: brandingPresets,
      selectedCaptionIndex: selectedCaptionIndex,
      generatedCaptions: generatedCaptions,
      selectedDestinations: selectedDestinations,
      processingStageIndex: processingStageIndex,
      processingComplete: processingComplete,
    ));
  }

  void _seedTranscriptAndClips() {
    transcript
      ..clear()
      ..addAll(_mockTranscript());
    suggestedClips
      ..clear()
      ..addAll(_mockClips());
  }

  List<TranscriptSegment> _mockTranscript() {
    final lines = <List<Object>>[
      [0, 6, "Good morning, church. It's good to see every one of you today."],
      [6, 8, '', true], // silence gap, collapsed in the UI
      [8, 19, "I want to talk about something that's been on my heart all week — the idea that faith isn't the absence of fear."],
      [19, 27, "It's choosing to move forward anyway, one step, even when your hands are shaking."],
      [27, 29, '', true],
      [29, 41, "Because here's the truth: nobody who's ever done anything worth doing felt fully ready when they started."],
      [41, 52, "Noah didn't feel ready. Moses didn't feel ready. You are not required to feel ready — you're required to be willing."],
    ];

    var id = 0;
    return lines.map((row) {
      id++;
      final start = Duration(seconds: row[0] as int);
      final end = Duration(seconds: row[1] as int);
      final isSilence = row.length > 3 && row[3] == true;
      return TranscriptSegment(
        id: 's$id',
        start: start,
        end: end,
        text: row[2] as String,
        isSilence: isSilence,
      );
    }).toList();
  }

  List<AiClip> _mockClips() {
    return const [
      AiClip(
        id: 'c1',
        title: "Faith isn't the absence of fear",
        start: Duration(seconds: 8),
        end: Duration(seconds: 27),
        viralScore: 98,
        reason: 'Strong hook + emotional payoff in first 3 seconds.',
      ),
      AiClip(
        id: 'c2',
        title: 'You are not required to feel ready',
        start: Duration(seconds: 29),
        end: Duration(seconds: 52),
        viralScore: 91,
        reason: 'Quotable closing line, high rewatch potential.',
      ),
      AiClip(
        id: 'c3',
        title: 'Good morning, church',
        start: Duration(seconds: 0),
        end: Duration(seconds: 6),
        viralScore: 62,
        reason: 'Low energy opener — works better as a Story teaser.',
      ),
    ];
  }
}

enum EditorTool { captions, audio, aiCuts, overlays }
