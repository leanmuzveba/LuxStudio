import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/brand_settings.dart';
import 'api_client.dart';

/// Persists [BrandSettings] as a small JSON string in browser storage
/// (`shared_preferences`, backed by localStorage on web) — global app
/// settings, not tied to one project, so they're separate from
/// [ProjectStore]'s per-project snapshots. The logo image itself lives on
/// the backend (see backend/app/routers/brand.py); only its URL is stored
/// here.
class BrandSettingsStore {
  static const _key = 'brand_settings';

  BrandSettingsStore({
    Future<SharedPreferences> Function()? preferencesProvider,
    ApiClient? apiClient,
  })  : _preferencesProvider = preferencesProvider ?? SharedPreferences.getInstance,
        _apiClient = apiClient ?? ApiClient();

  final Future<SharedPreferences> Function() _preferencesProvider;
  final ApiClient _apiClient;

  Future<BrandSettings> load() async {
    try {
      final prefs = await _preferencesProvider();
      final raw = prefs.getString(_key);
      if (raw == null) return BrandSettings.seeded;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return BrandSettings.fromJson(json);
    } catch (_) {
      return BrandSettings.seeded;
    }
  }

  Future<void> save(BrandSettings settings) async {
    try {
      final prefs = await _preferencesProvider();
      await prefs.setString(_key, jsonEncode(settings.toJson()));
    } catch (_) {
      // Best-effort — a failed write shouldn't crash the settings screen.
    }
  }

  /// Uploads [imageBytes] as the new logo and saves the resulting URL as
  /// part of [current]. Returns [current] unchanged if the upload fails.
  Future<BrandSettings> updateLogo(
    BrandSettings current,
    Uint8List imageBytes,
    String filename,
  ) async {
    try {
      final response = await _apiClient.postMultipart(
        '/brand/logo',
        fieldName: 'file',
        bytes: imageBytes,
        filename: filename,
      );
      final updated = BrandSettings(
        logoUrl: response['logoUrl'] as String?,
        organizationName: current.organizationName,
        color: current.color,
        watermarkCorner: current.watermarkCorner,
      );
      await save(updated);
      return updated;
    } catch (_) {
      return current;
    }
  }
}
