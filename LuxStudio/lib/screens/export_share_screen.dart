import 'package:flutter/material.dart';

import '../models/export_destination.dart';
import '../state/app_state.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/viral_score_badge.dart';

/// Screen 4 — Export & Share.
///
/// Pick one or more destinations, choose an AI-generated caption, toggle
/// branding presets, then share. This is the terminal screen of the
/// import → edit → select → export flow.
class ExportShareScreen extends StatelessWidget {
  const ExportShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Export & Share')),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final clip = appState.selectedClip;
          if (clip == null) {
            return const Center(
              child: Text(
                'Pick a clip from AI Suggested Clips first.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(Gaps.md),
                  children: [
                    _ClipSummaryCard(clip: clip.title, score: clip.viralScore, range: clip.timeRangeLabel),
                    const SizedBox(height: Gaps.lg),
                    _SectionLabel('DESTINATIONS'),
                    const SizedBox(height: Gaps.sm),
                    _DestinationGrid(appState: appState),
                    const SizedBox(height: Gaps.lg),
                    _SectionLabel('AI-GENERATED CAPTION'),
                    const SizedBox(height: Gaps.sm),
                    _CaptionPicker(appState: appState),
                    const SizedBox(height: Gaps.lg),
                    _SectionLabel('BRANDING'),
                    const SizedBox(height: Gaps.sm),
                    _BrandingList(appState: appState),
                    const SizedBox(height: Gaps.lg),
                  ],
                ),
              ),
              _buildShareBar(context, appState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShareBar(BuildContext context, AppState appState) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Gaps.md,
        Gaps.sm,
        Gaps.md,
        MediaQuery.of(context).padding.bottom + Gaps.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: GradientButton(
        label: appState.selectedDestinations.length == 1
            ? 'Share to ${ExportDestination.all.firstWhere((d) => d.platform == appState.selectedDestinations.first).label}'
            : 'Share to ${appState.selectedDestinations.length} destinations',
        icon: Icons.share_rounded,
        onPressed: () => _confirmShare(context),
      ),
    );
  }

  void _confirmShare(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting… you\'ll get a notification when it\'s posted.')),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelSmall);
  }
}

class _ClipSummaryCard extends StatelessWidget {
  final String clip;
  final int score;
  final String range;

  const _ClipSummaryCard({required this.clip, required this.score, required this.range});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 78,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clip, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(range, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          ViralScoreBadge(score: score, compact: true),
        ],
      ),
    );
  }
}

class _DestinationGrid extends StatelessWidget {
  final AppState appState;
  const _DestinationGrid({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gaps.sm,
      runSpacing: Gaps.sm,
      children: ExportDestination.all.map((dest) {
        final selected = appState.selectedDestinations.contains(dest.platform);
        return GestureDetector(
          onTap: () => appState.toggleDestination(dest.platform),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: (MediaQuery.of(context).size.width - Gaps.md * 2 - Gaps.sm) / 2,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(dest.icon, size: 20, color: selected ? AppColors.accent : AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dest.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? AppColors.textPrimary : AppColors.textPrimary)),
                      Text(dest.aspectHint, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.accent),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CaptionPicker extends StatelessWidget {
  final AppState appState;
  const _CaptionPicker({required this.appState});

  @override
  Widget build(BuildContext context) {
    if (appState.isGeneratingSocialCopy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Gaps.md),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...List.generate(appState.generatedCaptions.length, (i) {
          final selected = appState.selectedCaptionIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: Gaps.sm),
            child: GestureDetector(
              onTap: () => appState.selectCaption(i),
              child: Container(
                padding: const EdgeInsets.all(Gaps.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.5 : 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      size: 18,
                      color: selected ? AppColors.accent : AppColors.textMuted,
                    ),
                    const SizedBox(width: Gaps.sm),
                    Expanded(
                      child: Text(
                        appState.generatedCaptions[i],
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (appState.socialCopyError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.sm),
            child: Text(
              appState.socialCopyError!,
              style: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
            ),
          ),
        GradientButton(
          label: appState.generatedCaptions.isEmpty ? 'Generate captions' : 'Regenerate captions',
          icon: Icons.auto_awesome_rounded,
          expand: false,
          onPressed: appState.generateSocialCopy,
        ),
      ],
    );
  }
}

class _BrandingList extends StatelessWidget {
  final AppState appState;
  const _BrandingList({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: appState.brandingPresets.map((preset) {
        return Container(
          margin: const EdgeInsets.only(bottom: Gaps.sm),
          padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: preset.enabled,
            onChanged: (_) => appState.toggleBranding(preset.id),
            title: Text(preset.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _subtitle(preset),
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _subtitle(BrandingPreset preset) {
    final brand = appState.brandSettings;
    switch (preset.id) {
      case 'watermark':
        return brand.logoPath == null
            ? 'No logo set — add one in Settings.'
            : 'Your logo, bottom-right corner.';
      case 'lower_third':
        return brand.organizationName.trim().isEmpty
            ? 'No organisation name set — add one in Settings.'
            : '${brand.organizationName} on first 3s.';
      default:
        return preset.description;
    }
  }
}
