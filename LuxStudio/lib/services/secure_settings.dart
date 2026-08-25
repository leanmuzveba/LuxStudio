import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] for the one secret LuxStudio holds: the
/// user's own Gemini API key. It's entered at runtime via [SettingsScreen]
/// and never hardcoded, never in source control, never compiled into the
/// APK — Android Keystore-backed storage is the only place it lives.
class SecureSettings {
  SecureSettings({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _geminiApiKeyKey = 'gemini_api_key';

  Future<String?> getGeminiApiKey() => _storage.read(key: _geminiApiKeyKey);

  Future<void> setGeminiApiKey(String apiKey) =>
      _storage.write(key: _geminiApiKeyKey, value: apiKey.trim());

  Future<void> clearGeminiApiKey() => _storage.delete(key: _geminiApiKeyKey);
}
