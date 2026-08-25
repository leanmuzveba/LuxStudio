import 'package:flutter/material.dart';

/// Central design tokens for LuxStudio.
///
/// The product is a dark, editing-suite-style surface (think: a
/// professional tool, not a playful consumer app) with a single warm
/// accent gradient used sparingly for calls-to-action and the "viral
/// score" badge.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B0B10);
  static const Color surface = Color(0xFF16161D);
  static const Color surfaceRaised = Color(0xFF1F1F29);
  static const Color surfaceSunken = Color(0xFF0E0E13);
  static const Color border = Color(0xFF2A2A35);

  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA0A0AD);
  static const Color textMuted = Color(0xFF6B6B78);

  static const Color accentStart = Color(0xFFFF5B7F);
  static const Color accentEnd = Color(0xFF7B5CFF);
  static const Color accent = Color(0xFF7B5CFF);

  static const Color success = Color(0xFF3DDC97);
  static const Color warning = Color(0xFFFFB84D);
  static const Color waveform = Color(0xFF4D8CFF);
  static const Color silenceGap = Color(0xFF2A2A35);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentStart, accentEnd],
  );

  /// Score-dependent gradient for the "viral score" badge: hotter colors
  /// for higher-scoring clips.
  static LinearGradient scoreGradient(int score) {
    if (score >= 90) {
      return const LinearGradient(
        colors: [Color(0xFFFF5B7F), Color(0xFFFF8A5B)],
      );
    }
    if (score >= 75) {
      return const LinearGradient(
        colors: [Color(0xFFFFB84D), Color(0xFFFF8A5B)],
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF4D8CFF), Color(0xFF7B5CFF)],
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.accent,
        secondary: AppColors.accentStart,
        surface: AppColors.surface,
        error: const Color(0xFFFF5C5C),
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            headlineSmall: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
            titleMedium: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            labelSmall: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      splashFactory: InkRipple.splashFactory,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.surfaceRaised,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Shared spacing scale so every screen breathes the same way.
class Gaps {
  Gaps._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
