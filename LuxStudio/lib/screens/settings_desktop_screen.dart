import 'package:flutter/material.dart';

import '../main.dart';
import '../models/caption_style.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/settings_fields.dart';
import '../widgets/settings_form_mixin.dart';

const _captionTemplateLabels = <CaptionTemplate, String>{
  CaptionTemplate.boldPop: 'Bold Word',
  CaptionTemplate.minimal: 'Clean Line',
  CaptionTemplate.karaoke: 'Highlight',
};

/// Desktop Settings (Phase 31) — a reskin of the mobile [SettingsScreen]
/// onto `ui_kit/settings_desktop/`'s two-pane shape (left settings-nav +
/// wide content pane), sharing all form state/autosave logic via
/// [SettingsFormMixin] rather than duplicating it.
///
/// **Scope cuts vs. the mockup, same pattern as Phases 26-30:** the
/// mockup's nav categories (Account & Profile, Video Preferences, Output &
/// Encoding, Keyboard Shortcuts, Notifications, Privacy & Security) and
/// their content (email/avatar upload, hardware-acceleration toggle,
/// export-path picker, proxy resolution, keybinding editor, per-item
/// notification toggles) describe a generic desktop video editor with no
/// real feature behind any of it in this app — no user accounts, no local
/// filesystem export target (exports download/share from the backend), no
/// configurable render pipeline, no notification system. Rather than
/// fabricate those, this screen keeps the mockup's left-nav/right-pane
/// *shape* but fills it with the six real church-settings sections that
/// already exist on mobile: Church Profile, Contact & Service Times,
/// Default Caption Template, Default Hashtags, Giving Information,
/// Session. "Discard Changes" is also dropped — every field autosaves on
/// change via [SettingsFormMixin.updateSettings], so there is never an
/// unsaved edit to discard; "Save" here just confirms via a snackbar (same
/// as mobile's Save button).
class SettingsDesktopScreen extends StatefulWidget {
  const SettingsDesktopScreen({super.key});

  @override
  State<SettingsDesktopScreen> createState() => _SettingsDesktopScreenState();
}

class _SettingsSection {
  final IconData icon;
  final String label;
  const _SettingsSection(this.icon, this.label);
}

const _sections = [
  _SettingsSection(Icons.business_rounded, 'Church Profile'),
  _SettingsSection(Icons.location_on_outlined, 'Contact & Service Times'),
  _SettingsSection(Icons.text_fields_rounded, 'Caption Template'),
  _SettingsSection(Icons.tag_rounded, 'Default Hashtags'),
  _SettingsSection(Icons.volunteer_activism_outlined, 'Giving Information'),
  _SettingsSection(Icons.lock_outline_rounded, 'Session'),
];

class _SettingsDesktopScreenState extends State<SettingsDesktopScreen> with SettingsFormMixin<SettingsDesktopScreen> {
  int _selected = 0;

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

    return ColoredBox(
      color: LuxColors.background,
      child: settingsLoading
          ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
          : Column(
              children: [
                _Header(onSave: () => saveSettings(appState)),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionNav(
                        selected: _selected,
                        onSelect: (i) => setState(() => _selected = i),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: _buildSection(_selected, appState),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection(int index, AppState appState) {
    switch (index) {
      case 0:
        return SettingsCard(
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
        );
      case 1:
        return SettingsCard(
          icon: Icons.location_on_outlined,
          title: 'Contact & Service Times',
          children: [
            const FieldLabel('Address'),
            SettingsTextField(controller: addressController, maxLines: 2, onChanged: (_) => syncAddress()),
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
        );
      case 2:
        return SettingsCard(
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
        );
      case 3:
        return SettingsCard(
          icon: Icons.tag_rounded,
          title: 'Default Hashtags',
          subtitle: 'Suggested automatically on every AI summary. Editable per post.',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: settings.defaultHashtags
                  .map<Widget>((h) => RemovableChip(label: '#$h', onRemove: () => removeHashtag(h)))
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
        );
      case 4:
        return SettingsCard(
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
        );
      case 5:
      default:
        return SettingsCard(
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
        );
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSave;
  const _Header({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.border))),
      child: Row(
        children: [
          const Icon(Icons.settings_rounded, size: 18, color: LuxColors.gold),
          const SizedBox(width: 8),
          Text('Church Settings', style: LuxText.manrope(size: 15.5, weight: FontWeight.w700)),
          const Spacer(),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(LuxRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(LuxRadii.pill),
              onTap: onSave,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: const BoxDecoration(
                  gradient: LuxColors.goldGradient,
                  borderRadius: BorderRadius.all(Radius.circular(LuxRadii.pill)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Save',
                  style: LuxText.manrope(size: 12.5, weight: FontWeight.w800, color: LuxColors.background),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _SectionNav({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: LuxColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _sections.length; i++) ...[
            _SectionNavItem(
              icon: _sections[i].icon,
              label: _sections[i].label,
              active: i == selected,
              onTap: () => onSelect(i),
            ),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

class _SectionNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SectionNavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? LuxColors.surfaceRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: active ? LuxColors.gold : LuxColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: LuxText.manrope(
                    size: 13,
                    weight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? LuxColors.textPrimary : LuxColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
