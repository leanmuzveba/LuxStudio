// This file is only ever compiled in on web (see upload_progress.dart's
// conditional export) — LuxStudio is a Flutter Web app (see CLAUDE.md), so
// there's no other platform for `dart:html` to be the wrong choice for, and
// no non-deprecated replacement exposes `xhr.upload.onProgress` yet.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Real upload progress on Flutter Web, via a raw `HttpRequest` + `FormData`.
///
/// `package:http`'s `BrowserClient` can't do two things a 1-2 hour sermon
/// video (multi-GB) needs:
///  - report upload progress — it's `fetch()`-based, which has no
///    upload-progress hook at all;
///  - avoid doubling memory — `BrowserClient.send()` always calls
///    `request.finalize().toBytes()`, fully re-materializing the encoded
///    multipart body into ONE new contiguous buffer *on top of* the
///    Uint8List already held from `readAsBytes()`. For a multi-GB video
///    that second full copy is enough to crash the tab.
///
/// `FormData` + `Blob` avoids that: the browser encodes and streams the
/// request from the Blob itself, so Dart never holds a second full copy of
/// the video (an earlier version of this file built the multipart body by
/// hand into a `BytesBuilder`, which had the exact same doubling problem —
/// see the commit that replaced it with this).
Future<Map<String, dynamic>> multipartUploadWithProgress({
  required String url,
  required String fieldName,
  required Uint8List bytes,
  required String filename,
  Map<String, String>? fields,
  void Function(int sent, int total)? onProgress,
}) {
  final completer = Completer<Map<String, dynamic>>();

  final formData = html.FormData();
  fields?.forEach(formData.append);
  formData.appendBlob(fieldName, html.Blob([bytes]), filename);

  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  // No manual Content-Type: the browser sets the correct
  // `multipart/form-data; boundary=...` header itself for a FormData body.

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

  xhr.send(formData);
  return completer.future;
}
