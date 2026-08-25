import 'package:flutter/material.dart';

import '../main.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/timeline_strip.dart';
import '../widgets/transcript_list.dart';

/// Screen 2 — Video Editor.
///
/// Vertical preview pane up top, a 4-tab tool bar (Captions / Audio /
/// AI Cuts / Overlays) driving a swappable bottom panel, a scrubber
/// timeline showing audio chunks & silence gaps, and — in the Captions
/// tab — the full editable transcript.
class VideoEditorScreen extends StatelessWidget {
  const VideoEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.clips),
            child: const Text('Next: AI Clips'),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (appState.project == null) {
            return const Center(
              child: Text(
                'No project loaded yet — go import a video first.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return Column(
            children: [
              Expanded(child: _PreviewPane(appState: appState)),
              _buildTimelineArea(context, appState),
              _ToolBar(
                active: appState.activeTool,
                onSelect: appState.setActiveTool,
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineArea(BuildContext context, AppState appState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimelineStrip(
            segments: appState.transcript,
            totalDuration: appState.project!.processedDuration,
          ),
          const SizedBox(height: Gaps.sm),
          SizedBox(
            height: 260,
            child: _ToolPanel(appState: appState),
          ),
        ],
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  final AppState appState;

  const _PreviewPane({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
      child: Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF23212B), Color(0xFF14131A)],
                    ),
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white70),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      appState.project!.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  final EditorTool active;
  final ValueChanged<EditorTool> onSelect;

  const _ToolBar({required this.active, required this.onSelect});

  static const _items = [
    (EditorTool.captions, Icons.closed_caption_rounded, 'Captions'),
    (EditorTool.audio, Icons.graphic_eq_rounded, 'Audio'),
    (EditorTool.aiCuts, Icons.auto_awesome_rounded, 'AI Cuts'),
    (EditorTool.overlays, Icons.layers_rounded, 'Overlays'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: _items.map((item) {
          final (tool, icon, label) = item;
          final isActive = tool == active;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(tool),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isActive ? AppColors.accent : AppColors.textMuted,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ToolPanel extends StatelessWidget {
  final AppState appState;

  const _ToolPanel({required this.appState});

  @override
  Widget build(BuildContext context) {
    switch (appState.activeTool) {
      case EditorTool.captions:
        return TranscriptList(
          segments: appState.transcript,
          onEdit: (segment, text) => appState.updateTranscriptText(segment.id, text),
          onToggleCut: (segment) => appState.toggleMarkForCut(segment.id),
        );
      case EditorTool.audio:
        return const _AudioPanel();
      case EditorTool.aiCuts:
        return _AiCutsPanel(appState: appState);
      case EditorTool.overlays:
        return const _OverlaysPanel();
    }
  }
}

class _AudioPanel extends StatelessWidget {
  const _AudioPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
      children: const [
        _SliderRow(label: 'Voice level', value: 0.8),
        _SliderRow(label: 'Background music', value: 0.25),
        _SliderRow(label: 'Noise reduction', value: 0.6),
        SizedBox(height: Gaps.sm),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;

  const _SliderRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.surfaceRaised,
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(value: value, onChanged: (_) {}),
          ),
        ],
      ),
    );
  }
}

class _AiCutsPanel extends StatelessWidget {
  final AppState appState;

  const _AiCutsPanel({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.sm),
          child: Text(
            'The AI already scored every moment in this sermon. Review the '
            'full ranked list on the next screen.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
            child: GradientButton(
              label: 'View ${appState.suggestedClips.length} AI-suggested clips',
              icon: Icons.auto_awesome_rounded,
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.clips),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlaysPanel extends StatelessWidget {
  const _OverlaysPanel();

  @override
  Widget build(BuildContext context) {
    const overlays = [
      ('Lower third', Icons.text_fields_rounded),
      ('Logo watermark', Icons.workspace_premium_rounded),
      ('Verse reference', Icons.menu_book_rounded),
      ('Progress bar', Icons.linear_scale_rounded),
    ];

    return GridView.count(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
      crossAxisCount: 2,
      mainAxisSpacing: Gaps.sm,
      crossAxisSpacing: Gaps.sm,
      childAspectRatio: 2.4,
      children: overlays.map((o) {
        final (label, icon) = o;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
