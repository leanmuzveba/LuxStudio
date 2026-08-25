import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/video_project.dart';
import 'ffmpeg_service.dart';

/// Lets the user pick a video file, copies it into the app's private
/// sandbox (the original on the user's device is only ever read, never
/// written to), and probes it for duration/resolution.
///
/// [pickFilePath] and [documentsDirProvider] default to real
/// implementations but are injectable so tests never touch the real
/// `file_picker`/`path_provider` platform channels (no implementation
/// under plain `flutter test`) — `PlatformFile` itself can't be faked
/// directly (it's an unconstructable `abstract base class` outside its
/// own package), so injection happens at the path-string level instead.
class MediaImportService {
  MediaImportService({
    FfmpegService? ffmpegService,
    Future<Directory> Function()? documentsDirProvider,
    Future<String?> Function()? pickFilePath,
  })  : _ffmpegService = ffmpegService ?? FfmpegService(),
        _documentsDirProvider = documentsDirProvider ?? getApplicationDocumentsDirectory,
        _pickFilePath = pickFilePath ?? _defaultPickFilePath;

  final FfmpegService _ffmpegService;
  final Future<Directory> Function() _documentsDirProvider;
  final Future<String?> Function() _pickFilePath;

  static Future<String?> _defaultPickFilePath() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov'],
    );
    return file?.path;
  }

  /// Returns the imported [VideoProject], or `null` if the user cancelled
  /// the picker. Throws if the picked file couldn't be read/copied/probed.
  Future<VideoProject?> importVideo() async {
    final pickedPath = await _pickFilePath();
    if (pickedPath == null) return null;

    final sourceFile = File(pickedPath);
    if (!sourceFile.existsSync()) {
      throw StateError("Picked file doesn't exist on disk: $pickedPath");
    }

    final docs = await _documentsDirProvider();
    final mediaDir = Directory('${docs.path}/media');
    if (!mediaDir.existsSync()) {
      mediaDir.createSync(recursive: true);
    }

    final id = const Uuid().v4();
    final fileName = _basename(pickedPath);
    final ext = _extension(fileName);
    final destPath = '${mediaDir.path}/$id${ext.isEmpty ? '' : '.$ext'}';
    sourceFile.copySync(destPath);

    final info = await _ffmpegService.probe(destPath);

    return VideoProject(
      id: id,
      fileName: fileName,
      sourcePath: destPath,
      workingPath: destPath,
      rawDuration: info.duration,
      processedDuration: info.duration,
      width: info.width,
      height: info.height,
      importedAt: DateTime.now(),
      status: ProjectStatus.ready,
    );
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot + 1);
  }
}
