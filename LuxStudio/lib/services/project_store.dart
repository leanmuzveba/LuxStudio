import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/ai_clip.dart';
import '../models/export_destination.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';

/// A full snapshot of one editing session — everything [AppState] needs to
/// pick back up where the user left off after an unexpected close.
class ProjectSnapshot {
  final VideoProject project;
  final List<TranscriptSegment> transcript;
  final List<AiClip> suggestedClips;
  final String? selectedClipId;
  final List<BrandingPreset> brandingPresets;
  final int selectedCaptionIndex;
  final List<String> generatedCaptions;
  final Set<ExportPlatform> selectedDestinations;
  final int processingStageIndex;
  final bool processingComplete;

  const ProjectSnapshot({
    required this.project,
    required this.transcript,
    required this.suggestedClips,
    required this.selectedClipId,
    required this.brandingPresets,
    required this.selectedCaptionIndex,
    required this.generatedCaptions,
    required this.selectedDestinations,
    required this.processingStageIndex,
    required this.processingComplete,
  });

  Map<String, dynamic> toJson() => {
        'project': project.toJson(),
        'transcript': transcript.map((s) => s.toJson()).toList(),
        'suggestedClips': suggestedClips.map((c) => c.toJson()).toList(),
        'selectedClipId': selectedClipId,
        'brandingPresets': brandingPresets.map((b) => b.toJson()).toList(),
        'selectedCaptionIndex': selectedCaptionIndex,
        'generatedCaptions': generatedCaptions,
        'selectedDestinations': selectedDestinations.map((d) => d.name).toList(),
        'processingStageIndex': processingStageIndex,
        'processingComplete': processingComplete,
      };

  factory ProjectSnapshot.fromJson(Map<String, dynamic> json) => ProjectSnapshot(
        project: VideoProject.fromJson(json['project'] as Map<String, dynamic>),
        transcript: (json['transcript'] as List)
            .map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
        suggestedClips: (json['suggestedClips'] as List)
            .map((e) => AiClip.fromJson(e as Map<String, dynamic>))
            .toList(),
        selectedClipId: json['selectedClipId'] as String?,
        brandingPresets: (json['brandingPresets'] as List)
            .map((e) => BrandingPreset.fromJson(e as Map<String, dynamic>))
            .toList(),
        selectedCaptionIndex: json['selectedCaptionIndex'] as int,
        generatedCaptions: (json['generatedCaptions'] as List).cast<String>(),
        selectedDestinations: (json['selectedDestinations'] as List)
            .map((name) => ExportPlatform.values.byName(name as String))
            .toSet(),
        processingStageIndex: json['processingStageIndex'] as int,
        processingComplete: json['processingComplete'] as bool,
      );
}

/// Persists one [ProjectSnapshot] per project as JSON under the app's
/// documents directory, plus a small pointer file recording which project
/// was last active — so LuxStudio can recover it on the next launch.
///
/// Every read/write is best-effort: a missing plugin (e.g. under
/// `flutter test`, which has no platform channel implementation), a
/// corrupt file, or a write failure should never crash the editor — it
/// just means autosave/recovery silently does nothing for that call.
class ProjectStore {
  /// [documentsDirProvider] defaults to the real platform documents
  /// directory (via `path_provider`, which needs a platform channel with
  /// no implementation under plain `flutter test`). Tests inject a fake
  /// (e.g. a temp directory) instead of mocking that channel.
  ProjectStore({Future<Directory> Function()? documentsDirProvider})
      : _documentsDirProvider = documentsDirProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirProvider;

  // Deliberately synchronous dart:io calls (Directory/File *Sync methods)
  // rather than the async variants: these are small local JSON files (KBs,
  // not media), so the sync cost is negligible, and it sidesteps a
  // real-world quirk where the async overlapped-I/O path can take seconds
  // to complete under some sandboxed/monitored environments (observed
  // while testing) while the equivalent sync call returns instantly.

  Future<Directory> _projectsDir() async {
    final docs = await _documentsDirProvider();
    final dir = Directory('${docs.path}/projects');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<File> _lastOpenPointerFile() async {
    final dir = await _projectsDir();
    return File('${dir.path}/last_open.txt');
  }

  Future<void> save(ProjectSnapshot snapshot) async {
    try {
      final dir = await _projectsDir();
      final file = File('${dir.path}/${snapshot.project.id}.json');
      file.writeAsStringSync(jsonEncode(snapshot.toJson()));
      final pointer = await _lastOpenPointerFile();
      pointer.writeAsStringSync(snapshot.project.id);
    } catch (_) {
      // Best-effort autosave — see class doc.
    }
  }

  Future<ProjectSnapshot?> loadLast() async {
    try {
      final pointer = await _lastOpenPointerFile();
      if (!pointer.existsSync()) return null;
      final id = pointer.readAsStringSync().trim();
      if (id.isEmpty) return null;
      final dir = await _projectsDir();
      final file = File('${dir.path}/$id.json');
      if (!file.existsSync()) return null;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return ProjectSnapshot.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
