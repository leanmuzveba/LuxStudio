import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the LuxStudio UI (gold/dark "premium studio" look),
/// extracted from the "LuxStudio App Mockups" design artifact.
class LuxColors {
  LuxColors._();

  static const background = Color(0xFF1A141A);
  static const surface = Color(0xFF241D22);
  static const surfaceRaised = Color(0xFF2E262B);
  static const surfaceDashed = Color(0xFF1F181D);
  static const border = Color(0xFF322A2F);
  static const borderStrong = Color(0xFF3A2F35);
  static const borderDashed = Color(0xFF4A3E44);
  static const divider = Color(0xFF2A2226);
  static const bottomNavBg = Color(0xFF1D1619);
  static const playerSurface = Color(0xFF0F0C0F);

  static const textPrimary = Color(0xFFF5EFE6);
  static const textSecondary = Color(0xFF8C7C74);
  static const textMuted = Color(0xFF5A4C52);
  static const textMutedAlt = Color(0xFF7A6C64);
  static const iconSubtle = Color(0xFFB7A79C);
  static const transcriptBody = Color(0xFFE9DFD3);

  static const gold = Color(0xFFF4B315);
  static const amber = Color(0xFFE59312);
  static const tan = Color(0xFFD3AF85);
  static const bronze = Color(0xFF8E5915);
  static const slate = Color(0xFF423738);
  static const success = Color(0xFF6FBF73);
  static const error = Color(0xFFFF5C5C);

  static const avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, bronze],
  );
}

class LuxRadii {
  LuxRadii._();
  static const card = 16.0;
  static const dashedCard = 18.0;
  static const button = 14.0;
  static const iconButton = 12.0;
  static const pill = 100.0;
}

class LuxSpacing {
  LuxSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
}

/// Sora (display/headings) + Manrope (body/UI) via Google Fonts, matching
/// the mockup exactly — fetched once and cached by the package, same
/// network assumption the app already makes for Gemini.
class LuxText {
  LuxText._();

  static TextStyle sora({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color color = LuxColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle manrope({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = LuxColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
}

class LuxTheme {
  LuxTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: LuxColors.textPrimary,
      displayColor: LuxColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: LuxColors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: LuxColors.gold,
        secondary: LuxColors.amber,
        surface: LuxColors.surface,
        error: LuxColors.error,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: LuxColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: LuxColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: LuxColors.textPrimary),
      ),
      cardColor: LuxColors.surface,
      dividerColor: LuxColors.divider,
      splashFactory: InkRipple.splashFactory,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LuxColors.surfaceRaised,
        contentTextStyle: LuxText.manrope(size: 13.5, color: LuxColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
