import 'dart:typed_data';

import 'api_client.dart';

/// Bytes read and sent per chunk. Small enough that the browser tab never
/// has to hold more than this much of a video in memory at once — a 1-2
/// hour sermon video is easily several GB, and even a single full-size
/// `Uint8List` (from `file_picker`'s `readAsBytes()`) was enough to crash
/// the tab on its own, independent of how the upload request itself was
/// encoded.
const int uploadChunkBytes = 8 * 1024 * 1024;

/// Uploads [length] bytes, read on demand via [readRange], to the
/// backend's chunked-upload endpoint (see
/// `backend/app/routers/uploads.py`) and returns the resulting
/// `upload_id` — the caller then completes it against its own
/// finalizing endpoint (`POST /projects/from-upload`,
/// `POST /library/assets/from-upload`), which moves the assembled file
/// into its final location.
Future<String> uploadInChunks({
  required ApiClient apiClient,
  required int length,
  required Future<Uint8List> Function(int start, int end) readRange,
  void Function(int sent, int total)? onProgress,
}) async {
  final startResponse = await apiClient.postJson('/uploads', const {});
  final uploadId = startResponse['upload_id'] as String;

  var offset = 0;
  while (offset < length) {
    final end = offset + uploadChunkBytes < length ? offset + uploadChunkBytes : length;
    final chunk = await readRange(offset, end);
    await apiClient.putBytes('/uploads/$uploadId/chunk?offset=$offset', chunk);
    offset = end;
    onProgress?.call(offset, length);
  }

  return uploadId;
}
