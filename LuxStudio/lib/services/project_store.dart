import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_clip.dart';
import '../models/caption_style.dart';
import '../models/export_destination.dart' show BrandingPreset;
import '../models/export_job.dart';
import '../models/silence_range.dart';
import '../models/social_copy.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';

/// A full snapshot of one editing session — everything [AppState] needs to
/// pick back up where the user left off after an unexpected close.
class ProjectSnapshot {
  final VideoProject project;
  final List<TranscriptSegment> transcript;
  final List<AiClip> suggestedClips;
  final List<SilenceRange> silenceRanges;
  final String? selectedClipId;
  final List<BrandingPreset> brandingPresets;
  final CaptionStyle captionStyle;
  final SocialCopy? socialCopy;
  final Map<String, ExportJob> exportJobs;

  const ProjectSnapshot({
    required this.project,
    required this.transcript,
    required this.suggestedClips,
    required this.silenceRanges,
    required this.selectedClipId,
    required this.brandingPresets,
    this.captionStyle = CaptionStyle.defaultStyle,
    this.socialCopy,
    this.exportJobs = const {},
  });

  Map<String, dynamic> toJson() => {
        'project': project.toJson(),
        'transcript': transcript.map((s) => s.toJson()).toList(),
        'suggestedClips': suggestedClips.map((c) => c.toJson()).toList(),
        'silenceRanges': silenceRanges.map((r) => r.toJson()).toList(),
        'selectedClipId': selectedClipId,
        'brandingPresets': brandingPresets.map((b) => b.toJson()).toList(),
        'captionStyle': captionStyle.toJson(),
        'socialCopy': socialCopy?.toJson(),
        'exportJobs': exportJobs.map((id, job) => MapEntry(id, job.toJson())),
      };

  factory ProjectSnapshot.fromJson(Map<String, dynamic> json) => ProjectSnapshot(
        project: VideoProject.fromJson(json['project'] as Map<String, dynamic>),
        transcript: (json['transcript'] as List)
            .map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
        suggestedClips: (json['suggestedClips'] as List)
            .map((e) => AiClip.fromJson(e as Map<String, dynamic>))
            .toList(),
        silenceRanges: (json['silenceRanges'] as List? ?? [])
            .map((e) => SilenceRange.fromJson(e as Map<String, dynamic>))
            .toList(),
        selectedClipId: json['selectedClipId'] as String?,
        brandingPresets: (json['brandingPresets'] as List)
            .map((e) => BrandingPreset.fromJson(e as Map<String, dynamic>))
            .toList(),
        captionStyle: json['captionStyle'] == null
            ? CaptionStyle.defaultStyle
            : CaptionStyle.fromJson(json['captionStyle'] as Map<String, dynamic>),
        socialCopy: json['socialCopy'] == null
            ? null
            : SocialCopy.fromJson(json['socialCopy'] as Map<String, dynamic>),
        exportJobs: (json['exportJobs'] as Map<String, dynamic>? ?? {}).map(
          (id, job) => MapEntry(id, ExportJob.fromJson(job as Map<String, dynamic>)),
        ),
      );
}

/// Persists one [ProjectSnapshot] per project as a JSON string in browser
/// storage (`shared_preferences`, backed by localStorage on web), plus a
/// small pointer key recording which project was last active — so
/// LuxStudio can recover it on the next launch.
///
/// Every read/write is best-effort: a missing plugin (e.g. under
/// `flutter test`, which has no platform channel implementation unless
/// mocked), a corrupt value, or a write failure should never crash the
/// editor — it just means autosave/recovery silently does nothing for
/// that call.
class ProjectStore {
  static const _idsKey = 'project_ids';
  static const _lastOpenKey = 'last_open_project_id';
  static String _snapshotKey(String id) => 'project:$id';

  /// [preferencesProvider] defaults to the real [SharedPreferences]
  /// instance. Tests inject a fake by calling
  /// `SharedPreferences.setMockInitialValues({})` before construction (the
  /// standard pattern for this package) rather than overriding this.
  ProjectStore({Future<SharedPreferences> Function()? preferencesProvider})
      : _preferencesProvider = preferencesProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesProvider;

  Future<void> save(ProjectSnapshot snapshot) async {
    try {
      final prefs = await _preferencesProvider();
      final id = snapshot.project.id;
      await prefs.setString(_snapshotKey(id), jsonEncode(snapshot.toJson()));
      final ids = prefs.getStringList(_idsKey) ?? [];
      if (!ids.contains(id)) {
        await prefs.setStringList(_idsKey, [...ids, id]);
      }
      await prefs.setString(_lastOpenKey, id);
    } catch (_) {
      // Best-effort autosave — see class doc.
    }
  }

  Future<ProjectSnapshot?> loadLast() async {
    try {
      final prefs = await _preferencesProvider();
      final id = prefs.getString(_lastOpenKey);
      if (id == null || id.isEmpty) return null;
      return _load(prefs, id);
    } catch (_) {
      return null;
    }
  }

  /// Every saved project, most recently updated first — powers the Home
  /// dashboard's recent-projects list. A snapshot that fails to parse
  /// (corrupt, or from a future incompatible version) is skipped rather
  /// than failing the whole listing.
  Future<List<ProjectSnapshot>> listAll() async {
    try {
      final prefs = await _preferencesProvider();
      final ids = prefs.getStringList(_idsKey) ?? [];
      final snapshots = <ProjectSnapshot>[];
      for (final id in ids) {
        final snapshot = _load(prefs, id);
        if (snapshot != null) snapshots.add(snapshot);
      }
      snapshots.sort((a, b) => b.project.updatedAt.compareTo(a.project.updatedAt));
      return snapshots;
    } catch (_) {
      return [];
    }
  }

  ProjectSnapshot? _load(SharedPreferences prefs, String id) {
    final raw = prefs.getString(_snapshotKey(id));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ProjectSnapshot.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
