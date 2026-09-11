import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart' show FilePickerWebOptions;

/// `withData: false` is the whole point of this file. `FilePickerWebOptions`
/// (file_picker_web's own options type — not re-exported by `package:
/// file_picker` itself, hence importing it directly here) defaults `withData`
/// to `true`, which makes file_picker eagerly read the ENTIRE picked file
/// into memory via `FileReader.readAsArrayBuffer()` *at pick time*, before
/// any of our own code even runs — regardless of how `MediaImportService`
/// or the Media Library screen read it afterward. For a 1-2 hour sermon
/// video (easily several GB) that alone is enough to crash the tab. With
/// `withData: false`, file_picker instead hands back a lazy reference
/// (`PlatformFile.xFile`, backed by the browser's own Blob) that our chunked
/// upload (`chunked_upload.dart`) reads on demand in small pieces.
Future<PlatformFile?> pickVideoFile({required List<String> allowedExtensions}) {
  return FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    webOptions: const FilePickerWebOptions(withData: false),
  );
}
