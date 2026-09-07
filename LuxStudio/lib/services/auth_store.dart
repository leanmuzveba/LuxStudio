import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether this device already passed the shared church-passcode
/// gate (backend/app/routers/auth.py, V2 Decision #1: one passcode for
/// everyone, no per-user accounts/sessions). "Unlocked" here just means
/// "this browser entered the correct passcode once" — there is no token to
/// expire or refresh, matching [BrandSettingsStore]'s local-storage-only
/// shape rather than a real auth session.
class AuthStore {
  static const _key = 'auth_unlocked';

  AuthStore({Future<SharedPreferences> Function()? preferencesProvider})
      : _preferencesProvider = preferencesProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesProvider;

  Future<bool> isUnlocked() async {
    try {
      final prefs = await _preferencesProvider();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setUnlocked(bool value) async {
    try {
      final prefs = await _preferencesProvider();
      await prefs.setBool(_key, value);
    } catch (_) {
      // Best-effort — a failed write shouldn't crash the login/settings flow.
    }
  }
}
