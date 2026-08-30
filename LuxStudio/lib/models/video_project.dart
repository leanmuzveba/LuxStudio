/// Where a [VideoProject] currently sits in the pipeline.
enum ProjectStatus { importing, detectingSilence, transcribing, ready, exporting }

/// The sermon recording being worked on.
///
/// [backendProjectId] is the id of this project on the LuxStudio backend
/// (see backend/README.md) — the source video, working (silence-trimmed)
/// copy, and every export live there, keyed by this id. The original
/// upload is never modified; the backend keeps it separate from any
/// working copy it produces.
class VideoProject {
  final String id;
  final String fileName;
  final String backendProjectId;
  final Duration rawDuration;
  Duration processedDuration;
  final int width;
  final int height;
  final DateTime importedAt;
  ProjectStatus status;

  /// User-facing project name shown on the Home dashboard — defaults to
  /// [fileName] minus its extension, editable afterwards.
  String title;

  /// Bumped on every autosave; drives the Home dashboard's recency sort
  /// and "last edited" labels.
  DateTime updatedAt;

  /// Set once a clip from this project has completed export — drives the
  /// Home dashboard's "Exported" status pill.
  bool hasExported;

  VideoProject({
    required this.id,
    required this.fileName,
    required this.backendProjectId,
    required this.rawDuration,
    required this.processedDuration,
    required this.width,
    required this.height,
    required this.importedAt,
    this.status = ProjectStatus.importing,
    String? title,
    DateTime? updatedAt,
    this.hasExported = false,
  })  : title = title ?? _titleFromFileName(fileName),
        updatedAt = updatedAt ?? importedAt;

  static String _titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot == -1 ? fileName : fileName.substring(0, dot);
    return base.isEmpty ? fileName : base;
  }

  Duration get trimmedAmount => rawDuration - processedDuration;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'backendProjectId': backendProjectId,
        'rawDurationMs': rawDuration.inMilliseconds,
        'processedDurationMs': processedDuration.inMilliseconds,
        'width': width,
        'height': height,
        'importedAt': importedAt.toIso8601String(),
        'status': status.name,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'hasExported': hasExported,
      };

  factory VideoProject.fromJson(Map<String, dynamic> json) => VideoProject(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        backendProjectId: json['backendProjectId'] as String,
        rawDuration: Duration(milliseconds: json['rawDurationMs'] as int),
        processedDuration: Duration(milliseconds: json['processedDurationMs'] as int),
        width: json['width'] as int,
        height: json['height'] as int,
        importedAt: DateTime.parse(json['importedAt'] as String),
        status: ProjectStatus.values.byName(json['status'] as String),
        title: json['title'] as String?,
        updatedAt: json['updatedAt'] == null ? null : DateTime.parse(json['updatedAt'] as String),
        hasExported: json['hasExported'] as bool? ?? false,
      );
}
