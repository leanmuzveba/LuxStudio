import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/ai_clip.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../utils/error_presenter.dart';
import '../widgets/lux_icon_button.dart';

enum _Platform { reels, tiktok, shorts, story }

/// Screen 5 — Share. Matches `ui_kit/share/index.html`: a single-clip
/// flow — platform picker, one combined AI-generated caption blob (not
/// social_screen.dart's 4 structured fields), an Apply Branding toggle,
/// and Save/Share Now. Replaces both `social_screen.dart` and
/// `export_share_screen.dart`'s batch multi-clip list.
///
/// The platform picker is purely cosmetic — no per-platform export
/// variant exists (every export is the same 1080x1920 MP4 regardless of
/// which platform icon is selected), matching the mockup itself (a static
/// UI with no wired-up platform-specific behavior either).
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  _Platform _platform = _Platform.reels;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppStateScope.of(context);
      if (appState.selectedClip != null && appState.socialCopy == null) {
        appState.generateSocialCopy();
      }
    });
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caption copied.')));
  }

  /// "Save" and "Share Now" both export (if not already done) then open
  /// the platform share sheet — there's no separate download-to-disk API
  /// wired up, so for now they behave the same rather than one of them
  /// silently doing nothing.
  Future<void> _shareOrSave(BuildContext context, AppState appState, AiClip clip) async {
    if (appState.exportedDownloadPath == null) {
      await appState.exportSelectedClip();
    }
    final path = appState.exportedDownloadPath;
    if (path == null || !context.mounted) return;
    final bytes = await appState.downloadExport(path);
    if (!context.mounted) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: '${clip.title}.mp4', mimeType: 'video/mp4')],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
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

            var watermarkOn = false;
            for (final preset in appState.brandingPresets) {
              if (preset.id == 'watermark') {
                watermarkOn = preset.enabled;
                break;
              }
            }

            return Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      _PreviewFrame(clip: clip),
                      const SizedBox(height: 24),
                      Text(
                        'CHOOSE PLATFORM',
                        style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: LuxColors.gold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 84,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _PlatformTile(
                              icon: Icons.movie_creation_rounded,
                              label: 'Reels',
                              selected: _platform == _Platform.reels,
                              onTap: () => setState(() => _platform = _Platform.reels),
                            ),
                            const SizedBox(width: 10),
                            _PlatformTile(
                              icon: Icons.music_note_rounded,
                              label: 'TikTok',
                              selected: _platform == _Platform.tiktok,
                              onTap: () => setState(() => _platform = _Platform.tiktok),
                            ),
                            const SizedBox(width: 10),
                            _PlatformTile(
                              icon: Icons.smart_display_rounded,
                              label: 'Shorts',
                              selected: _platform == _Platform.shorts,
                              onTap: () => setState(() => _platform = _Platform.shorts),
                            ),
                            const SizedBox(width: 10),
                            _PlatformTile(
                              icon: Icons.auto_stories_rounded,
                              label: 'Story',
                              selected: _platform == _Platform.story,
                              onTap: () => setState(() => _platform = _Platform.story),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'AI GENERATED CAPTIONS',
                            style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: LuxColors.gold, letterSpacing: 1.5),
                          ),
                          GestureDetector(
                            onTap: appState.isGeneratingSocialCopy ? null : appState.generateSocialCopy,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'REGENERATE',
                                  style: LuxText.manrope(
                                    size: 10,
                                    weight: FontWeight.w700,
                                    color: LuxColors.textMutedAlt,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.refresh_rounded, size: 13, color: LuxColors.textMutedAlt),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CaptionCard(appState: appState, onCopy: _copy),
                      const SizedBox(height: 24),
                      _BrandingRow(
                        enabled: watermarkOn,
                        onChanged: () => appState.toggleBranding('watermark'),
                      ),
                    ],
                  ),
                ),
                _buildBottomBar(context, appState, clip),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
            child: Text('Share Clip', style: LuxText.sora(size: 17, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppState appState, AiClip clip) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final busy = appState.isExportingClip;

    return Container(
      decoration: const BoxDecoration(
        color: LuxColors.background,
        border: Border(top: BorderSide(color: LuxColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (appState.exportError != null) ...[
            Text(
              friendlyError(appState.exportError),
              textAlign: TextAlign.center,
              style: LuxText.manrope(size: 12, color: LuxColors.error),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _shareOrSave(context, appState, clip),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: LuxColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Save',
                    style: LuxText.manrope(size: 14, weight: FontWeight.w700, color: LuxColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: busy ? null : () => _shareOrSave(context, appState, clip),
                  style: FilledButton.styleFrom(
                    backgroundColor: LuxColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: LuxColors.background),
                        )
                      : Text(
                          'Share Now',
                          style: LuxText.manrope(size: 14, weight: FontWeight.w800, color: LuxColors.background),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  final AiClip clip;
  const _PreviewFrame({required this.clip});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 180,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              color: LuxColors.surfaceDashed,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: LuxColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (clip.category.isNotEmpty)
                        Text(
                          clip.category.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: LuxText.manrope(size: 9, weight: FontWeight.w700, color: LuxColors.gold, letterSpacing: 1.2),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        clip.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: LuxText.sora(size: 16, weight: FontWeight.w900, height: 1.05),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: 0.33,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation(LuxColors.gold),
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

class _PlatformTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformTile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? LuxColors.gold : Colors.transparent, width: 2),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: LuxColors.textPrimary),
              const SizedBox(height: 6),
              Text(
                label.toUpperCase(),
                style: LuxText.manrope(size: 9.5, weight: FontWeight.w700, color: LuxColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionCard extends StatelessWidget {
  final AppState appState;
  final void Function(BuildContext, String) onCopy;
  const _CaptionCard({required this.appState, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    if (appState.isGeneratingSocialCopy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: LuxColors.gold)),
      );
    }

    final copy = appState.socialCopy;
    if (copy == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LuxColors.surface,
          border: Border.all(color: LuxColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          appState.socialCopyError ?? 'Captions will appear here once generated.',
          style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: LuxColors.gold, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              copy.displayBlob,
              style: LuxText.manrope(size: 13.5, color: LuxColors.transcriptBody, height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          LuxIconButton(
            icon: Icons.copy_all_rounded,
            variant: LuxIconButtonVariant.subtle,
            size: 28,
            iconSize: 15,
            onPressed: () => onCopy(context, copy.displayBlob),
          ),
        ],
      ),
    );
  }
}

class _BrandingRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback onChanged;
  const _BrandingRow({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxColors.surface,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: LuxColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LuxColors.border),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.palette_outlined, size: 18, color: LuxColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Apply Branding', style: LuxText.manrope(size: 13.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'LUXSTUDIO PRESET V2',
                  style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: LuxColors.textMutedAlt, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (_) => onChanged(),
            activeThumbColor: LuxColors.background,
            activeTrackColor: LuxColors.gold,
            inactiveThumbColor: LuxColors.textMuted,
            inactiveTrackColor: LuxColors.surfaceRaised,
          ),
        ],
      ),
    );
  }
}
