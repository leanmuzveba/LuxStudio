import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the LuxStudio UI, extracted from the church-branded
/// `ui_kit/` reference (dark/gold, Inter, Phosphor icons) that replaced the
/// earlier "LuxStudio App Mockups" artifact this theme originally matched.
class LuxColors {
  LuxColors._();

  static const background = Color(0xFF1A1A1A);

  /// Approximates the mockup's glass-card recipe (`rgba(51,50,55,0.8)` +
  /// 12px backdrop blur) as an opaque fill — a real blur-behind effect is
  /// deferred to a later pass; this keeps every screen's cards/nav/sheets
  /// readable and correctly toned without `BackdropFilter` everywhere.
  static const surface = Color(0xFF333237);
  static const surfaceRaised = Color(0xFF3D3C42);
  static const surfaceDashed = Color(0xFF252525);

  static const border = Color(0x4D6C4D15); // glass-border, rgba(108,77,21,.3)
  static const borderStrong = Color(0xFF6C4D15); // icon-muted
  static const borderDashed = Color(0x4D6C4D15);
  static const divider = Color(0xFF333237);
  static const bottomNavBg = Color(0xF0333237);
  static const playerSurface = Color(0xFF000000);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFD4B48C);
  static const textMuted = Color(0xFF6C4D15);
  static const textMutedAlt = Color(0x66D4B48C); // rgba(212,180,140,.4)
  static const iconSubtle = Color(0xFFD4B48C);
  static const transcriptBody = Color(0xFFD4B48C);

  static const gold = Color(0xFFF4A823);
  static const gold2 = Color(0xFFF5AE1F);
  static const amber = Color(0xFFF5AE1F);
  static const tan = Color(0xFFD4B48C);
  static const bronze = Color(0xFF8E5915);
  static const slate = Color(0xFF333237);
  static const success = Color(0xFF6FBF73);
  static const error = Color(0xFFFF5C5C);

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, gold2],
  );

  static const avatarGradient = goldGradient;
}

class LuxRadii {
  LuxRadii._();
  static const card = 20.0;
  static const dashedCard = 24.0;
  static const button = 16.0;
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

/// [sora]/[manrope] now both render Inter (the ui_kit's one font family,
/// 400-900 weights) — kept as two named methods rather than renamed, since
/// dozens of call sites across every screen use them and a rename is out
/// of scope for a token-only pass; each screen's own reskin phase can
/// simplify to a single method as it's rewritten anyway.
class LuxText {
  LuxText._();

  static TextStyle sora({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color color = LuxColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.inter(
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
      GoogleFonts.inter(
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
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
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
        titleTextStyle: GoogleFonts.inter(
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
