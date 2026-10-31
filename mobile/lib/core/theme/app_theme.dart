import 'package:flutter/material.dart';

/// Theme tokens and palette matching the Resarc editorial research assistant aesthetic:
/// Vibrant coral accent (#FF5238), pristine off-white canvas (#FBFBFB),
/// crisp white cards (#FFFFFF) with delicate neutral borders (#E5E7EB),
/// deep obsidian dark mode, and jet black action buttons (#111827).
class AppTheme {
  static const seed = Color(0xFF111827);
  static const coral = Color(0xFFFF5238);
  static const coralDark = Color(0xFFE54028);
  static const coralSubtle = Color(0xFFFFF0ED);
  static const jetBlack = Color(0xFF111827);

  // Backwards-compatible aliases upgraded to the coral editorial palette
  static const canaryYellow = Color(0xFFFF5238);
  static const vividYellow = Color(0xFFFF6954);
  static const coralPink = Color(0xFFFF5238);

  static const deepDark = Color(0xFF101216);
  static const obsidian = Color(0xFF181A20);
  static const lightBg = Color(0xFFFBFBFB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE5E7EB);
  static const borderDark = Color(0xFF282C38);
  static const dotGrid = Color(0xFFE5E7EB);
  static const dotGridDark = Color(0xFF252936);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF111827),
      brightness: brightness,
      primary: isDark ? const Color(0xFFFF5238) : const Color(0xFF111827),
      onPrimary: isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF),
      primaryContainer: isDark ? const Color(0xFF2A2B30) : const Color(0xFFFFF0ED),
      onPrimaryContainer: isDark ? const Color(0xFFFF5238) : const Color(0xFFD6341B),
      secondary: const Color(0xFFFF5238),
      secondaryContainer: isDark ? const Color(0xFF282C38) : const Color(0xFFF4F5F8),
      onSecondaryContainer: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF111827),
      tertiary: const Color(0xFFFF5238),
      surface: isDark ? const Color(0xFF181A20) : const Color(0xFFFFFFFF),
      surfaceContainerLowest: isDark ? const Color(0xFF101216) : const Color(0xFFFBFBFB),
      surfaceContainerLow: isDark ? const Color(0xFF1C1F27) : const Color(0xFFF5F6F8),
      surfaceContainer: isDark ? const Color(0xFF222630) : const Color(0xFFEEF0F3),
      surfaceContainerHigh: isDark ? const Color(0xFF2A2E3A) : const Color(0xFFE5E7EB),
      outline: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
      outlineVariant: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFFBFBFB),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFFBFBFB),
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
            color: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFFFF5238) : const Color(0xFF111827),
          foregroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF),
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
          borderSide: BorderSide(color: isDark ? const Color(0xFFFF5238) : const Color(0xFF111827), width: 1.6),
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
          BorderSide(color: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB), width: 1),
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
        indicatorColor: isDark ? const Color(0xFF2A2E3A) : const Color(0xFFFFF0ED),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppTheme.coral, size: 24);
          }
          return IconThemeData(
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            size: 24,
          );
        }),
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
