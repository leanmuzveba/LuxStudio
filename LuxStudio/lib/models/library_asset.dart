/// A video stored in the Media Library (V2 Decision #2) — independent of
/// any one project, reusable to start more than one (see
/// AppState.useLibraryAssetAsProject / backend/app/routers/library.py).
class LibraryAsset {
  final String id;
  final String filename;
  final String? folderId;
  final int sizeBytes;
  final Duration duration;
  final int width;
  final int height;

  const LibraryAsset({
    required this.id,
    required this.filename,
    required this.folderId,
    required this.sizeBytes,
    required this.duration,
    required this.width,
    required this.height,
  });

  factory LibraryAsset.fromJson(Map<String, dynamic> json) => LibraryAsset(
        id: json['id'] as String,
        filename: json['filename'] as String,
        folderId: json['folder_id'] as String?,
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
      );

  LibraryAsset copyWithFolderId(String? folderId) => LibraryAsset(
        id: id,
        filename: filename,
        folderId: folderId,
        sizeBytes: sizeBytes,
        duration: duration,
        width: width,
        height: height,
      );

  String get sizeLabel {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (sizeBytes >= gb) return '${(sizeBytes / gb).toStringAsFixed(1)} GB';
    if (sizeBytes >= mb) return '${(sizeBytes / mb).toStringAsFixed(1)} MB';
    if (sizeBytes >= kb) return '${(sizeBytes / kb).toStringAsFixed(0)} KB';
    return '$sizeBytes B';
  }

  String get durationLabel {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return duration.inHours > 0
        ? '${duration.inHours}:${m.padLeft(2, '0')}:$s'
        : '$m:$s';
  }
}
