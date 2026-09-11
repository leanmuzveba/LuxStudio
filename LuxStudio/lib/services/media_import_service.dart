import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/video_project.dart';
import '../utils/video_format.dart';
import 'api_client.dart';

/// A picked file, reduced to what [MediaImportService] needs. Wraps
/// [PlatformFile] (an unconstructable `abstract base class` outside its
/// own package, so it can't be faked directly in tests) so the picker
/// step stays injectable.
class PickedMediaFile {
  final String name;

  /// A real on-disk path, when the platform picker returned one — unused
  /// now that upload always goes through [readAsBytes] (the only option
  /// that works on every platform, including web).
  final String? path;
  final Future<Uint8List> Function() readAsBytes;

  const PickedMediaFile({required this.name, this.path, required this.readAsBytes});
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
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'mkv'],
    );
    if (file == null) return null;
    return PickedMediaFile(name: file.name, path: file.path, readAsBytes: file.readAsBytes);
  }

  /// Returns the imported [VideoProject], or `null` if the user cancelled
  /// the picker. Throws if the picked file couldn't be read/uploaded.
  ///
  /// [onProgress], when given, reports real bytes-sent-over-the-wire
  /// progress for the upload — a 1-2 hour sermon video is easily multiple
  /// GB, so this also matters for *how* the upload is sent, not just
  /// visibility: see [ApiClient.postMultipart]'s doc for why the
  /// progress-tracked path (web only) is the one that avoids doubling
  /// memory for a file this size, where the plain `package:http` path can
  /// crash the tab.
  Future<VideoProject?> importVideo({void Function(int sent, int total)? onProgress}) async {
    final picked = await _pickFile();
    if (picked == null) return null;
    if (!isSupportedVideoFilename(picked.name)) {
      throw Exception(unsupportedVideoFormatMessage(picked.name));
    }

    final bytes = await picked.readAsBytes();
    final response = await _apiClient.postMultipart(
      '/projects',
      fieldName: 'file',
      bytes: bytes,
      filename: picked.name,
      onProgress: onProgress,
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
