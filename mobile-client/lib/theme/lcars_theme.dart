import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta clássica LCARS (Star Trek: TNG / Voyager) sobre fundo preto absoluto.
abstract final class LcarsColors {
  static const Color background = Color(0xFF000000);
  static const Color amber = Color(0xFFFF9900);
  static const Color peach = Color(0xFFFFAA66);
  static const Color lavender = Color(0xFFCC99CC);
  static const Color skyBlue = Color(0xFF9999FF);
  static const Color gold = Color(0xFFFFCC66);
  static const Color redAlert = Color(0xFFCC6666);
  static const Color offlineGrey = Color(0xFF3A3A44);
  static const Color textDark = Color(0xFF000000);
  static const Color textLight = Color(0xFFFFE5B4);

  static Color fromToken(String? token) {
    return switch (token) {
      'amber' => amber,
      'peach' => peach,
      'lavender' => lavender,
      'cyan' || 'sky_blue' => skyBlue,
      'gold' => gold,
      'red_alert' => redAlert,
      _ => amber,
    };
  }
}

ThemeData buildLcarsTheme() {
  final base = ThemeData.dark();
  final condensed = GoogleFonts.antonioTextTheme(base.textTheme).apply(
    bodyColor: LcarsColors.textLight,
    displayColor: LcarsColors.amber,
  );

  return base.copyWith(
    scaffoldBackgroundColor: LcarsColors.background,
    colorScheme: const ColorScheme.dark(
      surface: LcarsColors.background,
      primary: LcarsColors.amber,
      secondary: LcarsColors.lavender,
      tertiary: LcarsColors.skyBlue,
      error: LcarsColors.redAlert,
    ),
    textTheme: condensed.copyWith(
      headlineMedium: condensed.headlineMedium?.copyWith(
        color: LcarsColors.amber,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
      ),
      titleMedium: condensed.titleMedium?.copyWith(
        color: LcarsColors.textLight,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
      bodyMedium: condensed.bodyMedium?.copyWith(
        color: LcarsColors.textLight,
        letterSpacing: 1.1,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(color: LcarsColors.lavender, fontSize: 13),
      hintStyle: TextStyle(color: LcarsColors.textLight.withValues(alpha: 0.55)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LcarsColors.amber, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LcarsColors.skyBlue, width: 2),
      ),
    ),
  );
}
