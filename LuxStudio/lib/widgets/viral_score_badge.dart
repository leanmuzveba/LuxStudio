import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The "98% Viral Score" pill shown on each AI-suggested clip.
class ViralScoreBadge extends StatelessWidget {
  final int score;
  final bool compact;

  const ViralScoreBadge({super.key, required this.score, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.scoreGradient(score),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.scoreGradient(score).colors.first.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: compact ? 12 : 14, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '$score% Viral',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11 : 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
