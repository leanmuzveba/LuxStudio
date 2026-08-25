import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/brand_settings.dart';
import '../services/brand_settings_store.dart';
import '../services/secure_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';

/// Settings — the user's own Gemini API key, and reusable branding
/// (logo + organisation name) applied across exports.
///
/// The API key is stored via [SecureSettings] (Android Keystore-backed
/// secure storage), entered at runtime — never hardcoded, never in source
/// control, never compiled into the APK. Branding is stored via
/// [BrandSettingsStore] (a plain JSON file — a logo path and org name
/// aren't secrets).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _secureSettings = SecureSettings();
  final _brandSettingsStore = BrandSettingsStore();
  final _controller = TextEditingController();
  final _orgNameController = TextEditingController();
  bool _obscure = true;
  bool _loading = true;
  bool _saving = false;
  bool _hasSavedKey = false;
  BrandSettings _brandSettings = BrandSettings.empty;
  bool _pickingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _controller.dispose();
    _orgNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final key = await _secureSettings.getGeminiApiKey();
    final brand = await _brandSettingsStore.load();
    if (!mounted) return;
    setState(() {
      _controller.text = key ?? '';
      _hasSavedKey = key != null && key.isNotEmpty;
      _brandSettings = brand;
      _orgNameController.text = brand.organizationName;
      _loading = false;
    });
  }

  Future<void> _pickLogo() async {
    setState(() => _pickingLogo = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final updated = await _brandSettingsStore.updateLogo(_brandSettings, picked.path);
      if (!mounted) return;
      setState(() => _brandSettings = updated);
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    final updated = BrandSettings(organizationName: _brandSettings.organizationName);
    await _brandSettingsStore.save(updated);
    if (!mounted) return;
    setState(() => _brandSettings = updated);
  }

  void _onOrgNameChanged(String value) {
    final updated = BrandSettings(logoPath: _brandSettings.logoPath, organizationName: value);
    _brandSettings = updated;
    unawaited(_brandSettingsStore.save(updated));
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
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Gaps.md),
              children: [
                Text('Gemini API key', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Gaps.xs),
                Text(
                  'LuxStudio uses your own free-tier Gemini API key for transcription, '
                  'AI clip suggestions, and social copy. Get one at '
                  "aistudio.google.com/apikey — it's stored only on this device and "
                  "only ever sent to Google's API.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Gaps.md),
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    hintText: 'Paste your Gemini API key',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: Gaps.md),
                GradientButton(
                  label: _saving ? 'Saving…' : 'Save key',
                  icon: Icons.check_rounded,
                  onPressed: _saving ? null : _save,
                ),
                if (_hasSavedKey) ...[
                  const SizedBox(height: Gaps.sm),
                  Center(
                    child: TextButton(
                      onPressed: _clear,
                      child: const Text('Remove saved key'),
                    ),
                  ),
                ],
                const SizedBox(height: Gaps.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _hasSavedKey ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 16,
                      color: _hasSavedKey ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: Gaps.sm),
                    Expanded(
                      child: Text(
                        _hasSavedKey
                            ? 'A key is saved on this device.'
                            : "No key saved yet — AI features won't work until you add one.",
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.xl),
                const Divider(color: AppColors.border),
                const SizedBox(height: Gaps.xl),
                Text('Branding', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Gaps.xs),
                const Text(
                  'A logo and organisation name applied to exports when '
                  'branding is enabled.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: Gaps.md),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _brandSettings.logoPath == null
                          ? const Icon(Icons.image_outlined, color: AppColors.textMuted)
                          : Image.file(File(_brandSettings.logoPath!), fit: BoxFit.cover),
                    ),
                    const SizedBox(width: Gaps.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _pickingLogo ? null : _pickLogo,
                            child: Text(
                              _pickingLogo
                                  ? 'Opening picker…'
                                  : _brandSettings.logoPath == null
                                      ? 'Choose logo'
                                      : 'Change logo',
                            ),
                          ),
                          if (_brandSettings.logoPath != null)
                            TextButton(
                              onPressed: _removeLogo,
                              child: const Text('Remove logo'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.md),
                TextField(
                  controller: _orgNameController,
                  onChanged: _onOrgNameChanged,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    hintText: 'Organisation name',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
