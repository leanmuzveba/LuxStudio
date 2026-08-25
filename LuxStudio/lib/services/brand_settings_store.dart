import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/brand_settings.dart';

/// Persists [BrandSettings] as a small JSON file under the app's
/// documents directory — global app settings, not tied to one project,
/// so they're separate from [ProjectStore]'s per-project snapshots.
///
/// Uses synchronous dart:io calls, same reasoning as [ProjectStore]: small
/// files, and it sidesteps a real-world quirk where the async I/O path
/// was observed taking multiple real seconds in a sandboxed environment
/// while the equivalent sync call returned instantly.
class BrandSettingsStore {
  BrandSettingsStore({Future<Directory> Function()? documentsDirProvider})
      : _documentsDirProvider = documentsDirProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirProvider;

  Future<File> _settingsFile() async {
    final docs = await _documentsDirProvider();
    return File('${docs.path}/brand_settings.json');
  }

  Future<BrandSettings> load() async {
    try {
      final file = await _settingsFile();
      if (!file.existsSync()) return BrandSettings.empty;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return BrandSettings.fromJson(json);
    } catch (_) {
      return BrandSettings.empty;
    }
  }

  Future<void> save(BrandSettings settings) async {
    try {
      final file = await _settingsFile();
      file.writeAsStringSync(jsonEncode(settings.toJson()));
    } catch (_) {
      // Best-effort — a failed write shouldn't crash the settings screen.
    }
  }

  /// Copies the picked image into the app sandbox (so it survives even if
  /// the OS clears the picker's temp/cache file) and saves it as the
  /// current logo.
  Future<BrandSettings> updateLogo(BrandSettings current, String pickedImagePath) async {
    try {
      final docs = await _documentsDirProvider();
      final brandDir = Directory('${docs.path}/brand');
      if (!brandDir.existsSync()) brandDir.createSync(recursive: true);

      final dotIndex = pickedImagePath.lastIndexOf('.');
      final ext = dotIndex == -1 ? '.png' : pickedImagePath.substring(dotIndex);
      final destPath = '${brandDir.path}/logo$ext';
      File(pickedImagePath).copySync(destPath);

      final updated = BrandSettings(logoPath: destPath, organizationName: current.organizationName);
      await save(updated);
      return updated;
    } catch (_) {
      return current;
    }
  }
}
