import 'package:flutter/material.dart';

/// SolarDeye theme tokens.
///
/// Distilled from `docs/design/v35_solardeye_ui_ux_consistency_system.md` in
/// the backend repo. Mobile does not redesign — it consumes the same palette
/// and converts concepts, not pixels.
class AppTheme {
  const AppTheme._();

  // ── Palette (v35 §8.1) ───────────────────────────────────────────────
  static const Color ink = Color(0xFF0F172A); // primary text
  static const Color softInk = Color(0xFF1E293B);
  static const Color muted = Color(0xFF475569);
  static const Color faintMuted = Color(0xFF64748B);
  static const Color line = Color(0xFFCBD5E1);
  // v83: cooler page background — subtle indigo tint instead of flat near-
  // white. Every screen picks this up via scaffoldBackgroundColor.
  static const Color softBg = Color(0xFFF1F5FF);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color indigoPrimary = Color(0xFF4338CA);
  static const Color indigoBright = Color(0xFF6366F1);
  static const Color indigoSoft = Color(0xFFEEF2FF);
  static const Color violet = Color(0xFF7C3AED);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);

  // v83: accent palette — used sparingly for visual variety on chips,
  // category tags, and small status pills. The core stays indigo/violet.
  static const Color cyan = Color(0xFF06B6D4);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B); // alias of warning

  // ── Radii (v35 §8.4) ─────────────────────────────────────────────────
  static const double radiusInput = 10;
  // v83: softer card corner (12 → 14) for a more premium / glassy feel.
  // Every AppCard in the app picks this up; pre-existing screens look
  // marginally rounder without behavior changes.
  static const double radiusCard = 14;
  static const double radiusHero = 16;
  static const double radiusGlass = 18;

  // ── Sizing (v35 §4.1) ────────────────────────────────────────────────
  /// Standard form control height — 42 dp mirrors the 42 px web rule.
  static const double formControlHeight = 42;

  // ── v58 design-system tokens ─────────────────────────────────────────
  //
  // Additive only. Every existing token above is unchanged so screens
  // already in production keep working. The tokens below let new and
  // refreshed screens (v58→v80) share one consistent visual language
  // instead of each screen re-inventing spacing / shadow / gradient
  // constants inline.

  // Spacing scale — 4 dp grid. Use these instead of magic numbers in
  // SizedBox / EdgeInsets where possible.
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space14 = 14;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;

  // Soft shadows for elevated cards / hero surfaces. Indigo-tinted so
  // they harmonise with the brand instead of looking like a generic grey
  // drop-shadow. v83: bumped intensity so depth is actually visible on
  // a real device.
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: indigoPrimary.withValues(alpha: 0.08),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> liftedShadow = [
    BoxShadow(
      color: indigoPrimary.withValues(alpha: 0.14),
      blurRadius: 26,
      offset: const Offset(0, 10),
    ),
  ];

  // Brand gradients. The full-saturation `brandGradient` is for hero /
  // accent surfaces; the pale variant matches Home/Splash backdrop.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [indigoPrimary, indigoBright],
  );

  static const LinearGradient pageBackdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE0E7FF),
      Color(0xFFF1F5FF),
      Color(0xFFF8FAFC),
    ],
    stops: [0.0, 0.35, 0.85],
  );

  // Glass surface — semi-transparent white over the page backdrop, with
  // a subtle border. For cards that sit on top of the gradient backdrop.
  static Color get glassSurface => Colors.white.withValues(alpha: 0.96);
  static Color get glassBorder => line;

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: indigoPrimary,
      onPrimary: Colors.white,
      secondary: violet,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: ink,
      error: danger,
      onError: Colors.white,
      outline: line,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: softBg,
      // v95: Arabic typography wired. All nine Alexandria weight .ttf
      // files live under `assets/fonts/` (Thin … Black) and are declared
      // in `pubspec.yaml` under `flutter.fonts`. Every Text widget in the
      // app now renders in Alexandria — no per-widget change needed.
      // Flutter resolves any `FontWeight.wXXX` request straight to the
      // matching cut.
      fontFamily: 'Alexandria',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
        // v82: bumped to 19, tightened letterSpacing for richer feel
        // across all screens. Arabic still renders cleanly; the spacing
        // only really shows on Latin tokens (Zynavolt, units).
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: line, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: indigoBright, width: 2),
        ),
        labelStyle: const TextStyle(
          color: muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: const TextStyle(
          color: faintMuted,
          fontSize: 12,
        ),
        errorStyle: const TextStyle(
          color: danger,
          fontSize: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: indigoPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(formControlHeight + 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInput),
          ),
          // v82: softened from w800 → w700, added letterSpacing for a
          // more refined CTA feel without sacrificing readability.
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: indigoPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        // v84: stronger indicator pill — full-saturation indigo accent
        // instead of the pale wash that was easy to miss on a real device.
        indicatorColor: indigoBright,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            color: selected ? indigoPrimary : ink,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Colors.white : muted,
            size: 22,
          );
        }),
        // v84: a touch taller — gives the indicator pill more breathing
        // room and the icons more weight on a real device.
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        // v84: stronger separation between body and bottom nav. Bumps
        // the tonal contrast on screens where the gradient backdrop sits
        // right above the nav.
        surfaceTintColor: surface,
        shadowColor: indigoPrimary.withValues(alpha: 0.18),
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            bodySmall: const TextStyle(color: faintMuted, fontSize: 12),
            labelSmall: const TextStyle(color: muted, fontSize: 12),
          ),
    );
  }
}
