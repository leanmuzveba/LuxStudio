/// The sermon recording being worked on. Kept intentionally small — this
/// is a UI-flow reconstruction, not a media pipeline, so it tracks just
/// enough to drive the editor screens realistically.
class VideoProject {
  final String fileName;
  final Duration rawDuration;
  final Duration processedDuration;
  final DateTime importedAt;

  const VideoProject({
    required this.fileName,
    required this.rawDuration,
    required this.processedDuration,
    required this.importedAt,
  });

  Duration get trimmedAmount => rawDuration - processedDuration;

  factory VideoProject.mockImport() {
    return VideoProject(
      fileName: 'Sunday_Service_Aug23.mov',
      rawDuration: const Duration(minutes: 38, seconds: 12),
      processedDuration: const Duration(minutes: 31, seconds: 40),
      importedAt: DateTime.now(),
    );
  }
}
