import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/brand_settings.dart';
import '../services/brand_settings_store.dart';
import '../state/app_state.dart';

/// Shared church-settings form state/logic — factored out so the mobile
/// SettingsScreen and desktop SettingsDesktopScreen (PIVOT_PLAN_V2.md
/// Phase 31) share the same load/autosave plumbing instead of each
/// reimplementing it, same reasoning as VideoScrubMixin in Phase 26.
mixin SettingsFormMixin<T extends StatefulWidget> on State<T> {
  final brandSettingsStore = BrandSettingsStore();
  final orgNameController = TextEditingController();
  final addressController = TextEditingController();
  final givingAccountController = TextEditingController();
  final newHashtagController = TextEditingController();
  final List<TextEditingController> serviceLabelControllers = [];
  final List<TextEditingController> serviceTimeControllers = [];

  bool settingsLoading = true;
  bool pickingLogo = false;
  BrandSettings settings = BrandSettings.seeded;

  Future<void> loadSettings() async {
    final loaded = await brandSettingsStore.load();
    if (!mounted) return;
    setState(() {
      settings = loaded;
      orgNameController.text = loaded.organizationName;
      addressController.text = loaded.address;
      givingAccountController.text = loaded.givingAccountText;
      _rebuildServiceControllers();
      settingsLoading = false;
    });
  }

  /// Call from the widget's own [State.dispose] — not overridden here
  /// directly so each screen keeps control of its own disposal order.
  void disposeSettingsControllers() {
    orgNameController.dispose();
    addressController.dispose();
    givingAccountController.dispose();
    newHashtagController.dispose();
    for (final c in [...serviceLabelControllers, ...serviceTimeControllers]) {
      c.dispose();
    }
  }

  void _rebuildServiceControllers() {
    for (final c in [...serviceLabelControllers, ...serviceTimeControllers]) {
      c.dispose();
    }
    serviceLabelControllers.clear();
    serviceTimeControllers.clear();
    for (final s in settings.serviceTimes) {
      serviceLabelControllers.add(TextEditingController(text: s.label));
      serviceTimeControllers.add(TextEditingController(text: s.time));
    }
  }

  void updateSettings(BrandSettings Function(BrandSettings) transform) {
    setState(() => settings = transform(settings));
    unawaited(brandSettingsStore.save(settings));
  }

  void addServiceTime() {
    setState(() {
      settings = settings.copyWith(
        serviceTimes: [...settings.serviceTimes, const ServiceTime(label: '', time: '')],
      );
      serviceLabelControllers.add(TextEditingController());
      serviceTimeControllers.add(TextEditingController());
    });
    unawaited(brandSettingsStore.save(settings));
  }

  void removeServiceTime(int index) {
    setState(() {
      final list = [...settings.serviceTimes]..removeAt(index);
      settings = settings.copyWith(serviceTimes: list);
      serviceLabelControllers.removeAt(index).dispose();
      serviceTimeControllers.removeAt(index).dispose();
    });
    unawaited(brandSettingsStore.save(settings));
  }

  void syncServiceTimeAt(int index) {
    final list = [...settings.serviceTimes];
    list[index] = ServiceTime(
      label: serviceLabelControllers[index].text,
      time: serviceTimeControllers[index].text,
    );
    updateSettings((s) => s.copyWith(serviceTimes: list));
  }

  void addHashtag() {
    final value = newHashtagController.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (value.isEmpty) return;
    if (settings.defaultHashtags.contains(value)) {
      newHashtagController.clear();
      return;
    }
    updateSettings((s) => s.copyWith(defaultHashtags: [...s.defaultHashtags, value]));
    newHashtagController.clear();
  }

  void removeHashtag(String tag) {
    updateSettings((s) => s.copyWith(defaultHashtags: s.defaultHashtags.where((h) => h != tag).toList()));
  }

  Future<void> pickLogo() async {
    setState(() => pickingLogo = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final updated = await brandSettingsStore.updateLogo(settings, bytes, picked.name);
      if (!mounted) return;
      setState(() => settings = updated);
    } finally {
      if (mounted) setState(() => pickingLogo = false);
    }
  }

  Future<void> saveSettings(AppState appState) async {
    updateSettings((s) => s.copyWith(organizationName: orgNameController.text, address: addressController.text));
    await appState.reloadBrandSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
  }

  void syncOrgName() => updateSettings((s) => s.copyWith(organizationName: orgNameController.text));
  void syncAddress() => updateSettings((s) => s.copyWith(address: addressController.text));
}
