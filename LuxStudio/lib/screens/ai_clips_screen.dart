import 'package:flutter/material.dart';

import '../main.dart';
import '../models/ai_clip.dart';
import '../services/project_dashboard.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_app_bar.dart';
import '../widgets/lux_buttons.dart';
import '../widgets/lux_card.dart';
import '../widgets/lux_icon_button.dart';
import '../widgets/lux_pill.dart';
import '../widgets/sticky_cta_bar.dart';

/// Screen 3 — AI Suggested Clips.
///
/// Ranked list of AI-surfaced moments, each with a category pill, an
/// "include in export" toggle, and an "Edit Clip" action that jumps back
/// to the editor seeked to that clip's range.
class AiClipsScreen extends StatelessWidget {
  const AiClipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      appBar: LuxAppBar(
        title: 'AI Clips',
        actions: [
          AnimatedBuilder(
            animation: appState,
            builder: (context, _) => LuxIconButton(
              icon: Icons.auto_awesome_rounded,
              variant: LuxIconButtonVariant.subtle,
              tooltip: 'Regenerate suggestions',
              onPressed: appState.isGeneratingClips ? null : appState.generateClipSuggestions,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (appState.isGeneratingClips) {
            return const Center(child: CircularProgressIndicator(color: LuxColors.gold));
          }

          final clips = List<AiClip>.from(appState.suggestedClips)
            ..sort((a, b) => b.viralScore.compareTo(a.viralScore));
          final includedCount = clips.where((c) => c.includeInExport).length;
          final sourceLabel = appState.project == null
              ? ''
              : formatProjectDuration(appState.project!.processedDuration);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${clips.length} clips found', style: LuxText.sora(size: 16, weight: FontWeight.w800)),
                    if (sourceLabel.isNotEmpty)
                      Text(
                        'from $sourceLabel source',
                        style: LuxText.manrope(size: 12, weight: FontWeight.w600, color: LuxColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (appState.clipGenerationError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    appState.clipGenerationError!,
                    style: LuxText.manrope(size: 12.5, color: LuxColors.error),
                  ),
                ),
              Expanded(
                child: clips.isEmpty
                    ? _EmptyState(hasTranscript: appState.transcript.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: clips.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ClipCard(
                            clip: clips[index],
                            onToggleInclude: () => appState.toggleClipIncludeInExport(clips[index].id),
                            onEditClip: () {
                              appState.chooseClip(clips[index]);
                              Navigator.of(context).pushNamed(AppRoutes.editor);
                            },
                          ),
                        ),
                      ),
              ),
              if (clips.isNotEmpty)
                StickyCtaBar(
                  child: LuxPrimaryButton(
                    label: 'Continue with $includedCount Clip${includedCount == 1 ? '' : 's'}',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: includedCount == 0
                        ? null
                        : () {
                            final first = clips.firstWhere((c) => c.includeInExport);
                            appState.chooseClip(first);
                            Navigator.of(context).pushNamed(AppRoutes.social);
                          },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasTranscript;
  const _EmptyState({required this.hasTranscript});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          hasTranscript
              ? 'No clips yet — tap the sparkle icon above to generate some.'
              : 'Transcribe captions first — the AI reads the transcript to find complete, engaging moments.',
          textAlign: TextAlign.center,
          style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
        ),
      ),
    );
  }
}

class _ClipCard extends StatelessWidget {
  final AiClip clip;
  final VoidCallback onToggleInclude;
  final VoidCallback onEditClip;

  const _ClipCard({required this.clip, required this.onToggleInclude, required this.onEditClip});

  LuxPillTone get _tone {
    final tones = [LuxPillTone.gold, LuxPillTone.amber, LuxPillTone.tan];
    if (clip.category.isEmpty) return LuxPillTone.neutral;
    return tones[clip.category.hashCode.abs() % tones.length];
  }

  @override
  Widget build(BuildContext context) {
    return LuxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: LuxColors.slate, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Icon(Icons.movie_creation_outlined, size: 22, color: LuxColors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(clip.title, style: LuxText.manrope(size: 13.5, weight: FontWeight.w700, height: 1.3)),
                    const SizedBox(height: 5),
                    Text(
                      '${clip.timeRangeLabel} · ${clip.durationLabel}',
                      style: LuxText.manrope(size: 11.5, weight: FontWeight.w600, color: LuxColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (clip.category.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: LuxPill(label: clip.category, tone: _tone),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: LuxColors.divider, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onToggleInclude,
                child: Row(
                  children: [
                    Icon(
                      clip.includeInExport ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: clip.includeInExport ? LuxColors.gold : LuxColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Include in export',
                      style: LuxText.manrope(size: 12.5, weight: FontWeight.w700, color: LuxColors.iconSubtle),
                    ),
                  ],
                ),
              ),
              LuxGhostButton(label: 'Edit Clip', icon: Icons.arrow_forward_rounded, onPressed: onEditClip),
            ],
          ),
        ],
      ),
    );
  }
}
