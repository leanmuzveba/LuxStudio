import 'package:flutter/material.dart';

import '../main.dart';
import '../models/ai_clip.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_icon_button.dart';

/// Screen 3 — AI Clip Finder. Matches `ui_kit/clips/index.html`: a
/// featured top card (full treatment — glowing viral-score badge, big
/// overlay heading) and compact secondary cards below, each with its own
/// "Edit & Export" action. No real per-clip thumbnail exists (no frame
/// extraction is built), so the "image" area is a styled placeholder
/// frame rather than a real photo — everything else (badge, time chip,
/// overlay heading, play button) still renders on top of it.
///
/// The old batch include-in-export toggle + "Continue with N Clips" CTA
/// are dropped: the mockup has no batch-selection concept on this screen
/// at all, matching where Phase 12 is headed anyway (Share becomes a
/// single-clip flow). Batch export isn't gone — `export_share_screen.dart`
/// is still reachable from the Editor's EXPORT button — this screen just
/// no longer curates which clips go into it.
class AiClipsScreen extends StatelessWidget {
  const AiClipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final clips = List<AiClip>.from(appState.suggestedClips)
              ..sort((a, b) => b.viralScore.compareTo(a.viralScore));

            return Column(
              children: [
                _buildHeader(context, appState),
                Expanded(
                  child: appState.isGeneratingClips
                      ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
                      : clips.isEmpty
                          ? _EmptyState(
                              hasTranscript: appState.transcript.isNotEmpty,
                              error: appState.clipGenerationError,
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              children: [
                                Text('Recommended Shorts', style: LuxText.sora(size: 20, weight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  "We've identified ${clips.length} viral-ready moment${clips.length == 1 ? '' : 's'}.",
                                  style: LuxText.manrope(size: 13, weight: FontWeight.w500, color: LuxColors.textSecondary),
                                ),
                                const SizedBox(height: 20),
                                for (var i = 0; i < clips.length; i++) ...[
                                  _ClipCard(
                                    clip: clips[i],
                                    featured: i == 0,
                                    onEditClip: () {
                                      appState.chooseClip(clips[i]);
                                      Navigator.of(context).pushNamed(AppRoutes.editor);
                                    },
                                  ),
                                  if (i != clips.length - 1) const SizedBox(height: 20),
                                ],
                              ],
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState appState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          LuxIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 16,
            size: 32,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AI Clip Finder', style: LuxText.sora(size: 16, weight: FontWeight.w700)),
                if (appState.project != null)
                  Text(
                    appState.project!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LuxText.manrope(size: 11.5, weight: FontWeight.w500, color: LuxColors.textSecondary),
                  ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(LuxRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(LuxRadii.pill),
              onTap: appState.isGeneratingClips ? null : appState.generateClipSuggestions,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: LuxColors.surface,
                  border: Border.all(color: LuxColors.border),
                  borderRadius: BorderRadius.circular(LuxRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: LuxColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      appState.isGeneratingClips ? 'WORKING' : 'AI ACTIVE',
                      style: LuxText.manrope(size: 10, weight: FontWeight.w800, color: LuxColors.gold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasTranscript;
  final String? error;
  const _EmptyState({required this.hasTranscript, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasTranscript
                  ? 'No clips yet — pull to refresh once analysis finishes.'
                  : 'Run Analyse on a project first — the AI reads the transcript to find complete, engaging moments.',
              textAlign: TextAlign.center,
              style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center, style: LuxText.manrope(size: 12, color: LuxColors.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClipCard extends StatelessWidget {
  final AiClip clip;
  final bool featured;
  final VoidCallback onEditClip;

  const _ClipCard({required this.clip, required this.featured, required this.onEditClip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: LuxColors.surface,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: LuxColors.surfaceDashed,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.movie_creation_outlined,
                    size: featured ? 44 : 32,
                    color: LuxColors.borderStrong,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                      stops: const [0, 0.55],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _ScoreBadge(score: clip.viralScore, glow: featured),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (clip.category.isNotEmpty)
                        Text(
                          clip.category.toUpperCase(),
                          style: LuxText.manrope(
                            size: 10,
                            weight: FontWeight.w700,
                            color: LuxColors.gold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        clip.title.toUpperCase(),
                        maxLines: featured ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: LuxText.sora(
                          size: featured ? 26 : 18,
                          weight: FontWeight.w900,
                          color: LuxColors.textPrimary,
                          height: 0.95,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: LuxColors.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 11, color: LuxColors.textPrimary),
                            const SizedBox(width: 4),
                            Text(
                              clip.timeRangeLabel,
                              style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: LuxColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      if (featured)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(gradient: LuxColors.goldGradient, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded, size: 18, color: LuxColors.background),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (featured) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '"${clip.title}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LuxText.manrope(size: 14, weight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.more_vert_rounded, size: 18, color: LuxColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    clip.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LuxText.manrope(size: 11.5, weight: FontWeight.w500, color: LuxColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Text(
                    '"${clip.title}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LuxText.manrope(size: 13, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                ],
                _EditExportButton(featured: featured, onTap: onEditClip),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  final bool glow;
  const _ScoreBadge({required this.score, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: LuxColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: LuxColors.gold,
              shape: BoxShape.circle,
              boxShadow: glow ? const [BoxShadow(color: LuxColors.gold, blurRadius: 6)] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$score% VIRAL SCORE',
            style: LuxText.manrope(size: 10, weight: FontWeight.w900, color: LuxColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _EditExportButton extends StatelessWidget {
  final bool featured;
  final VoidCallback onTap;
  const _EditExportButton({required this.featured, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: featured ? null : LuxColors.surfaceRaised,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          gradient: featured ? LuxColors.goldGradient : null,
          borderRadius: BorderRadius.circular(12),
          border: featured ? null : Border.all(color: LuxColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit & Export',
                  style: LuxText.manrope(
                    size: 13,
                    weight: FontWeight.w700,
                    color: featured ? LuxColors.background : LuxColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: featured ? LuxColors.background : LuxColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
