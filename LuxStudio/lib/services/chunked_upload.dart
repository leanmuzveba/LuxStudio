import 'dart:typed_data';

import 'api_client.dart';

/// Bytes read and sent per chunk. Still small enough that the browser tab
/// never has to hold more than a couple of these in memory at once (see
/// [uploadInChunks]'s read/send overlap below) — a 1-2 hour sermon video is
/// easily several GB, and even a single full-size `Uint8List` (from
/// `file_picker`'s `readAsBytes()`) was enough to crash the tab on its own,
/// independent of how the upload request itself was encoded. 32MB keeps
/// that safety margin (two in flight is still only ~64MB) while cutting
/// the number of request round-trips roughly 4x versus the original 8MB.
const int uploadChunkBytes = 32 * 1024 * 1024;

int _chunkEnd(int start, int length) =>
    start + uploadChunkBytes < length ? start + uploadChunkBytes : length;

/// Uploads [length] bytes, read on demand via [readRange], to the
/// backend's chunked-upload endpoint (see
/// `backend/app/routers/uploads.py`) and returns the resulting
/// `upload_id` — the caller then completes it against its own
/// finalizing endpoint (`POST /projects/from-upload`,
/// `POST /library/assets/from-upload`), which moves the assembled file
/// into its final location.
///
/// Reads and sends overlap: while a chunk's `PUT` is in flight, the next
/// chunk is already being read off disk, instead of the two running
/// strictly back-to-back. The backend still requires chunks in order
/// (see `uploads.py`'s offset check), so this doesn't parallelize the
/// uploads themselves — it just hides read latency behind the network
/// round-trip.
Future<String> uploadInChunks({
  required ApiClient apiClient,
  required int length,
  required Future<Uint8List> Function(int start, int end) readRange,
  void Function(int sent, int total)? onProgress,
}) async {
  final startResponse = await apiClient.postJson('/uploads', const {});
  final uploadId = startResponse['upload_id'] as String;

  var offset = 0;
  Future<Uint8List>? nextRead = offset < length ? readRange(offset, _chunkEnd(offset, length)) : null;

  while (nextRead != null) {
    final chunkStart = offset;
    final chunk = await nextRead;
    final chunkEnd = _chunkEnd(chunkStart, length);

    nextRead = chunkEnd < length ? readRange(chunkEnd, _chunkEnd(chunkEnd, length)) : null;

    await apiClient.putBytes('/uploads/$uploadId/chunk?offset=$chunkStart', chunk);
    offset = chunkEnd;
    onProgress?.call(offset, length);
  }

  return uploadId;
}
