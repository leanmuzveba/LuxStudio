import 'package:flutter/material.dart';

import '../main.dart';
import '../models/caption_style.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';
import '../widgets/settings_fields.dart';
import '../widgets/settings_form_mixin.dart';

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
///
/// Form state/autosave logic lives in [SettingsFormMixin], shared with
/// [SettingsDesktopScreen] (Phase 31) — see that file for why.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SettingsFormMixin<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  void dispose() {
    disposeSettingsControllers();
    super.dispose();
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
                onTap: () => saveSettings(appState),
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
      body: settingsLoading
          ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                SettingsCard(
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
                          child: settings.logoUrl == null
                              ? const Icon(Icons.image_outlined, color: LuxColors.textMuted)
                              : Image.network(
                                  '${appState.backendBaseUrl}${settings.logoUrl}',
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(width: 14),
                        OutlinedButton.icon(
                          onPressed: pickingLogo ? null : pickLogo,
                          icon: const Icon(Icons.upload_rounded, size: 16),
                          label: Text(pickingLogo ? 'Opening…' : 'Change Logo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LuxColors.textPrimary,
                            side: const BorderSide(color: LuxColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const FieldLabel('Church Name'),
                    SettingsTextField(controller: orgNameController, onChanged: (_) => syncOrgName()),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsCard(
                  icon: Icons.location_on_outlined,
                  title: 'Contact & Service Times',
                  children: [
                    const FieldLabel('Address'),
                    SettingsTextField(
                      controller: addressController,
                      maxLines: 2,
                      onChanged: (_) => syncAddress(),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < settings.serviceTimes.length; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FieldLabel(i == 0 ? 'Service' : 'Service ${i + 1}'),
                                SettingsTextField(
                                  controller: serviceLabelControllers[i],
                                  hint: 'e.g. Sunday Service',
                                  onChanged: (_) => syncServiceTimeAt(i),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SettingsTextField(
                              controller: serviceTimeControllers[i],
                              hint: 'e.g. 9:00 AM – 12:00 PM',
                              onChanged: (_) => syncServiceTimeAt(i),
                            ),
                          ),
                          IconButton(
                            onPressed: () => removeServiceTime(i),
                            icon: const Icon(Icons.close_rounded, size: 18, color: LuxColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: addServiceTime,
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
                SettingsCard(
                  icon: Icons.text_fields_rounded,
                  title: 'Default Caption Template',
                  subtitle: 'Applied to every new clip. Change anytime per-project in the editor.',
                  children: [
                    Row(
                      children: CaptionTemplate.values.map((t) {
                        final selected = settings.defaultCaptionTemplate == t;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: t == CaptionTemplate.values.last ? 0 : 8),
                            child: TemplateSwatch(
                              label: _captionTemplateLabels[t]!,
                              selected: selected,
                              onTap: () => updateSettings((s) => s.copyWith(defaultCaptionTemplate: t)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsCard(
                  icon: Icons.tag_rounded,
                  title: 'Default Hashtags',
                  subtitle: 'Suggested automatically on every AI summary. Editable per post.',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: settings.defaultHashtags
                          .map((h) => RemovableChip(label: '#$h', onRemove: () => removeHashtag(h)))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SettingsTextField(
                            controller: newHashtagController,
                            hint: 'Add a hashtag',
                            onSubmitted: (_) => addHashtag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        LuxIconAddButton(onTap: addHashtag),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsCard(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Giving Information',
                  subtitle: 'Off by default. Only appended when you explicitly enable it below.',
                  trailing: Switch(
                    value: settings.givingEnabled,
                    onChanged: (v) => updateSettings((s) => s.copyWith(givingEnabled: v)),
                    activeThumbColor: LuxColors.background,
                    activeTrackColor: LuxColors.gold,
                    inactiveThumbColor: LuxColors.textMuted,
                    inactiveTrackColor: LuxColors.surfaceRaised,
                  ),
                  children: [
                    Opacity(
                      opacity: settings.givingEnabled ? 1 : 0.4,
                      child: IgnorePointer(
                        ignoring: !settings.givingEnabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('Giving Account'),
                            SettingsTextField(
                              controller: givingAccountController,
                              onChanged: (v) => updateSettings((s) => s.copyWith(givingAccountText: v)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!settings.givingEnabled) ...[
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
                const SizedBox(height: 16),
                SettingsCard(
                  icon: Icons.lock_outline_rounded,
                  title: 'Session',
                  subtitle: 'This device stays signed in with the shared church passcode until you sign out.',
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => appState.signOut(),
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LuxColors.error,
                        side: const BorderSide(color: LuxColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
