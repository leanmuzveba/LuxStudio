import 'dart:typed_data';

/// Non-web fallback (used under `flutter test`, which runs on the Dart VM
/// where `dart:html` doesn't exist). [ApiClient.postMultipart] catches the
/// [UnsupportedError] this throws and falls back to the plain
/// `package:http` upload path, just without progress events.
Future<Map<String, dynamic>> multipartUploadWithProgress({
  required String url,
  required String fieldName,
  required Uint8List bytes,
  required String filename,
  Map<String, String>? fields,
  void Function(int sent, int total)? onProgress,
}) {
  throw UnsupportedError('Progress-tracked upload is only available on web.');
}
