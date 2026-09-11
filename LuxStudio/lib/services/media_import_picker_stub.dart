import 'package:file_picker/file_picker.dart';

/// Non-web fallback — `withData` (web-only) doesn't apply here, and this
/// path is only reachable in production on non-web platforms anyway (tests
/// inject their own `pickFile` and never call this).
Future<PlatformFile?> pickVideoFile({required List<String> allowedExtensions}) {
  return FilePicker.pickFile(type: FileType.custom, allowedExtensions: allowedExtensions);
}
