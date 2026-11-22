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

  // Semantic role accents
  static const seminalAmber = Color(0xFFF59E0B);
  static const seminalAmberDark = Color(0xFFD97706);
  static const openAccessEmerald = Color(0xFF10B981);
  static const aiViolet = Color(0xFF8B5CF6);
  static const audioIndigo = Color(0xFF6366F1);
  static const danger = Color(0xFFEF4444);

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
      extensions: [isDark ? AthenaColors.dark : AthenaColors.light],
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

/// Comprehensive semantic token extension powering Athena's editorial design system.
@immutable
class AthenaColors extends ThemeExtension<AthenaColors> {
  const AthenaColors({
    required this.canvas,
    required this.surfaceLowest,
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.coral,
    required this.coralSubtle,
    required this.seminalAmber,
    required this.openAccessEmerald,
    required this.aiViolet,
    required this.audioIndigo,
    required this.danger,
  });

  final Color canvas;
  final Color surfaceLowest;
  final Color surfaceBase;
  final Color surfaceRaised;
  final Color borderSubtle;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color coral;
  final Color coralSubtle;
  final Color seminalAmber;
  final Color openAccessEmerald;
  final Color aiViolet;
  final Color audioIndigo;
  final Color danger;

  static const light = AthenaColors(
    canvas: Color(0xFFFBFBFB),
    surfaceLowest: Color(0xFFF3F4F6),
    surfaceBase: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    borderSubtle: Color(0xFFE5E7EB),
    borderStrong: Color(0xFFD1D5DB),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    coral: Color(0xFFFF5238),
    coralSubtle: Color(0xFFFFF0ED),
    seminalAmber: Color(0xFFD97706),
    openAccessEmerald: Color(0xFF059669),
    aiViolet: Color(0xFF7C3AED),
    audioIndigo: Color(0xFF4F46E5),
    danger: Color(0xFFDC2626),
  );

  static const dark = AthenaColors(
    canvas: Color(0xFF0D0F14),
    surfaceLowest: Color(0xFF12151D),
    surfaceBase: Color(0xFF171B26),
    surfaceRaised: Color(0xFF1F2433),
    borderSubtle: Color(0xFF232938),
    borderStrong: Color(0xFF333C52),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    coral: Color(0xFFFF5238),
    coralSubtle: Color(0xFF2A1614),
    seminalAmber: Color(0xFFF59E0B),
    openAccessEmerald: Color(0xFF10B981),
    aiViolet: Color(0xFFA78BFA),
    audioIndigo: Color(0xFF818CF8),
    danger: Color(0xFFEF4444),
  );

  @override
  AthenaColors copyWith({
    Color? canvas,
    Color? surfaceLowest,
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? borderSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? coral,
    Color? coralSubtle,
    Color? seminalAmber,
    Color? openAccessEmerald,
    Color? aiViolet,
    Color? audioIndigo,
    Color? danger,
  }) {
    return AthenaColors(
      canvas: canvas ?? this.canvas,
      surfaceLowest: surfaceLowest ?? this.surfaceLowest,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      coral: coral ?? this.coral,
      coralSubtle: coralSubtle ?? this.coralSubtle,
      seminalAmber: seminalAmber ?? this.seminalAmber,
      openAccessEmerald: openAccessEmerald ?? this.openAccessEmerald,
      aiViolet: aiViolet ?? this.aiViolet,
      audioIndigo: audioIndigo ?? this.audioIndigo,
      danger: danger ?? this.danger,
    );
  }

  @override
  AthenaColors lerp(ThemeExtension<AthenaColors>? other, double t) {
    if (other is! AthenaColors) return this;
    return AthenaColors(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      surfaceLowest: Color.lerp(surfaceLowest, other.surfaceLowest, t) ?? surfaceLowest,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t) ?? surfaceBase,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t) ?? surfaceRaised,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      coral: Color.lerp(coral, other.coral, t) ?? coral,
      coralSubtle: Color.lerp(coralSubtle, other.coralSubtle, t) ?? coralSubtle,
      seminalAmber: Color.lerp(seminalAmber, other.seminalAmber, t) ?? seminalAmber,
      openAccessEmerald: Color.lerp(openAccessEmerald, other.openAccessEmerald, t) ?? openAccessEmerald,
      aiViolet: Color.lerp(aiViolet, other.aiViolet, t) ?? aiViolet,
      audioIndigo: Color.lerp(audioIndigo, other.audioIndigo, t) ?? audioIndigo,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
    );
  }
}

/// Convenience extension on BuildContext to quickly access Athena design tokens.
extension AthenaThemeX on BuildContext {
  AthenaColors get athenaColors =>
      Theme.of(this).extension<AthenaColors>() ??
      (Theme.of(this).brightness == Brightness.dark ? AthenaColors.dark : AthenaColors.light);
}

/// Reading surface themes for long-form paper reading.
enum ReaderThemeMode {
  light,
  sepia,
  slate,
  obsidian,
}

/// Color tokens tailored specifically for comfortable, fatigue-free long-form reading.
class ReaderTheme {
  const ReaderTheme({
    required this.background,
    required this.text,
    required this.border,
    required this.muted,
  });

  final Color background;
  final Color text;
  final Color border;
  final Color muted;

  static const light = ReaderTheme(
    background: Color(0xFFFBFBFB),
    text: Color(0xFF111827),
    border: Color(0xFFE5E7EB),
    muted: Color(0xFF6B7280),
  );

  static const sepia = ReaderTheme(
    background: Color(0xFFF4ECD8),
    text: Color(0xFF382C1E),
    border: Color(0xFFE2D6BC),
    muted: Color(0xFF7D6B56),
  );

  static const slate = ReaderTheme(
    background: Color(0xFF1E2430),
    text: Color(0xFFE2E8F0),
    border: Color(0xFF2E384D),
    muted: Color(0xFF94A3B8),
  );

  static const obsidian = ReaderTheme(
    background: Color(0xFF0D0F14),
    text: Color(0xFFF1F5F9),
    border: Color(0xFF1E2330),
    muted: Color(0xFF64748B),
  );

  static ReaderTheme of(ReaderThemeMode mode) {
    switch (mode) {
      case ReaderThemeMode.light:
        return light;
      case ReaderThemeMode.sepia:
        return sepia;
      case ReaderThemeMode.slate:
        return slate;
      case ReaderThemeMode.obsidian:
        return obsidian;
    }
  }
}
