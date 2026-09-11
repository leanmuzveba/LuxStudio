import 'dart:typed_data';

import '../models/video_project.dart';
import '../utils/video_format.dart';
import 'api_client.dart';
import 'chunked_upload.dart';
import 'media_import_picker.dart';

/// A picked file, reduced to what [MediaImportService] needs. Wraps
/// [PlatformFile] (an unconstructable `abstract base class` outside its
/// own package, so it can't be faked directly in tests) so the picker
/// step stays injectable.
///
/// [readRange] reads only the requested byte range rather than the whole
/// file — [MediaImportService.importVideo] uses it to upload in fixed-size
/// chunks instead of ever materializing a multi-GB video as one buffer.
class PickedMediaFile {
  final String name;

  /// A real on-disk path, when the platform picker returned one — unused
  /// now that upload always goes through [readRange] (the only option
  /// that works on every platform, including web).
  final String? path;
  final Future<int> Function() length;
  final Future<Uint8List> Function(int start, int end) readRange;

  const PickedMediaFile({
    required this.name,
    this.path,
    required this.length,
    required this.readRange,
  });
}

/// Lets the user pick a video file and uploads it to the LuxStudio backend
/// (see backend/README.md), which stores it, best-effort probes it for
/// duration/resolution, and hands back a project id.
///
/// [pickFile] defaults to a real implementation but is injectable so tests
/// never touch the real `file_picker` platform channel (no implementation
/// under plain `flutter test`).
class MediaImportService {
  MediaImportService({
    ApiClient? apiClient,
    Future<PickedMediaFile?> Function()? pickFile,
  })  : _apiClient = apiClient ?? ApiClient(),
        _pickFile = pickFile ?? _defaultPickFile;

  final ApiClient _apiClient;
  final Future<PickedMediaFile?> Function() _pickFile;

  static Future<PickedMediaFile?> _defaultPickFile() async {
    final file = await pickVideoFile(allowedExtensions: ['mp4', 'mov', 'mkv']);
    if (file == null) return null;
    return PickedMediaFile(
      name: file.name,
      path: file.path,
      length: file.length,
      readRange: (start, end) => file.xFile.openRead(start, end).single,
    );
  }

  /// Returns the imported [VideoProject], or `null` if the user cancelled
  /// the picker. Throws if the picked file couldn't be read/uploaded.
  ///
  /// [onProgress], when given, reports bytes-uploaded progress as each
  /// chunk completes (see `chunked_upload.dart` for why the upload itself
  /// is chunked, not just why this reports progress).
  Future<VideoProject?> importVideo({void Function(int sent, int total)? onProgress}) async {
    final picked = await _pickFile();
    if (picked == null) return null;
    if (!isSupportedVideoFilename(picked.name)) {
      throw Exception(unsupportedVideoFormatMessage(picked.name));
    }

    final length = await picked.length();
    final uploadId = await uploadInChunks(
      apiClient: _apiClient,
      length: length,
      readRange: picked.readRange,
      onProgress: onProgress,
    );
    final response = await _apiClient.postJson(
      '/projects/from-upload?upload_id=$uploadId&filename=${Uri.encodeQueryComponent(picked.name)}',
      const {},
    );

    final durationMs = (response['durationMs'] as num?)?.toInt();

    return VideoProject(
      id: response['id'] as String,
      fileName: picked.name,
      backendProjectId: response['id'] as String,
      rawDuration: Duration(milliseconds: durationMs ?? 0),
      processedDuration: Duration(milliseconds: durationMs ?? 0),
      width: (response['width'] as num?)?.toInt() ?? 0,
      height: (response['height'] as num?)?.toInt() ?? 0,
      importedAt: DateTime.now(),
      status: ProjectStatus.ready,
    );
  }
}
