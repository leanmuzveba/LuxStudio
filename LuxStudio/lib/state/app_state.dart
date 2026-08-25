import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ai_clip.dart';
import '../models/brand_settings.dart';
import '../models/export_destination.dart';
import '../models/processing_step.dart';
import '../models/silence_range.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';
import '../services/brand_settings_store.dart';
import '../services/ffmpeg_service.dart';
import '../services/gemini_service.dart';
import '../services/project_store.dart';

/// Where a clip export currently stands.
enum ExportStatus { idle, processing, completed, failed }

/// App-wide state for the LuxStudio flow, shared across the four screens
/// via a single [ChangeNotifier] (see main.dart for how it's provided).
///
/// This intentionally avoids a state-management package — the flow is
/// linear and small enough that a plain ChangeNotifier plus
/// [AnimatedBuilder]/[ListenableBuilder] keeps the example dependency-free.
class AppState extends ChangeNotifier {
  AppState({
    ProjectStore? projectStore,
    FfmpegService? ffmpegService,
    GeminiService? geminiService,
    BrandSettingsStore? brandSettingsStore,
    Future<Directory> Function()? documentsDirProvider,
  })  : _projectStore = projectStore ?? ProjectStore(),
        _ffmpegService = ffmpegService ?? FfmpegService(),
        _geminiService = geminiService ?? GeminiService(),
        _brandSettingsStore = brandSettingsStore ?? BrandSettingsStore(),
        _documentsDirProvider = documentsDirProvider ?? getApplicationDocumentsDirectory;

  final ProjectStore _projectStore;
  final FfmpegService _ffmpegService;
  final GeminiService _geminiService;
  final BrandSettingsStore _brandSettingsStore;
  final Future<Directory> Function() _documentsDirProvider;

  VideoProject? project;

  /// Global branding (logo + org name) — set in the Settings screen,
  /// applied across exports when enabled. Refresh with
  /// [reloadBrandSettings] after the user edits it there.
  BrandSettings brandSettings = BrandSettings.empty;

  /// Which pipeline stage the import screen is currently animating.
  int processingStageIndex = 0;
  bool processingComplete = false;

  final List<TranscriptSegment> transcript = [];
  final List<AiClip> suggestedClips = [];

  List<SilenceRange> silenceRanges = [];
  bool isDetectingSilence = false;
  bool isApplyingSilenceRemoval = false;
  String? silenceError;

  bool isTranscribing = false;
  String? transcriptionError;

  bool isGeneratingClips = false;
  String? clipGenerationError;

  bool isGeneratingSocialCopy = false;
  String? socialCopyError;

  ExportStatus exportStatus = ExportStatus.idle;
  String? exportError;
  String? lastExportPath;

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

  List<String> generatedCaptions = [];

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
    generatedCaptions = [];
    socialCopyError = null;
    exportStatus = ExportStatus.idle;
    exportError = null;
    lastExportPath = null;
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

  /// Extracts the current working file's audio track and sends it to
  /// Gemini for transcription, replacing the transcript with the result.
  Future<void> transcribeAudio() async {
    final currentProject = project;
    if (currentProject == null) return;
    isTranscribing = true;
    transcriptionError = null;
    notifyListeners();
    try {
      final audioPath = _extractedAudioPath(currentProject.sourcePath);
      await _ffmpegService.extractAudio(currentProject.workingPath, audioPath);
      final audioBytes = File(audioPath).readAsBytesSync();
      final segments = await _geminiService.transcribe(audioBytes, 'audio/aac');
      transcript
        ..clear()
        ..addAll(segments);
    } catch (e) {
      transcriptionError = e.toString();
    } finally {
      isTranscribing = false;
      _notifyAndSave();
    }
  }

  String _extractedAudioPath(String sourcePath) {
    final dotIndex = sourcePath.lastIndexOf('.');
    final base = dotIndex == -1 ? sourcePath : sourcePath.substring(0, dotIndex);
    return '${base}_audio.m4a';
  }

  /// Asks Gemini to find short-form clip candidates in the current
  /// transcript, replacing any previous suggestions. Requires a
  /// transcript — captions must be generated first.
  Future<void> generateClipSuggestions() async {
    if (project == null) return;
    if (transcript.isEmpty) {
      clipGenerationError = 'Transcribe captions first.';
      notifyListeners();
      return;
    }
    isGeneratingClips = true;
    clipGenerationError = null;
    notifyListeners();
    try {
      final clips = await _geminiService.suggestClips(transcript);
      suggestedClips
        ..clear()
        ..addAll(clips);
    } catch (e) {
      clipGenerationError = e.toString();
    } finally {
      isGeneratingClips = false;
      _notifyAndSave();
    }
  }

  /// Asks Gemini to write ready-to-post social captions for the currently
  /// selected clip, replacing any previous suggestions.
  Future<void> generateSocialCopy() async {
    final clip = selectedClip;
    if (clip == null) return;
    isGeneratingSocialCopy = true;
    socialCopyError = null;
    notifyListeners();
    try {
      generatedCaptions = await _geminiService.generateSocialCaptions(
        transcript: transcript,
        clip: clip,
      );
      selectedCaptionIndex = 0;
    } catch (e) {
      socialCopyError = e.toString();
    } finally {
      isGeneratingSocialCopy = false;
      _notifyAndSave();
    }
  }

  /// Refreshes [brandSettings] from disk — call after the user edits
  /// branding in the Settings screen.
  Future<void> reloadBrandSettings() async {
    brandSettings = await _brandSettingsStore.load();
    notifyListeners();
  }

  /// Renders the selected clip as a 1080×1920 MP4 — trimmed to its time
  /// range, with matching transcript lines burned in as captions and
  /// branding applied per the enabled presets — saved under the app's
  /// documents directory with a meaningful filename.
  Future<void> exportSelectedClip() async {
    final currentProject = project;
    final clip = selectedClip;
    if (currentProject == null || clip == null) return;

    exportStatus = ExportStatus.processing;
    exportError = null;
    notifyListeners();
    try {
      final exportsDir = Directory('${(await _documentsDirProvider()).path}/exports');
      if (!exportsDir.existsSync()) exportsDir.createSync(recursive: true);

      String? subtitlesPath;
      final clipLines = transcript
          .where((s) => !s.isSilence && s.text.trim().isNotEmpty && s.end > clip.start && s.start < clip.end)
          .toList();
      if (clipLines.isNotEmpty) {
        subtitlesPath = '${exportsDir.path}/${clip.id}.srt';
        File(subtitlesPath).writeAsStringSync(_buildSrt(clipLines, clip.start));
      }

      final watermarkOn = _brandingEnabled('watermark');
      final lowerThirdOn = _brandingEnabled('lower_third');
      final logoPath = watermarkOn ? brandSettings.logoPath : null;
      final orgName = brandSettings.organizationName.trim();
      final lowerThirdText = (lowerThirdOn && orgName.isNotEmpty) ? orgName : null;

      final outputPath =
          '${exportsDir.path}/${_sanitizeFileName(clip.title)}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      await _ffmpegService.exportClip(
        sourcePath: currentProject.workingPath,
        start: clip.start,
        end: clip.end,
        outputPath: outputPath,
        subtitlesPath: subtitlesPath,
        logoPath: logoPath,
        lowerThirdText: lowerThirdText,
      );

      lastExportPath = outputPath;
      exportStatus = ExportStatus.completed;
    } catch (e) {
      exportError = e.toString();
      exportStatus = ExportStatus.failed;
    } finally {
      _notifyAndSave();
    }
  }

  bool _brandingEnabled(String presetId) {
    for (final preset in brandingPresets) {
      if (preset.id == presetId) return preset.enabled;
    }
    return false;
  }

  String _buildSrt(List<TranscriptSegment> segments, Duration clipStart) {
    final buffer = StringBuffer();
    var index = 0;
    for (final segment in segments) {
      final end = segment.end - clipStart;
      if (end <= Duration.zero) continue;
      final start = segment.start - clipStart;
      final clampedStart = start < Duration.zero ? Duration.zero : start;
      index++;
      buffer
        ..writeln(index)
        ..writeln('${_srtTimestamp(clampedStart)} --> ${_srtTimestamp(end)}')
        ..writeln(segment.text)
        ..writeln();
    }
    return buffer.toString();
  }

  String _srtTimestamp(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  String _sanitizeFileName(String title) {
    final safe = title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_');
    final trimmed = safe.replaceAll(RegExp(r'^_|_$'), '');
    return trimmed.isEmpty ? 'clip' : trimmed;
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

}

enum EditorTool { captions, audio, aiCuts, overlays }
