import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';
import '../widgets/lux_buttons.dart';
import '../widgets/lux_card.dart';
import '../widgets/lux_chip.dart';
import '../widgets/lux_icon_button.dart';
import '../widgets/sticky_cta_bar.dart';

/// Social Content — the clip's AI-written social copy as independently
/// editable/copyable fields (title, summary, description, hashtags)
/// instead of picking one of several caption strings.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      appBar: LuxAppBar(
        title: 'Social Content',
        actions: [
          AnimatedBuilder(
            animation: appState,
            builder: (context, _) => LuxIconButton(
              icon: Icons.auto_awesome_rounded,
              variant: LuxIconButtonVariant.subtle,
              tooltip: 'Regenerate',
              onPressed: appState.selectedClip == null || appState.isGeneratingSocialCopy
                  ? null
                  : appState.generateSocialCopy,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final clip = appState.selectedClip;
          if (clip == null) {
            return Center(
              child: Text(
                'Pick a clip from AI Clips first.',
                style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
              ),
            );
          }

          if (appState.isGeneratingSocialCopy) {
            return const Center(child: CircularProgressIndicator(color: LuxColors.gold));
          }

          final copy = appState.socialCopy;
          if (copy == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 32, color: LuxColors.textMuted),
                    const SizedBox(height: 10),
                    Text(
                      'Generate ready-to-post copy for this clip.',
                      textAlign: TextAlign.center,
                      style: LuxText.manrope(size: 12.5, color: LuxColors.textSecondary),
                    ),
                    if (appState.socialCopyError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        appState.socialCopyError!,
                        textAlign: TextAlign.center,
                        style: LuxText.manrope(size: 11.5, color: LuxColors.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    LuxSecondaryButton(
                      label: 'Generate',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: appState.generateSocialCopy,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _CopyCard(label: 'Title', value: copy.title, onCopy: () => _copy(context, 'Title', copy.title)),
                    const SizedBox(height: 12),
                    _CopyCard(label: 'Summary', value: copy.summary, onCopy: () => _copy(context, 'Summary', copy.summary)),
                    const SizedBox(height: 12),
                    _CopyCard(
                      label: 'Description',
                      value: copy.description,
                      onCopy: () => _copy(context, 'Description', copy.description),
                    ),
                    const SizedBox(height: 12),
                    LuxCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'HASHTAGS',
                                style: LuxText.manrope(size: 11.5, weight: FontWeight.w800, color: LuxColors.textSecondary, letterSpacing: 0.5),
                              ),
                              LuxIconButton(
                                icon: Icons.copy_all_rounded,
                                variant: LuxIconButtonVariant.subtle,
                                size: 28,
                                iconSize: 15,
                                onPressed: () => _copy(
                                  context,
                                  'Hashtags',
                                  copy.hashtags.map((h) => '#$h').join(' '),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: copy.hashtags
                                .map((h) => LuxChip(label: '#$h'))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              StickyCtaBar(
                child: LuxPrimaryButton(
                  label: 'Continue to Export',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.export),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CopyCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  const _CopyCard({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return LuxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: LuxText.manrope(size: 11.5, weight: FontWeight.w800, color: LuxColors.textSecondary, letterSpacing: 0.5),
              ),
              LuxIconButton(
                icon: Icons.copy_all_rounded,
                variant: LuxIconButtonVariant.subtle,
                size: 28,
                iconSize: 15,
                onPressed: onCopy,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value.isEmpty ? '—' : value,
            style: LuxText.manrope(size: 13.5, color: LuxColors.transcriptBody, height: 1.55),
          ),
        ],
      ),
    );
  }
}
