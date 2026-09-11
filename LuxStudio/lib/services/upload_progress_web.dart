// This file is only ever compiled in on web (see upload_progress.dart's
// conditional export) — LuxStudio is a Flutter Web app (see CLAUDE.md), so
// there's no other platform for `dart:html` to be the wrong choice for, and
// no non-deprecated replacement exposes `xhr.upload.onProgress` yet.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Real upload progress on Flutter Web. `package:http` has no upload-progress
/// hook (it hands the browser a fully-materialized body), so this builds the
/// multipart request by hand on a raw `HttpRequest` and listens to
/// `xhr.upload.onProgress`, which fires from actual bytes-sent-over-the-wire
/// events — the only way to get a real percentage for a large video upload.
Future<Map<String, dynamic>> multipartUploadWithProgress({
  required String url,
  required String fieldName,
  required Uint8List bytes,
  required String filename,
  Map<String, String>? fields,
  void Function(int sent, int total)? onProgress,
}) {
  final completer = Completer<Map<String, dynamic>>();
  final boundary = '----luxstudio-${DateTime.now().microsecondsSinceEpoch}';
  final body = _buildMultipartBody(boundary, fieldName, bytes, filename, fields);

  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  xhr.setRequestHeader('Content-Type', 'multipart/form-data; boundary=$boundary');

  xhr.upload.onProgress.listen((event) {
    if (onProgress != null && event.lengthComputable) {
      onProgress(event.loaded ?? 0, event.total ?? 0);
    }
  });

  xhr.onLoad.listen((_) {
    final status = xhr.status ?? 0;
    if (status >= 200 && status < 300) {
      final decoded = jsonDecode(xhr.responseText ?? '{}');
      if (decoded is Map<String, dynamic>) {
        completer.complete(decoded);
      } else {
        completer.completeError(FormatException('Expected a JSON object, got: $decoded'));
      }
    } else {
      completer.completeError(Exception('Upload failed ($status): ${xhr.responseText}'));
    }
  });

  xhr.onError.listen((_) => completer.completeError(Exception('Upload failed: network error')));

  xhr.send(body);
  return completer.future;
}

Uint8List _buildMultipartBody(
  String boundary,
  String fieldName,
  Uint8List bytes,
  String filename,
  Map<String, String>? fields,
) {
  final buffer = BytesBuilder();
  void writeString(String s) => buffer.add(utf8.encode(s));

  fields?.forEach((key, value) {
    writeString('--$boundary\r\n');
    writeString('Content-Disposition: form-data; name="$key"\r\n\r\n');
    writeString('$value\r\n');
  });

  writeString('--$boundary\r\n');
  writeString('Content-Disposition: form-data; name="$fieldName"; filename="$filename"\r\n');
  writeString('Content-Type: application/octet-stream\r\n\r\n');
  buffer.add(bytes);
  writeString('\r\n--$boundary--\r\n');

  return buffer.toBytes();
}
