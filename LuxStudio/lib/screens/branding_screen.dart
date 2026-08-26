import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/brand_settings.dart';
import '../services/brand_settings_store.dart';
import '../theme/app_theme.dart';

/// Branding — a logo and organisation name applied across exports when
/// enabled. A bottom-nav tab (not a pushed screen), so it has no back
/// arrow. Split out of Settings so Settings can stay focused on the
/// Gemini API key.
///
/// Still on the pre-redesign [AppColors] theme for now — restyled with
/// the Lux design system (plus brand color and watermark-corner pickers)
/// in a later phase.
class BrandingScreen extends StatefulWidget {
  const BrandingScreen({super.key});

  @override
  State<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  final _brandSettingsStore = BrandSettingsStore();
  final _orgNameController = TextEditingController();
  bool _loading = true;
  BrandSettings _brandSettings = BrandSettings.empty;
  bool _pickingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final brand = await _brandSettingsStore.load();
    if (!mounted) return;
    setState(() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Branding')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Gaps.md),
              children: [
                Text('Logo & organisation', style: Theme.of(context).textTheme.titleMedium),
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
