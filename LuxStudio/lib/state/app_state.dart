import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_clip.dart';
import '../models/brand_settings.dart';
import '../models/caption_style.dart';
import '../models/export_destination.dart';
import '../models/export_history_entry.dart';
import '../models/library_asset.dart';
import '../models/library_folder.dart';
import '../models/silence_range.dart';
import '../models/social_copy.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';
import '../services/api_client.dart';
import '../services/auth_store.dart';
import '../services/brand_settings_store.dart';
import '../services/export_history_service.dart';
import '../services/media_library_service.dart';
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
    AuthStore? authStore,
    MediaLibraryService? mediaLibraryService,
    ExportHistoryService? exportHistoryService,
  })  : _projectStore = projectStore ?? ProjectStore(),
        _apiClient = apiClient ?? ApiClient(),
        _brandSettingsStore = brandSettingsStore ?? BrandSettingsStore(),
        _authStore = authStore ?? AuthStore(),
        // Shares the same ApiClient as the rest of AppState (not its own
        // default instance) so a test/dev ApiClient override actually
        // covers Media Library/export-history calls too.
        _mediaLibraryService =
            mediaLibraryService ?? MediaLibraryService(apiClient: apiClient ?? ApiClient()),
        _exportHistoryService =
            exportHistoryService ?? ExportHistoryService(apiClient: apiClient ?? ApiClient());

  final ProjectStore _projectStore;
  final ApiClient _apiClient;
  final BrandSettingsStore _brandSettingsStore;
  final AuthStore _authStore;
  final MediaLibraryService _mediaLibraryService;
  final ExportHistoryService _exportHistoryService;

  // --- Shared church-passcode gate (V2 Decision #1) -----------------------
  // No per-user accounts/sessions: one passcode, checked against the
  // backend's /auth/verify, remembered locally via [AuthStore] once this
  // device passes it. See lib/screens/login_screen.dart.

  bool isUnlocked = false;
  bool isVerifyingPasscode = false;
  String? passcodeError;

  /// Loads whether this device already unlocked the app — call once at
  /// startup (see main.dart) before deciding whether to show the login
  /// screen.
  Future<void> loadAuthStatus() async {
    isUnlocked = await _authStore.isUnlocked();
    notifyListeners();
  }

  /// Checks [passcode] against the backend's shared church passcode.
  /// Returns whether it succeeded; [passcodeError] carries a message for
  /// the login screen to show on failure.
  Future<bool> verifyPasscode(String passcode) async {
    isVerifyingPasscode = true;
    passcodeError = null;
    notifyListeners();
    try {
      await _apiClient.postJson('/auth/verify', {'passcode': passcode});
      isUnlocked = true;
      await _authStore.setUnlocked(true);
      return true;
    } on ApiException catch (e) {
      passcodeError = e.statusCode == 401
          ? 'Incorrect passcode.'
          : "Couldn't reach the studio server.";
      return false;
    } catch (_) {
      passcodeError = "Couldn't reach the studio server.";
      return false;
    } finally {
      isVerifyingPasscode = false;
      notifyListeners();
    }
  }

  /// Re-locks the app on this device — offered from Settings.
  Future<void> signOut() async {
    isUnlocked = false;
    await _authStore.setUnlocked(false);
    notifyListeners();
  }

  // --- Media Library (V2 Decision #2) --------------------------------------
  // Folders + video assets independent of any one project, so the same
  // upload can start more than one project (see
  // [useLibraryAssetAsProject]) — real backend entity, not a mock.

  List<LibraryFolder> libraryFolders = [];
  List<LibraryAsset> libraryAssets = [];
  int libraryUsedBytes = 0;
  int libraryLimitBytes = 0;
  bool isLoadingLibrary = false;
  bool isUploadingLibraryAsset = false;
  String? libraryError;

  /// Loads folders, assets, and the quota summary — call when the Media
  /// Library screen first mounts.
  Future<void> loadLibrary() async {
    isLoadingLibrary = true;
    libraryError = null;
    notifyListeners();
    try {
      libraryFolders = await _mediaLibraryService.listFolders();
      libraryAssets = await _mediaLibraryService.listAssets();
      final quota = await _mediaLibraryService.getQuota();
      libraryUsedBytes = quota.usedBytes;
      libraryLimitBytes = quota.limitBytes;
    } catch (e) {
      libraryError = e.toString();
    } finally {
      isLoadingLibrary = false;
      notifyListeners();
    }
  }

  Future<void> createLibraryFolder(String name) async {
    try {
      final folder = await _mediaLibraryService.createFolder(name);
      libraryFolders = [...libraryFolders, folder];
    } catch (e) {
      libraryError = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteLibraryFolder(String id) async {
    try {
      await _mediaLibraryService.deleteFolder(id);
      libraryFolders = libraryFolders.where((f) => f.id != id).toList();
      // Assets in the deleted folder move to root server-side — mirror
      // that locally instead of re-fetching.
      libraryAssets = libraryAssets
          .map((a) => a.folderId == id ? a.copyWithFolderId(null) : a)
          .toList();
    } catch (e) {
      libraryError = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> uploadLibraryAsset(Uint8List bytes, String filename, {String? folderId}) async {
    isUploadingLibraryAsset = true;
    libraryError = null;
    notifyListeners();
    try {
      final asset = await _mediaLibraryService.uploadAsset(
        bytes: bytes,
        filename: filename,
        folderId: folderId,
      );
      libraryAssets = [...libraryAssets, asset];
      libraryUsedBytes += asset.sizeBytes;
    } catch (e) {
      libraryError = e.toString();
    } finally {
      isUploadingLibraryAsset = false;
      notifyListeners();
    }
  }

  Future<void> deleteLibraryAsset(String id) async {
    try {
      await _mediaLibraryService.deleteAsset(id);
      final removed = libraryAssets.where((a) => a.id == id).toList();
      libraryAssets = libraryAssets.where((a) => a.id != id).toList();
      if (removed.isNotEmpty) libraryUsedBytes -= removed.first.sizeBytes;
    } catch (e) {
      libraryError = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Starts a fresh project from a library asset (server-side copy — see
  /// backend/app/routers/library.py's `/use` endpoint) and makes it the
  /// active project, same as picking a file in the Import screen.
  Future<VideoProject> useLibraryAssetAsProject(String assetId) async {
    final json = await _mediaLibraryService.useAssetAsProject(assetId);
    final durationMs = (json['durationMs'] as num?)?.toInt();
    final project = VideoProject(
      id: json['id'] as String,
      fileName: json['original_filename'] as String? ?? 'asset',
      backendProjectId: json['id'] as String,
      rawDuration: Duration(milliseconds: durationMs ?? 0),
      processedDuration: Duration(milliseconds: durationMs ?? 0),
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      importedAt: DateTime.now(),
      status: ProjectStatus.ready,
    );
    startImport(project);
    return project;
  }

  // --- Export history (V2 Decision #3) -------------------------------------
  // Real history of completed/failed exports, independent of any one
  // project (survives that project being TTL-swept — see
  // backend/app/routers/exports.py). There's no real server-side render
  // queue/progress to mirror here (export is one synchronous call, not
  // concurrent jobs) — [isExportingClip] below already tracks the one
  // possible in-flight export.

  List<ExportHistoryEntry> exportHistory = [];
  bool isLoadingExportHistory = false;
  String? exportHistoryError;

  Future<void> loadExportHistory() async {
    isLoadingExportHistory = true;
    exportHistoryError = null;
    notifyListeners();
    try {
      exportHistory = await _exportHistoryService.list();
    } catch (e) {
      exportHistoryError = e.toString();
    } finally {
      isLoadingExportHistory = false;
      notifyListeners();
    }
  }

  Future<void> deleteExportHistoryEntry(String id) async {
    try {
      await _exportHistoryService.delete(id);
      exportHistory = exportHistory.where((e) => e.id != id).toList();
    } catch (e) {
      exportHistoryError = e.toString();
    } finally {
      notifyListeners();
    }
  }

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

  // The old Silence/Captions screens used to call detectSilence()/
  // applySilenceRemoval()/transcribeAudio() as Phase 5→9 transitional
  // aliases into runAnalysePipeline(); Phase 9 replaced those screens with
  // Analyse (which calls runAnalysePipeline() directly) and Phase 14
  // removed the now-unused aliases. generateClipSuggestions() survives —
  // AI Clips' regenerate action still calls it directly.

  bool isGeneratingClips = false;
  String? clipGenerationError;

  Future<void> generateClipSuggestions() async {
    await runAnalysePipeline();
    isGeneratingClips = analyseStatus == 'running';
    clipGenerationError = analyseError;
    notifyListeners();
  }

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

  /// Splits the segment at [segmentId]'s text at character offset
  /// [splitIndex] into two segments — the second holds everything from
  /// [splitIndex] onward and is inserted right after the first. [start]/
  /// [end] are proportioned by each half's share of the original text
  /// length (no word-level timing data exists to split on), clamped so
  /// neither half collapses to a zero-length range. Returns the new
  /// second segment's id (for the caller to move editing focus onto it),
  /// or [segmentId] unchanged if the split index doesn't actually split
  /// anything (e.g. at the very start/end, or on whitespace-only text).
  String splitTranscriptSegment(String segmentId, int splitIndex) {
    final index = transcript.indexWhere((s) => s.id == segmentId);
    if (index == -1) return segmentId;
    final segment = transcript[index];
    final text = segment.text;
    final clamped = splitIndex.clamp(0, text.length);
    if (clamped <= 0 || clamped >= text.length) return segmentId;

    final firstText = text.substring(0, clamped).trimRight();
    final secondText = text.substring(clamped).trimLeft();
    if (firstText.isEmpty || secondText.isEmpty) return segmentId;

    final totalMs = segment.duration.inMilliseconds;
    final rawOffsetMs = (totalMs * (clamped / text.length)).round();
    final offsetMs = totalMs > 1 ? rawOffsetMs.clamp(1, totalMs - 1) : rawOffsetMs;
    final splitTime = segment.start + Duration(milliseconds: offsetMs);
    final newId = const Uuid().v4();

    transcript.replaceRange(index, index + 1, [
      TranscriptSegment(
        id: segment.id,
        start: segment.start,
        end: splitTime,
        text: firstText,
        isSilence: segment.isSilence,
        isMarkedForCut: segment.isMarkedForCut,
      ),
      TranscriptSegment(
        id: newId,
        start: splitTime,
        end: segment.end,
        text: secondText,
        isSilence: segment.isSilence,
        isMarkedForCut: segment.isMarkedForCut,
      ),
    ]);
    _notifyAndSave();
    return newId;
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

  // toggleSilenceRangeAccepted/setAllSilenceRangesAccepted/
  // toggleClipIncludeInExport removed here (Phase 14 cleanup) — each was a
  // handler for a toggle UI that no longer exists (the old Silence
  // screen's per-range accept/reject, and Clips' old include-in-export
  // toggle, both retired in Phases 9/11). The underlying data
  // (`silenceRanges`, `AiClip.includeInExport`) stays — still real,
  // still persisted, just not currently editable from any screen.

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
  /// branding in the Settings screen. Also syncs [captionStyle]'s template
  /// from [BrandSettings.defaultCaptionTemplate] — Settings' "Default
  /// Caption Template" picker writes there, not to [captionStyle] directly
  /// (which [_renderClip] actually reads at export time), so without this
  /// the picker would silently do nothing to real exports.
  Future<void> reloadBrandSettings() async {
    brandSettings = await _brandSettingsStore.load();
    captionStyle = captionStyle.copyWith(template: brandSettings.defaultCaptionTemplate);
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
        // The backend only ever knows the upload's original filename —
        // this is the user-facing title (editable, defaults to the
        // filename minus extension) for the export history entry it
        // records (see backend/app/routers/exports.py, V2 Decision #3).
        'project_title': currentProject.title,
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
    final offset = Duration(milliseconds: captionStyle.timingOffsetMs);
    final buffer = StringBuffer();
    var index = 0;
    for (final segment in segments) {
      final end = segment.end - clipStart + offset;
      if (end <= Duration.zero) continue;
      final start = segment.start - clipStart + offset;
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
