import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Color scheme data
// ---------------------------------------------------------------------------

class _ColorScheme {
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color ring;

  const _ColorScheme({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
  });
}

const _darkScheme = _ColorScheme(
  background: Color(0xFF23202A),
  foreground: Color(0xFFFAFAFA),
  card: Color(0xFF282530),
  cardForeground: Color(0xFFFAFAFA),
  primary: Color(0xFF4D4099),
  primaryForeground: Color(0xFFFFFFFF),
  secondary: Color(0xFF37333E),
  secondaryForeground: Color(0xFFFAFAFA),
  muted: Color(0xFF37333E),
  mutedForeground: Color(0xFFA3A1A8),
  accent: Color(0xFF66B2FF),
  accentForeground: Color(0xFF23202A),
  destructive: Color(0xFFEF4444),
  destructiveForeground: Color(0xFFFAFAFA),
  border: Color(0xFF37333E),
  input: Color(0xFF37333E),
  ring: Color(0xFF66B2FF),
);

const _lightScheme = _ColorScheme(
  background: Color(0xFFF6F5F9),
  foreground: Color(0xFF1A1820),
  card: Color(0xFFFFFFFF),
  cardForeground: Color(0xFF1A1820),
  primary: Color(0xFF4D4099),
  primaryForeground: Color(0xFFFFFFFF),
  secondary: Color(0xFFECEBF0),
  secondaryForeground: Color(0xFF1A1820),
  muted: Color(0xFFECEBF0),
  mutedForeground: Color(0xFF6B6975),
  accent: Color(0xFF3B82F6),
  accentForeground: Color(0xFFFFFFFF),
  destructive: Color(0xFFDC2626),
  destructiveForeground: Color(0xFFFFFFFF),
  border: Color(0xFFD8D6DE),
  input: Color(0xFFECEBF0),
  ring: Color(0xFF3B82F6),
);

// ---------------------------------------------------------------------------
// AppColors — static proxy to current scheme
// ---------------------------------------------------------------------------

class AppColors {
  static _ColorScheme _scheme = _darkScheme;

  static bool get isDark => _scheme == _darkScheme;
  static void setDark() => _scheme = _darkScheme;
  static void setLight() => _scheme = _lightScheme;
  static void apply({required bool dark}) =>
      _scheme = dark ? _darkScheme : _lightScheme;

  static Color get background => _scheme.background;
  static Color get foreground => _scheme.foreground;
  static Color get card => _scheme.card;
  static Color get cardForeground => _scheme.cardForeground;
  static Color get primary => _scheme.primary;
  static Color get primaryForeground => _scheme.primaryForeground;
  static Color get secondary => _scheme.secondary;
  static Color get secondaryForeground => _scheme.secondaryForeground;
  static Color get muted => _scheme.muted;
  static Color get mutedForeground => _scheme.mutedForeground;
  static Color get accent => _scheme.accent;
  static Color get accentForeground => _scheme.accentForeground;
  static Color get destructive => _scheme.destructive;
  static Color get destructiveForeground => _scheme.destructiveForeground;
  static Color get border => _scheme.border;
  static Color get input => _scheme.input;
  static Color get ring => _scheme.ring;
}

class AppTheme {
  static const double borderRadius = 12.0;

  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? [const Color(0x194D4099), const Color(0x80222026)]
        : [const Color(0x0D4D4099), const Color(0x0DFAF9FC)],
  );

  static BoxShadow get accentGlow => BoxShadow(
    color: AppColors.accent.withValues(alpha: 0.15),
    blurRadius: 20,
    spreadRadius: 0,
  );

  // Shared builder — avoids duplicating the full ThemeData
  static ThemeData _build({required bool dark}) {
    final base = dark ? ThemeData.dark() : ThemeData.light();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light())
          .copyWith(
            surface: AppColors.background,
            onSurface: AppColors.foreground,
            primary: AppColors.primary,
            onPrimary: AppColors.primaryForeground,
            secondary: AppColors.secondary,
            onSecondary: AppColors.secondaryForeground,
            error: AppColors.destructive,
            onError: AppColors.destructiveForeground,
            outline: AppColors.border,
          ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: dark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background.withValues(alpha: 0.5),
        foregroundColor: AppColors.foreground,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.foreground,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.mutedForeground),
        hintStyle: TextStyle(color: AppColors.mutedForeground),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.foreground,
        displayColor: AppColors.foreground,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border.withValues(alpha: 0.5),
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme => _build(dark: true);
  static ThemeData get lightTheme => _build(dark: false);
}
