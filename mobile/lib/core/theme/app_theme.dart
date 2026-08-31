import 'package:flutter/material.dart';

/// Theme tokens and palette matching the Listenly AI UI Kit:
/// Deep obsidian darks, clean crisp surfaces, canary yellow highlight accents (#FEEA66 / #FFE600),
/// salmon pink smart markers (#FF7675), and smooth rounded pill components.
class AppTheme {
  static const seed = Color(0xFF141416);
  static const canaryYellow = Color(0xFFFEEA66);
  static const vividYellow = Color(0xFFFFE600);
  static const coralPink = Color(0xFFFF7675);
  static const deepDark = Color(0xFF121214);
  static const obsidian = Color(0xFF18181B);
  static const lightBg = Color(0xFFF7F8FA);
  static const lightSurface = Color(0xFFFFFFFF);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF141416),
      brightness: brightness,
      primary: isDark ? const Color(0xFFFEEA66) : const Color(0xFF121214),
      onPrimary: isDark ? const Color(0xFF121214) : const Color(0xFFFFFFFF),
      primaryContainer: isDark ? const Color(0xFF2A2B30) : const Color(0xFFFEEA66),
      onPrimaryContainer: isDark ? const Color(0xFFFEEA66) : const Color(0xFF121214),
      secondary: const Color(0xFFFFE600),
      secondaryContainer: isDark ? const Color(0xFF33353D) : const Color(0xFFF4F5F8),
      onSecondaryContainer: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF18181B),
      tertiary: const Color(0xFFFF7675),
      surface: isDark ? const Color(0xFF181A20) : const Color(0xFFFFFFFF),
      surfaceContainerLowest: isDark ? const Color(0xFF101216) : const Color(0xFFF8F9FA),
      surfaceContainerLow: isDark ? const Color(0xFF1C1F27) : const Color(0xFFF3F4F6),
      surfaceContainer: isDark ? const Color(0xFF222630) : const Color(0xFFEDEEF2),
      surfaceContainerHigh: isDark ? const Color(0xFF2A2E3A) : const Color(0xFFE5E7EB),
      outline: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
      outlineVariant: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF8F9FB),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF8F9FB),
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: themeText(brightness).titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1C1F27) : const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.65),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFFFEEA66) : const Color(0xFF121214),
          foregroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFFFFFFF),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: themeText(brightness).labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                fontSize: 15,
              ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          side: BorderSide(color: scheme.outlineVariant, width: 1.2),
          foregroundColor: isDark ? const Color(0xFFF3F4F6) : const Color(0xFF18181B),
          textStyle: themeText(brightness).labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: isDark ? const Color(0xFFFEEA66) : const Color(0xFF121214), width: 1.6),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1F27) : const Color(0xFFFFFFFF),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(
          isDark ? const Color(0xFF1C1F27) : const Color(0xFFFFFFFF),
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7), width: 1),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        constraints: const BoxConstraints(minHeight: 50),
        textStyle: WidgetStatePropertyAll(
          themeText(brightness).bodyMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        hintStyle: WidgetStatePropertyAll(
          themeText(brightness).bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 15,
              ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          textStyle: WidgetStatePropertyAll(
            themeText(brightness).labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF121418) : const Color(0xFFFFFFFF),
        indicatorColor: isDark ? const Color(0xFF2A2E3A) : const Color(0xFFFEEA66),
        labelTextStyle: WidgetStatePropertyAll(
          themeText(brightness).labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }

  /// Material defaults differ per brightness; resolve the matching TextTheme.
  static TextTheme themeText(Brightness brightness) =>
      brightness == Brightness.dark
          ? Typography.material2021().white
          : Typography.material2021().black;
}
