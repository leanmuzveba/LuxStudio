/// Where a [VideoProject] currently sits in the on-device pipeline.
enum ProjectStatus { importing, detectingSilence, transcribing, ready, exporting }

/// The sermon recording being worked on.
///
/// [sourcePath] is a copy of the user's original file inside the app's
/// private sandbox — made once at import time and never rewritten, so the
/// original file on the user's device is only ever read, never touched.
/// [workingPath] is the file actually used for preview/processing; it
/// starts out equal to [sourcePath] and is replaced with a new file once
/// silence removal (a later phase) produces a trimmed version.
class VideoProject {
  final String id;
  final String fileName;
  final String sourcePath;
  String workingPath;
  final Duration rawDuration;
  Duration processedDuration;
  final int width;
  final int height;
  final DateTime importedAt;
  ProjectStatus status;

  VideoProject({
    required this.id,
    required this.fileName,
    required this.sourcePath,
    required this.workingPath,
    required this.rawDuration,
    required this.processedDuration,
    required this.width,
    required this.height,
    required this.importedAt,
    this.status = ProjectStatus.importing,
  });

  Duration get trimmedAmount => rawDuration - processedDuration;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'sourcePath': sourcePath,
        'workingPath': workingPath,
        'rawDurationMs': rawDuration.inMilliseconds,
        'processedDurationMs': processedDuration.inMilliseconds,
        'width': width,
        'height': height,
        'importedAt': importedAt.toIso8601String(),
        'status': status.name,
      };

  factory VideoProject.fromJson(Map<String, dynamic> json) => VideoProject(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        sourcePath: json['sourcePath'] as String,
        workingPath: json['workingPath'] as String,
        rawDuration: Duration(milliseconds: json['rawDurationMs'] as int),
        processedDuration: Duration(milliseconds: json['processedDurationMs'] as int),
        width: json['width'] as int,
        height: json['height'] as int,
        importedAt: DateTime.parse(json['importedAt'] as String),
        status: ProjectStatus.values.byName(json['status'] as String),
      );
}
