import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/ai_clip.dart';
import '../models/brand_settings.dart';
import '../models/caption_style.dart';
import '../models/export_destination.dart';
import '../models/silence_range.dart';
import '../models/social_copy.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';
import '../services/api_client.dart';
import '../services/brand_settings_store.dart';
import '../services/project_store.dart';

/// App-wide state for the LuxStudio flow, shared across the four screens
/// via a single [ChangeNotifier] (see main.dart for how it's provided).
///
/// This intentionally avoids a state-management package — the flow is
/// linear and small enough that a plain ChangeNotifier plus
/// [AnimatedBuilder]/[ListenableBuilder] keeps the example dependency-free.
///
/// Since the backend pivot, every AI/FFmpeg operation goes through
/// [ApiClient] to the LuxStudio backend instead of calling
/// `google_generative_ai`/`ffmpeg_kit_flutter_new` directly on-device —
/// neither the Gemini key nor an ffmpeg binary ever touches the client.
class AppState extends ChangeNotifier {
  AppState({
    ProjectStore? projectStore,
    ApiClient? apiClient,
    BrandSettingsStore? brandSettingsStore,
  })  : _projectStore = projectStore ?? ProjectStore(),
        _apiClient = apiClient ?? ApiClient(),
        _brandSettingsStore = brandSettingsStore ?? BrandSettingsStore();

  final ProjectStore _projectStore;
  final ApiClient _apiClient;
  final BrandSettingsStore _brandSettingsStore;

  VideoProject? project;

  /// The backend's base URL — for building full URLs from the
  /// backend-relative paths its responses hand back (e.g.
  /// [BrandSettings.logoUrl]).
  String get backendBaseUrl => _apiClient.baseUrl;

  /// The URL the video player should stream from for the current project's
  /// working (or, before analysis, original) copy — see the backend's
  /// `GET /projects/{id}/video`. Null with no project loaded.
  String? get currentVideoUrl {
    final currentProject = project;
    if (currentProject == null) return null;
    return '$backendBaseUrl/projects/${currentProject.backendProjectId}/video';
  }

  /// Global branding (logo + org name) — set in the Settings screen,
  /// applied across exports when enabled. Refresh with
  /// [reloadBrandSettings] after the user edits it there.
  BrandSettings brandSettings = BrandSettings.seeded;

  final List<TranscriptSegment> transcript = [];
  final List<AiClip> suggestedClips = [];

  List<SilenceRange> silenceRanges = [];

  // --- Automatic analyse pipeline (backend Phase 3's atomic /analyse job:
  // silence removal -> audio enhancement -> transcription -> clip
  // suggestion, all in one background run) ---------------------------------

  String analyseStatus = 'idle'; // idle | running | done | error
  String? analyseStep; // silence_removal | audio_enhancement | clip_identification | captioning
  int analysePercent = 0;
  String? analyseError;

  /// Kicks off the backend's automatic analysis pipeline for the current
  /// project (if not already running/done — memoized per project so the
  /// old Silence/Captions/Clips screens' separate triggers, below, don't
  /// each re-run the whole pipeline) and polls until it finishes.
  Future<void> runAnalysePipeline() async {
    final currentProject = project;
    if (currentProject == null) return;
    if (analyseStatus == 'done' || analyseStatus == 'running') return;

    analyseStatus = 'running';
    analyseError = null;
    notifyListeners();
    try {
      await _apiClient.postJson('/projects/${currentProject.backendProjectId}/analyse', {});
      while (true) {
        await Future.delayed(const Duration(milliseconds: 800));
        final status =
            await _apiClient.getJson('/projects/${currentProject.backendProjectId}/analyse/status');
        analyseStep = status['step'] as String?;
        analysePercent = (status['percent'] as num?)?.toInt() ?? 0;
        final s = status['status'] as String? ?? 'error';
        if (s == 'done') {
          analyseStatus = 'done';
          await _loadAnalyseResults();
          break;
        }
        if (s == 'error') {
          analyseStatus = 'error';
          analyseError = status['error'] as String? ?? 'Analysis failed.';
          break;
        }
        notifyListeners();
      }
    } catch (e) {
      analyseStatus = 'error';
      analyseError = e.toString();
    } finally {
      _notifyAndSave();
    }
  }

  Future<void> _loadAnalyseResults() async {
    final currentProject = project;
    if (currentProject == null) return;
    final meta = await _apiClient.getJson('/projects/${currentProject.backendProjectId}');

    silenceRanges = ((meta['silence_ranges'] as List?) ?? [])
        .map((e) => SilenceRange.fromJson(e as Map<String, dynamic>))
        .toList();
    transcript
      ..clear()
      ..addAll(
        ((meta['transcript'] as List?) ?? [])
            .map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>)),
      );
    suggestedClips
      ..clear()
      ..addAll(
        ((meta['clips'] as List?) ?? []).map((e) => AiClip.fromJson(e as Map<String, dynamic>)),
      );
  }

  // --- Phase 5→9 transitional aliases --------------------------------------
  // The old Silence/Captions/Clips screens still call these by name; each
  // now just ensures the one automatic backend pipeline has run and
  // surfaces its slice of the result, since the backend has no standalone
  // per-step endpoints (by design — the new Analyse screen represents this
  // as one automatic job). Removed once Phase 9 replaces those screens with
  // the new Analyse screen, which calls runAnalysePipeline() directly.

  bool isDetectingSilence = false;
  String? silenceError;

  /// [noiseFloorDb]/[minDuration] are no longer configurable — the backend
  /// pipeline uses fixed defaults. Kept as parameters so the existing
  /// Silence screen call site compiles unchanged.
  Future<void> detectSilence({
    double noiseFloorDb = -30,
    Duration minDuration = const Duration(milliseconds: 500),
  }) async {
    await runAnalysePipeline();
    isDetectingSilence = analyseStatus == 'running';
    silenceError = analyseError;
    notifyListeners();
  }

  bool isApplyingSilenceRemoval = false;

  /// Removal already happens automatically server-side as part of
  /// analysis — this just ensures the pipeline has run.
  Future<void> applySilenceRemoval() async {
    await runAnalysePipeline();
    isApplyingSilenceRemoval = analyseStatus == 'running';
    silenceError = analyseError;
    notifyListeners();
  }

  bool isTranscribing = false;
  String? transcriptionError;

  Future<void> transcribeAudio() async {
    await runAnalysePipeline();
    isTranscribing = analyseStatus == 'running';
    transcriptionError = analyseError;
    notifyListeners();
  }

  bool isGeneratingClips = false;
  String? clipGenerationError;

  Future<void> generateClipSuggestions() async {
    await runAnalysePipeline();
    isGeneratingClips = analyseStatus == 'running';
    clipGenerationError = analyseError;
    notifyListeners();
  }

  // --- End transitional aliases ---------------------------------------------

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
    analyseStatus = 'idle';
    analyseStep = null;
    analysePercent = 0;
    analyseError = null;
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
    exportedDownloadPath = null;
    exportError = null;
    _notifyAndSave();
  }

  void toggleBranding(String id) {
    final preset = brandingPresets.firstWhere((p) => p.id == id);
    preset.enabled = !preset.enabled;
    _notifyAndSave();
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

  /// Asks the backend to write ready-to-post social copy for the currently
  /// selected clip, replacing any previous suggestions.
  Future<void> generateSocialCopy() async {
    final clip = selectedClip;
    final currentProject = project;
    if (clip == null || currentProject == null) return;
    isGeneratingSocialCopy = true;
    socialCopyError = null;
    notifyListeners();
    try {
      final response = await _apiClient.postJson(
        '/projects/${currentProject.backendProjectId}/social-copy',
        {
          'transcript': transcript.map((s) => s.toJson()).toList(),
          'clip': clip.toJson(),
        },
      );
      socialCopy = SocialCopy.fromJson(response);
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

  /// Whether [exportSelectedClip] is currently running.
  bool isExportingClip = false;
  String? exportError;

  /// The backend-relative path the most recent export can be downloaded
  /// from (see [downloadExport]) — null until [exportSelectedClip]
  /// succeeds for the current [selectedClip]; reset whenever a different
  /// clip is chosen (see [chooseClip]).
  String? exportedDownloadPath;

  /// Renders [selectedClip] as a 1080×1920 MP4 via the backend — the
  /// Share screen's primary action.
  Future<void> exportSelectedClip() async {
    final clip = selectedClip;
    if (clip == null) return;
    isExportingClip = true;
    exportError = null;
    notifyListeners();
    try {
      exportedDownloadPath = await _renderClip(clip);
      project?.hasExported = true;
    } catch (e) {
      exportError = e.toString();
    } finally {
      isExportingClip = false;
      _notifyAndSave();
    }
  }

  /// Renders [clip] as a 1080×1920 MP4 via the backend — trimmed to its
  /// time range, with matching transcript lines burned in as captions
  /// (styled per [captionStyle]) and branding applied per the enabled
  /// presets. Returns the backend-relative path the finished file can be
  /// downloaded from (see [downloadExport]).
  Future<String> _renderClip(AiClip clip) async {
    final currentProject = project!;

    String? subtitlesSrt;
    final clipLines = transcript
        .where((s) => !s.isSilence && s.text.trim().isNotEmpty && s.end > clip.start && s.start < clip.end)
        .toList();
    if (clipLines.isNotEmpty) {
      subtitlesSrt = _buildSrt(clipLines, clip.start);
    }

    final watermarkOn = _brandingEnabled('watermark');
    final lowerThirdOn = _brandingEnabled('lower_third');
    final orgName = brandSettings.organizationName.trim();
    final lowerThirdText = (lowerThirdOn && orgName.isNotEmpty) ? orgName : null;

    String? logoBase64;
    if (watermarkOn && brandSettings.logoUrl != null) {
      try {
        logoBase64 = base64Encode(await downloadExport(brandSettings.logoUrl!));
      } catch (_) {
        // Best-effort — export still proceeds without the watermark if the
        // logo can't be fetched.
      }
    }

    await _apiClient.postJson(
      '/projects/${currentProject.backendProjectId}/clips/${clip.id}/export',
      {
        if (subtitlesSrt != null) 'subtitles_srt': subtitlesSrt,
        if (subtitlesSrt != null) 'force_style': captionStyle.assForceStyle,
        if (lowerThirdText != null) 'lower_third_text': lowerThirdText,
        if (logoBase64 != null) 'logo_base64': logoBase64,
      },
    );

    return '/projects/${currentProject.backendProjectId}/clips/${clip.id}/export/download';
  }

  /// Fetches bytes from a backend-relative path (an export download route
  /// or the brand logo route) — used wherever a URL the backend handed
  /// back needs to become real bytes on the client (sharing an export,
  /// embedding the logo in a render request).
  Future<Uint8List> downloadExport(String path) => _apiClient.getBytes(path);

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
    exportedDownloadPath = null;
    exportError = null;
    analyseStatus = transcript.isNotEmpty || suggestedClips.isNotEmpty ? 'done' : 'idle';
    analyseStep = null;
    analysePercent = analyseStatus == 'done' ? 100 : 0;
    analyseError = null;
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
    ));
  }
}
