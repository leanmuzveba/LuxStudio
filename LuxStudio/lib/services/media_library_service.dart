import 'dart:typed_data';

import '../models/library_asset.dart';
import '../models/library_folder.dart';
import 'api_client.dart';

/// Talks to the backend's Media Library endpoints (`backend/app/routers
/// /library.py`, V2 Decision #2) — folders, video assets, and a storage
/// quota, all independent of any one project.
class MediaLibraryService {
  MediaLibraryService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<LibraryFolder>> listFolders() async => (await _apiClient.getJsonList('/library/folders'))
      .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<LibraryFolder> createFolder(String name) async =>
      LibraryFolder.fromJson(await _apiClient.postJson('/library/folders', {'name': name}));

  Future<void> deleteFolder(String id) => _apiClient.delete('/library/folders/$id');

  Future<List<LibraryAsset>> listAssets() async => (await _apiClient.getJsonList('/library/assets'))
      .map((e) => LibraryAsset.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<LibraryAsset> uploadAsset({
    required Uint8List bytes,
    required String filename,
    String? folderId,
  }) async {
    final response = await _apiClient.postMultipart(
      '/library/assets',
      fieldName: 'file',
      bytes: bytes,
      filename: filename,
      fields: folderId == null ? null : {'folder_id': folderId},
    );
    return LibraryAsset.fromJson(response);
  }

  Future<void> deleteAsset(String id) => _apiClient.delete('/library/assets/$id');

  /// Starts a new project from a library asset — returns the raw backend
  /// project JSON (same shape `POST /projects` returns), which
  /// [AppState.useLibraryAssetAsProject] turns into a [VideoProject].
  Future<Map<String, dynamic>> useAssetAsProject(String id) =>
      _apiClient.postJson('/library/assets/$id/use', const {});

  Future<({int usedBytes, int limitBytes})> getQuota() async {
    final json = await _apiClient.getJson('/library/quota');
    return (
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      limitBytes: (json['limit_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}
