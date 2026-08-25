import 'package:flutter/material.dart';

import '../main.dart';
import '../models/ai_clip.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/viral_score_badge.dart';

/// Screen 3 — AI Suggested Clips.
///
/// Ranked, scrollable list of AI-surfaced moments. Each card is a 9:16
/// preview with a title overlay, timestamp range, viral score, and an
/// "Edit & Export" button that hands the clip off to the export screen.
class AiClipsScreen extends StatelessWidget {
  const AiClipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Suggested Clips'),
        actions: [
          AnimatedBuilder(
            animation: appState,
            builder: (context, _) => IconButton(
              icon: appState.isGeneratingClips
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: 'Regenerate suggestions',
              onPressed: appState.isGeneratingClips ? null : appState.generateClipSuggestions,
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final clips = List<AiClip>.from(appState.suggestedClips)
            ..sort((a, b) => b.viralScore.compareTo(a.viralScore));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, 0),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${clips.length} moments ranked by predicted engagement',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (appState.clipGenerationError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.sm),
                  child: Text(
                    appState.clipGenerationError!,
                    style: const TextStyle(fontSize: 12.5, color: Colors.redAccent),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(Gaps.md),
                  itemCount: clips.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: Gaps.md),
                    child: _ClipCard(
                      clip: clips[index],
                      rank: index + 1,
                      onEditAndExport: () {
                        appState.chooseClip(clips[index]);
                        Navigator.of(context).pushNamed(AppRoutes.export);
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClipCard extends StatelessWidget {
  final AiClip clip;
  final int rank;
  final VoidCallback onEditAndExport;

  const _ClipCard({
    required this.clip,
    required this.rank,
    required this.onEditAndExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(Gaps.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClipThumbnail(clip: clip, rank: rank),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clip.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ViralScoreBadge(score: clip.viralScore),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${clip.timeRangeLabel}  ·  ${clip.durationLabel}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  clip.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Gaps.sm),
                GradientButton(
                  label: 'Edit & Export',
                  icon: Icons.arrow_forward_rounded,
                  expand: false,
                  onPressed: onEditAndExport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipThumbnail extends StatelessWidget {
  final AiClip clip;
  final int rank;

  const _ClipThumbnail({required this.clip, required this.rank});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.scoreGradient(clip.viralScore).colors.first.withValues(alpha: 0.35),
                    AppColors.surfaceSunken,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 24),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
