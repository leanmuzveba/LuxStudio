import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/brand_settings.dart';
import '../services/brand_settings_store.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';
import '../widgets/lux_buttons.dart';
import '../widgets/lux_card.dart';
import '../widgets/sticky_cta_bar.dart';

const _colorSwatches = <BrandColorPreset, Color>{
  BrandColorPreset.gold: LuxColors.gold,
  BrandColorPreset.amber: LuxColors.amber,
  BrandColorPreset.bronze: LuxColors.bronze,
  BrandColorPreset.tan: LuxColors.tan,
  BrandColorPreset.slate: LuxColors.slate,
  BrandColorPreset.ink: LuxColors.background,
};

const _colorLabels = <BrandColorPreset, String>{
  BrandColorPreset.gold: 'Gold',
  BrandColorPreset.amber: 'Amber',
  BrandColorPreset.bronze: 'Bronze',
  BrandColorPreset.tan: 'Tan',
  BrandColorPreset.slate: 'Slate',
  BrandColorPreset.ink: 'Ink',
};

const _cornerLabels = <WatermarkCorner, String>{
  WatermarkCorner.topLeft: 'Top-left',
  WatermarkCorner.topRight: 'Top-right',
  WatermarkCorner.bottomLeft: 'Bottom-left',
  WatermarkCorner.bottomRight: 'Bottom-right',
};

/// Branding — logo, organisation name, brand color, and watermark
/// position applied across exports. A bottom-nav tab (also directly
/// pushable, e.g. from the editor's Branding chip) so it has no back
/// arrow when shown as a tab.
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
      final bytes = await picked.readAsBytes();
      final updated = await _brandSettingsStore.updateLogo(_brandSettings, bytes, picked.name);
      if (!mounted) return;
      setState(() => _brandSettings = updated);
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  void _onOrgNameChanged(String value) {
    final updated = BrandSettings(
      logoUrl: _brandSettings.logoUrl,
      organizationName: value,
      color: _brandSettings.color,
      watermarkCorner: _brandSettings.watermarkCorner,
    );
    setState(() => _brandSettings = updated);
    unawaited(_brandSettingsStore.save(updated));
  }

  void _selectColor(BrandColorPreset color) {
    final updated = BrandSettings(
      logoUrl: _brandSettings.logoUrl,
      organizationName: _brandSettings.organizationName,
      color: color,
      watermarkCorner: _brandSettings.watermarkCorner,
    );
    setState(() => _brandSettings = updated);
    unawaited(_brandSettingsStore.save(updated));
  }

  void _selectCorner(WatermarkCorner corner) {
    final updated = BrandSettings(
      logoUrl: _brandSettings.logoUrl,
      organizationName: _brandSettings.organizationName,
      color: _brandSettings.color,
      watermarkCorner: corner,
    );
    setState(() => _brandSettings = updated);
    unawaited(_brandSettingsStore.save(updated));
  }

  Future<void> _save(AppState appState) async {
    await _brandSettingsStore.save(_brandSettings);
    await appState.reloadBrandSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branding saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      appBar: const LuxAppBar(title: 'Branding', showBack: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
          : AnimatedBuilder(
              animation: appState,
              builder: (context, _) {
                var watermarkPreset = false;
                for (final preset in appState.brandingPresets) {
                  if (preset.id == 'watermark') {
                    watermarkPreset = preset.enabled;
                    break;
                  }
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          LuxCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Apply Branding', style: LuxText.manrope(size: 14, weight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Add your logo and colors to exported clips',
                                        style: LuxText.manrope(size: 12, weight: FontWeight.w500, color: LuxColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: watermarkPreset,
                                  onChanged: (_) => appState.toggleBranding('watermark'),
                                  activeThumbColor: LuxColors.background,
                                  activeTrackColor: LuxColors.gold,
                                  inactiveThumbColor: LuxColors.textMuted,
                                  inactiveTrackColor: LuxColors.surfaceRaised,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Logo', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          LuxCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: LuxColors.surfaceDashed,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.antiAlias,
                                  child: _brandSettings.logoUrl == null
                                      ? const Icon(Icons.image_outlined, color: LuxColors.textMuted)
                                      : Image.network(
                                          '${appState.backendBaseUrl}${_brandSettings.logoUrl}',
                                          fit: BoxFit.contain,
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _brandSettings.logoUrl == null ? 'No logo set' : 'Logo set',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: LuxText.manrope(size: 13, weight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_cornerLabels[_brandSettings.watermarkCorner]} watermark',
                                        style: LuxText.manrope(size: 11.5, weight: FontWeight.w600, color: LuxColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                LuxGhostButton(
                                  label: _pickingLogo ? 'Opening…' : (_brandSettings.logoUrl == null ? 'Choose' : 'Change'),
                                  onPressed: _pickingLogo ? null : _pickLogo,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Organisation Name', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          LuxCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: TextField(
                              controller: _orgNameController,
                              onChanged: _onOrgNameChanged,
                              style: LuxText.manrope(size: 14, weight: FontWeight.w600),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Your organisation name',
                                hintStyle: LuxText.manrope(size: 14, weight: FontWeight.w600, color: LuxColors.textMuted),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Brand Colors', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          LuxCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: BrandColorPreset.values.map((preset) {
                                final selected = _brandSettings.color == preset;
                                return GestureDetector(
                                  onTap: () => _selectColor(preset),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: _colorSwatches[preset],
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected ? LuxColors.gold : Colors.transparent,
                                            width: 2.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: selected
                                            ? Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                                color: preset == BrandColorPreset.ink ? LuxColors.gold : LuxColors.background,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _colorLabels[preset]!,
                                        style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: LuxColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Watermark Position', style: LuxText.sora(size: 15, weight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1,
                            children: WatermarkCorner.values.map((corner) {
                              final selected = _brandSettings.watermarkCorner == corner;
                              return LuxCard(
                                onTap: () => _selectCorner(corner),
                                borderColor: selected ? LuxColors.gold : null,
                                backgroundColor: selected ? LuxColors.gold.withValues(alpha: 0.08) : null,
                                padding: EdgeInsets.zero,
                                child: Center(
                                  child: Icon(
                                    _cornerIcon(corner),
                                    size: 20,
                                    color: selected ? LuxColors.gold : LuxColors.textMuted,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    StickyCtaBar(
                      child: LuxPrimaryButton(label: 'Save Branding', onPressed: () => _save(appState)),
                    ),
                  ],
                );
              },
            ),
    );
  }

  IconData _cornerIcon(WatermarkCorner corner) => switch (corner) {
        WatermarkCorner.topLeft => Icons.north_west_rounded,
        WatermarkCorner.topRight => Icons.north_east_rounded,
        WatermarkCorner.bottomLeft => Icons.south_west_rounded,
        WatermarkCorner.bottomRight => Icons.south_east_rounded,
      };
}
