import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/video_project.dart';
import 'ffmpeg_service.dart';

/// A picked file, reduced to what [MediaImportService] needs. Wraps
/// [PlatformFile] (an unconstructable `abstract base class` outside its
/// own package, so it can't be faked directly in tests) so the picker
/// step stays injectable.
class PickedMediaFile {
  final String name;

  /// A real on-disk path, when the platform picker returned one — SAF
  /// picks on Android commonly return a `content://` URI instead, in
  /// which case this is null and [readAsBytes] is the only way to get the
  /// data.
  final String? path;
  final Future<Uint8List> Function() readAsBytes;

  const PickedMediaFile({required this.name, this.path, required this.readAsBytes});
}

/// Lets the user pick a video file, copies it into the app's private
/// sandbox (the original on the user's device is only ever read, never
/// written to), and probes it for duration/resolution.
///
/// [pickFile] and [documentsDirProvider] default to real implementations
/// but are injectable so tests never touch the real
/// `file_picker`/`path_provider` platform channels (no implementation
/// under plain `flutter test`).
class MediaImportService {
  MediaImportService({
    FfmpegService? ffmpegService,
    Future<Directory> Function()? documentsDirProvider,
    Future<PickedMediaFile?> Function()? pickFile,
  })  : _ffmpegService = ffmpegService ?? FfmpegService(),
        _documentsDirProvider = documentsDirProvider ?? getApplicationDocumentsDirectory,
        _pickFile = pickFile ?? _defaultPickFile;

  final FfmpegService _ffmpegService;
  final Future<Directory> Function() _documentsDirProvider;
  final Future<PickedMediaFile?> Function() _pickFile;

  static Future<PickedMediaFile?> _defaultPickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov'],
    );
    if (file == null) return null;
    return PickedMediaFile(name: file.name, path: file.path, readAsBytes: file.readAsBytes);
  }

  /// Returns the imported [VideoProject], or `null` if the user cancelled
  /// the picker. Throws if the picked file couldn't be read/copied/probed.
  Future<VideoProject?> importVideo() async {
    final picked = await _pickFile();
    if (picked == null) return null;

    final docs = await _documentsDirProvider();
    final mediaDir = Directory('${docs.path}/media');
    if (!mediaDir.existsSync()) {
      mediaDir.createSync(recursive: true);
    }

    final id = const Uuid().v4();
    final ext = _extension(picked.name);
    final destPath = '${mediaDir.path}/$id${ext.isEmpty ? '' : '.$ext'}';

    // Prefer a direct file copy when the picker gave us a real path. SAF
    // picks on Android commonly come back as a content:// URI instead
    // (no usable path) — fall back to reading the bytes in that case.
    final sourcePath = picked.path;
    if (sourcePath != null && File(sourcePath).existsSync()) {
      File(sourcePath).copySync(destPath);
    } else {
      final bytes = await picked.readAsBytes();
      File(destPath).writeAsBytesSync(bytes);
    }

    final info = await _ffmpegService.probe(destPath);

    return VideoProject(
      id: id,
      fileName: picked.name,
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

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot + 1);
  }
}
