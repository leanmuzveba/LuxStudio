import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/brand_settings.dart';
import '../models/caption_style.dart';
import '../services/brand_settings_store.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';

const _captionTemplateLabels = <CaptionTemplate, String>{
  CaptionTemplate.boldPop: 'Bold Word',
  CaptionTemplate.minimal: 'Clean Line',
  CaptionTemplate.karaoke: 'Highlight',
};

/// Settings — matches `ui_kit/settings/index.html` ("Church Settings").
/// Absorbs what used to be the separate Branding tab (logo, org name,
/// brand color, watermark corner — Phase 7 dropped Branding as its own
/// bottom-nav tab in anticipation of this) plus the previously-unmodeled
/// church-config fields from CLAUDE.md's default church config: address,
/// service times, default caption template, default hashtags, and the
/// giving-info toggle (off by default — PRD data-safety requirement).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _brandSettingsStore = BrandSettingsStore();
  final _orgNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _givingAccountController = TextEditingController();
  final _newHashtagController = TextEditingController();
  final List<TextEditingController> _serviceLabelControllers = [];
  final List<TextEditingController> _serviceTimeControllers = [];

  bool _loading = true;
  bool _pickingLogo = false;
  BrandSettings _settings = BrandSettings.seeded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _addressController.dispose();
    _givingAccountController.dispose();
    _newHashtagController.dispose();
    for (final c in [..._serviceLabelControllers, ..._serviceTimeControllers]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _brandSettingsStore.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _orgNameController.text = settings.organizationName;
      _addressController.text = settings.address;
      _givingAccountController.text = settings.givingAccountText;
      _rebuildServiceControllers();
      _loading = false;
    });
  }

  void _rebuildServiceControllers() {
    for (final c in [..._serviceLabelControllers, ..._serviceTimeControllers]) {
      c.dispose();
    }
    _serviceLabelControllers.clear();
    _serviceTimeControllers.clear();
    for (final s in _settings.serviceTimes) {
      _serviceLabelControllers.add(TextEditingController(text: s.label));
      _serviceTimeControllers.add(TextEditingController(text: s.time));
    }
  }

  void _update(BrandSettings Function(BrandSettings) transform) {
    setState(() => _settings = transform(_settings));
    unawaited(_brandSettingsStore.save(_settings));
  }

  void _addServiceTime() {
    setState(() {
      _settings = _settings.copyWith(
        serviceTimes: [..._settings.serviceTimes, const ServiceTime(label: '', time: '')],
      );
      _serviceLabelControllers.add(TextEditingController());
      _serviceTimeControllers.add(TextEditingController());
    });
    unawaited(_brandSettingsStore.save(_settings));
  }

  void _removeServiceTime(int index) {
    setState(() {
      final list = [..._settings.serviceTimes]..removeAt(index);
      _settings = _settings.copyWith(serviceTimes: list);
      _serviceLabelControllers.removeAt(index).dispose();
      _serviceTimeControllers.removeAt(index).dispose();
    });
    unawaited(_brandSettingsStore.save(_settings));
  }

  void _syncServiceTimeAt(int index) {
    final list = [..._settings.serviceTimes];
    list[index] = ServiceTime(
      label: _serviceLabelControllers[index].text,
      time: _serviceTimeControllers[index].text,
    );
    _update((s) => s.copyWith(serviceTimes: list));
  }

  void _addHashtag() {
    final value = _newHashtagController.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (value.isEmpty) return;
    if (_settings.defaultHashtags.contains(value)) {
      _newHashtagController.clear();
      return;
    }
    _update((s) => s.copyWith(defaultHashtags: [...s.defaultHashtags, value]));
    _newHashtagController.clear();
  }

  void _removeHashtag(String tag) {
    _update((s) => s.copyWith(defaultHashtags: s.defaultHashtags.where((h) => h != tag).toList()));
  }

  Future<void> _pickLogo() async {
    setState(() => _pickingLogo = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final updated = await _brandSettingsStore.updateLogo(_settings, bytes, picked.name);
      if (!mounted) return;
      setState(() => _settings = updated);
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _save(AppState appState) async {
    _update((s) => s.copyWith(organizationName: _orgNameController.text, address: _addressController.text));
    await appState.reloadBrandSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      appBar: LuxAppBar(
        title: 'Church Settings',
        subtitle: 'Branding & Configuration',
        showBack: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(LuxRadii.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(LuxRadii.pill),
                onTap: () => _save(appState),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    gradient: LuxColors.goldGradient,
                    borderRadius: BorderRadius.all(Radius.circular(LuxRadii.pill)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Save',
                    style: LuxText.manrope(size: 12, weight: FontWeight.w800, color: LuxColors.background),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                _SettingsCard(
                  icon: Icons.business_rounded,
                  title: 'Church Profile',
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: LuxColors.surfaceDashed,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          clipBehavior: Clip.antiAlias,
                          child: _settings.logoUrl == null
                              ? const Icon(Icons.image_outlined, color: LuxColors.textMuted)
                              : Image.network(
                                  '${appState.backendBaseUrl}${_settings.logoUrl}',
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(width: 14),
                        OutlinedButton.icon(
                          onPressed: _pickingLogo ? null : _pickLogo,
                          icon: const Icon(Icons.upload_rounded, size: 16),
                          label: Text(_pickingLogo ? 'Opening…' : 'Change Logo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LuxColors.textPrimary,
                            side: const BorderSide(color: LuxColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel('Church Name'),
                    _SettingsTextField(controller: _orgNameController, onChanged: (_) => _syncOrgName()),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  icon: Icons.location_on_outlined,
                  title: 'Contact & Service Times',
                  children: [
                    const _FieldLabel('Address'),
                    _SettingsTextField(
                      controller: _addressController,
                      maxLines: 2,
                      onChanged: (_) => _syncAddress(),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _settings.serviceTimes.length; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(i == 0 ? 'Service' : 'Service ${i + 1}'),
                                _SettingsTextField(
                                  controller: _serviceLabelControllers[i],
                                  hint: 'e.g. Sunday Service',
                                  onChanged: (_) => _syncServiceTimeAt(i),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SettingsTextField(
                              controller: _serviceTimeControllers[i],
                              hint: 'e.g. 9:00 AM – 12:00 PM',
                              onChanged: (_) => _syncServiceTimeAt(i),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeServiceTime(i),
                            icon: const Icon(Icons.close_rounded, size: 18, color: LuxColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: _addServiceTime,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Another Service Time'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LuxColors.gold,
                        side: const BorderSide(color: LuxColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  icon: Icons.text_fields_rounded,
                  title: 'Default Caption Template',
                  subtitle: 'Applied to every new clip. Change anytime per-project in the editor.',
                  children: [
                    Row(
                      children: CaptionTemplate.values.map((t) {
                        final selected = _settings.defaultCaptionTemplate == t;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: t == CaptionTemplate.values.last ? 0 : 8),
                            child: _TemplateSwatch(
                              label: _captionTemplateLabels[t]!,
                              selected: selected,
                              onTap: () => _update((s) => s.copyWith(defaultCaptionTemplate: t)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  icon: Icons.tag_rounded,
                  title: 'Default Hashtags',
                  subtitle: 'Suggested automatically on every AI summary. Editable per post.',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _settings.defaultHashtags
                          .map((h) => _RemovableChip(label: '#$h', onRemove: () => _removeHashtag(h)))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SettingsTextField(
                            controller: _newHashtagController,
                            hint: 'Add a hashtag',
                            onSubmitted: (_) => _addHashtag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        LuxIconAddButton(onTap: _addHashtag),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Giving Information',
                  subtitle: 'Off by default. Only appended when you explicitly enable it below.',
                  trailing: Switch(
                    value: _settings.givingEnabled,
                    onChanged: (v) => _update((s) => s.copyWith(givingEnabled: v)),
                    activeThumbColor: LuxColors.background,
                    activeTrackColor: LuxColors.gold,
                    inactiveThumbColor: LuxColors.textMuted,
                    inactiveTrackColor: LuxColors.surfaceRaised,
                  ),
                  children: [
                    Opacity(
                      opacity: _settings.givingEnabled ? 1 : 0.4,
                      child: IgnorePointer(
                        ignoring: !_settings.givingEnabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Giving Account'),
                            _SettingsTextField(
                              controller: _givingAccountController,
                              onChanged: (v) => _update((s) => s.copyWith(givingAccountText: v)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_settings.givingEnabled) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 14, color: LuxColors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Giving details will not be included in generated posts while this is off.',
                              style: LuxText.manrope(size: 11.5, color: LuxColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }

  void _syncOrgName() => _update((s) => s.copyWith(organizationName: _orgNameController.text));
  void _syncAddress() => _update((s) => s.copyWith(address: _addressController.text));
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  const _SettingsCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxColors.surface,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: LuxColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: LuxText.manrope(size: 14, weight: FontWeight.w700)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: LuxText.manrope(size: 11.5, color: LuxColors.textSecondary, height: 1.4)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: LuxText.manrope(size: 9.5, weight: FontWeight.w700, color: LuxColors.textMuted, letterSpacing: 0.8),
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _SettingsTextField({
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: LuxText.manrope(size: 13, color: LuxColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: LuxColors.background,
        hintText: hint,
        hintStyle: LuxText.manrope(size: 13, color: LuxColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      ),
    );
  }
}

class LuxIconAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const LuxIconAddButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.gold,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const SizedBox(width: 44, height: 44, child: Icon(Icons.add_rounded, color: LuxColors.background)),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _RemovableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LuxColors.gold.withValues(alpha: 0.1),
        border: Border.all(color: LuxColors.gold.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: LuxText.manrope(size: 11, weight: FontWeight.w600, color: LuxColors.gold)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 13, color: LuxColors.gold),
          ),
        ],
      ),
    );
  }
}

class _TemplateSwatch extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TemplateSwatch({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? LuxColors.gold : LuxColors.border, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              height: 32,
              decoration: BoxDecoration(
                gradient: LuxColors.goldGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('Aa', style: LuxText.sora(size: 14, weight: FontWeight.w800, color: LuxColors.background)),
            ),
            const SizedBox(height: 6),
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: LuxText.manrope(size: 10, weight: FontWeight.w600, color: LuxColors.textSecondary),
                ),
                if (selected)
                  const Positioned(
                    right: -4,
                    top: -18,
                    child: Icon(Icons.check_circle_rounded, size: 14, color: LuxColors.gold),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
