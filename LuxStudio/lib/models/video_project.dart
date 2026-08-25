import 'package:uuid/uuid.dart';

/// The sermon recording being worked on. Kept intentionally small — this
/// is a UI-flow reconstruction, not a media pipeline, so it tracks just
/// enough to drive the editor screens realistically.
class VideoProject {
  final String id;
  final String fileName;
  final Duration rawDuration;
  final Duration processedDuration;
  final DateTime importedAt;

  const VideoProject({
    required this.id,
    required this.fileName,
    required this.rawDuration,
    required this.processedDuration,
    required this.importedAt,
  });

  Duration get trimmedAmount => rawDuration - processedDuration;

  factory VideoProject.mockImport() {
    return VideoProject(
      id: const Uuid().v4(),
      fileName: 'Sunday_Service_Aug23.mov',
      rawDuration: const Duration(minutes: 38, seconds: 12),
      processedDuration: const Duration(minutes: 31, seconds: 40),
      importedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'rawDurationMs': rawDuration.inMilliseconds,
        'processedDurationMs': processedDuration.inMilliseconds,
        'importedAt': importedAt.toIso8601String(),
      };

  factory VideoProject.fromJson(Map<String, dynamic> json) => VideoProject(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        rawDuration: Duration(milliseconds: json['rawDurationMs'] as int),
        processedDuration: Duration(milliseconds: json['processedDurationMs'] as int),
        importedAt: DateTime.parse(json['importedAt'] as String),
      );
}
