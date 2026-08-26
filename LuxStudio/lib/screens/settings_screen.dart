import 'package:flutter/material.dart';

import '../services/secure_settings.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';
import '../widgets/lux_buttons.dart';

/// Settings — the user's own Gemini API key.
///
/// The API key is stored via [SecureSettings] (Android Keystore-backed
/// secure storage), entered at runtime — never hardcoded, never in source
/// control, never compiled into the APK. Branding (logo + org name) moved
/// to its own [BrandingScreen], reached via the bottom nav.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _secureSettings = SecureSettings();
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _loading = true;
  bool _saving = false;
  bool _hasSavedKey = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final key = await _secureSettings.getGeminiApiKey();
    if (!mounted) return;
    setState(() {
      _controller.text = key ?? '';
      _hasSavedKey = key != null && key.isNotEmpty;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      _showSnack('Enter a Gemini API key first.');
      return;
    }
    setState(() => _saving = true);
    await _secureSettings.setGeminiApiKey(key);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _hasSavedKey = true;
    });
    _showSnack('Gemini API key saved.');
  }

  Future<void> _clear() async {
    await _secureSettings.clearGeminiApiKey();
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _hasSavedKey = false;
    });
    _showSnack('Gemini API key removed.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.background,
      appBar: const LuxAppBar(title: 'Settings', showBack: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Gemini API key', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'LuxStudio uses your own free-tier Gemini API key for transcription, '
                  'AI clip suggestions, and social copy. Get one at '
                  "aistudio.google.com/apikey — it's stored only on this device and "
                  "only ever sent to Google's API.",
                  style: LuxText.manrope(size: 13, color: LuxColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  style: LuxText.manrope(size: 14, color: LuxColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: LuxColors.surface,
                    hintText: 'Paste your Gemini API key',
                    hintStyle: LuxText.manrope(size: 14, color: LuxColors.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LuxColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LuxColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LuxColors.gold),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: LuxColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LuxPrimaryButton(
                  label: _saving ? 'Saving…' : 'Save key',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
                if (_hasSavedKey) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _clear,
                      child: Text('Remove saved key', style: LuxText.manrope(size: 13, weight: FontWeight.w700, color: LuxColors.tan)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _hasSavedKey ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 16,
                      color: _hasSavedKey ? LuxColors.success : LuxColors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hasSavedKey
                            ? 'A key is saved on this device.'
                            : "No key saved yet — AI features won't work until you add one.",
                        style: LuxText.manrope(size: 12.5, color: LuxColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
