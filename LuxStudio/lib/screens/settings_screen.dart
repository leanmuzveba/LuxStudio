import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';

/// Settings.
///
/// Transitional placeholder: the Gemini API key entry that used to live
/// here moved server-side with the backend pivot (Phase 2) — the key is
/// now a backend-only env var and never touches the client, so there's
/// nothing left for the user to configure on this screen. Phase 13
/// replaces this with the real Settings screen (church profile, service
/// times, caption template default, hashtag defaults, giving toggle) per
/// the new UI kit.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.background,
      appBar: const LuxAppBar(title: 'Settings', showBack: false),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Settings are being redesigned to match the new church-branded '
          'UI kit (church profile, service times, caption defaults, '
          'hashtags, giving info). The Gemini API key now lives on the '
          'backend and no longer needs to be entered here.',
          style: LuxText.manrope(size: 13, color: LuxColors.textSecondary, height: 1.5),
        ),
      ),
    );
  }
}
