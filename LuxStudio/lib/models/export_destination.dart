import 'package:flutter/material.dart';

/// A social destination the user can export a finished clip to.
enum ExportPlatform { reels, tiktok, shorts, story }

class ExportDestination {
  final ExportPlatform platform;
  final String label;
  final IconData icon;
  final String aspectHint;

  const ExportDestination({
    required this.platform,
    required this.label,
    required this.icon,
    required this.aspectHint,
  });

  static const List<ExportDestination> all = [
    ExportDestination(
      platform: ExportPlatform.reels,
      label: 'Reels',
      icon: Icons.camera_alt_rounded,
      aspectHint: '9:16 · Instagram',
    ),
    ExportDestination(
      platform: ExportPlatform.tiktok,
      label: 'TikTok',
      icon: Icons.music_note_rounded,
      aspectHint: '9:16 · TikTok',
    ),
    ExportDestination(
      platform: ExportPlatform.shorts,
      label: 'Shorts',
      icon: Icons.play_arrow_rounded,
      aspectHint: '9:16 · YouTube',
    ),
    ExportDestination(
      platform: ExportPlatform.story,
      label: 'Story',
      icon: Icons.auto_stories_rounded,
      aspectHint: '9:16 · Story',
    ),
  ];
}

/// A branding toggle applied at export time (watermark, lower third, etc).
class BrandingPreset {
  final String id;
  final String label;
  final String description;
  bool enabled;

  BrandingPreset({
    required this.id,
    required this.label,
    required this.description,
    this.enabled = false,
  });
}
