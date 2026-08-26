import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ai_clip.dart';
import '../models/brand_settings.dart';
import '../models/caption_style.dart';
import '../models/export_destination.dart';
import '../models/export_job.dart';
import '../models/silence_range.dart';
import '../models/social_copy.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';
import '../services/brand_settings_store.dart';
import '../services/ffmpeg_service.dart';
import '../services/gemini_service.dart';
import '../services/project_store.dart';

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

  /// The clip the user chose to edit & export.
  AiClip? selectedClip;

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

  /// Structured social copy for [selectedClip].
  SocialCopy? socialCopy;

  /// How burned-in captions are styled at export — set on the Captions
  /// screen's style picker, feeds [_renderClip].
  CaptionStyle captionStyle = CaptionStyle.defaultStyle;

  /// One entry per clip currently in (or finished with) a batch export,
  /// keyed by [AiClip.id]. Populated by [exportBatch]/[retryClipExport].
  Map<String, ExportJob> exportJobs = {};

  void updateProjectTitle(String newTitle) {
    final currentProject = project;
    if (currentProject == null) return;
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    currentProject.title = trimmed;
    _notifyAndSave();
  }

  void startImport(VideoProject newProject) {
    project = newProject;
    _notifyAndSave();
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
    socialCopy = null;
    socialCopyError = null;
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
  /// [noiseFloorDb]/[minDuration] mirror [FfmpegService.detectSilence]'s
  /// defaults so callers that don't care can omit them.
  Future<void> detectSilence({
    double noiseFloorDb = -30,
    Duration minDuration = const Duration(milliseconds: 500),
  }) async {
    final currentProject = project;
    if (currentProject == null) return;
    isDetectingSilence = true;
    silenceError = null;
    notifyListeners();
    try {
      silenceRanges = await _ffmpegService.detectSilence(
        currentProject.sourcePath,
        noiseFloorDb: noiseFloorDb,
        minDuration: minDuration,
      );
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

  void toggleClipIncludeInExport(String clipId) {
    final clip = _findClip(clipId);
    if (clip == null) return;
    clip.includeInExport = !clip.includeInExport;
    _notifyAndSave();
  }

  void setAllSilenceRangesAccepted(bool accepted) {
    for (final range in silenceRanges) {
      range.accepted = accepted;
    }
    _notifyAndSave();
  }

  void updateCaptionStyle(CaptionStyle style) {
    captionStyle = style;
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

  /// Asks Gemini to write ready-to-post social copy for the currently
  /// selected clip, replacing any previous suggestions.
  Future<void> generateSocialCopy() async {
    final clip = selectedClip;
    if (clip == null) return;
    isGeneratingSocialCopy = true;
    socialCopyError = null;
    notifyListeners();
    try {
      final copy = await _geminiService.generateSocialCopy(
        transcript: transcript,
        clip: clip,
      );
      socialCopy = copy;
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

  /// Whether a batch export ([exportBatch]) is currently running.
  bool isBatchExporting = false;

  /// Renders every [AiClip.includeInExport] clip in [suggestedClips] as a
  /// 1080×1920 MP4, one at a time (sequential — concurrent ffmpeg sessions
  /// are too heavy for a phone), tracking each clip's progress in
  /// [exportJobs] so the Export screen can show independent per-clip rows.
  Future<void> exportBatch() async {
    final currentProject = project;
    if (currentProject == null) return;
    final clips = suggestedClips.where((c) => c.includeInExport).toList();
    if (clips.isEmpty) return;

    isBatchExporting = true;
    for (final clip in clips) {
      exportJobs[clip.id] = const ExportJob(status: ExportJobStatus.queued);
    }
    notifyListeners();

    for (final clip in clips) {
      await _runClipExportJob(clip);
    }

    isBatchExporting = false;
    notifyListeners();
  }

  /// Re-renders a single clip that previously failed (or finished) —
  /// exposed so the Export screen can offer a retry on a failed row
  /// without re-running the whole batch.
  Future<void> retryClipExport(AiClip clip) => _runClipExportJob(clip);

  Future<void> _runClipExportJob(AiClip clip) async {
    exportJobs[clip.id] = const ExportJob(status: ExportJobStatus.processing);
    notifyListeners();
    try {
      final outputPath = await _renderClip(clip);
      exportJobs[clip.id] = ExportJob(status: ExportJobStatus.done, outputPath: outputPath, progress: 1);
      project?.hasExported = true;
    } catch (e) {
      exportJobs[clip.id] = ExportJob(status: ExportJobStatus.failed, error: e.toString());
    }
    _notifyAndSave();
  }

  /// Renders [clip] as a 1080×1920 MP4 — trimmed to its time range, with
  /// matching transcript lines burned in as captions (styled per
  /// [captionStyle]) and branding applied per the enabled presets — saved
  /// under the app's documents directory with a meaningful filename.
  /// Shared by [exportBatch] and [retryClipExport].
  Future<String> _renderClip(AiClip clip) async {
    final currentProject = project!;
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
      forceStyle: subtitlesPath == null ? null : captionStyle.assForceStyle,
      logoPath: logoPath,
      lowerThirdText: lowerThirdText,
    );

    return outputPath;
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
    _applySnapshot(snapshot);
    notifyListeners();
  }

  /// Switches the active project to [snapshot] — used when the user taps
  /// a card on the Home dashboard's recent-projects list. Same shape as
  /// [tryRecoverLastProject], but explicitly chosen rather than the last
  /// one open, and persists immediately so it becomes the new "last open"
  /// project for the next app launch.
  void openProject(ProjectSnapshot snapshot) {
    _applySnapshot(snapshot);
    _notifyAndSave();
  }

  void _applySnapshot(ProjectSnapshot snapshot) {
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
    socialCopy = snapshot.socialCopy;
    captionStyle = snapshot.captionStyle;
    exportJobs = snapshot.exportJobs;
  }

  /// Every saved project, most recently updated first — backs the Home
  /// dashboard's recent-projects list. Call again (e.g. after returning
  /// from Import or the editor) to pick up changes.
  List<ProjectSnapshot> recentProjects = [];
  bool isLoadingRecentProjects = false;

  Future<void> loadRecentProjects() async {
    isLoadingRecentProjects = true;
    notifyListeners();
    recentProjects = await _projectStore.listAll();
    isLoadingRecentProjects = false;
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
    currentProject.updatedAt = DateTime.now();
    await _projectStore.save(ProjectSnapshot(
      project: currentProject,
      transcript: transcript,
      suggestedClips: suggestedClips,
      silenceRanges: silenceRanges,
      selectedClipId: selectedClip?.id,
      brandingPresets: brandingPresets,
      captionStyle: captionStyle,
      socialCopy: socialCopy,
      exportJobs: exportJobs,
    ));
  }
}
