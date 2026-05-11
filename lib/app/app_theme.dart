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
  static const Color softBg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color indigoPrimary = Color(0xFF4338CA);
  static const Color indigoBright = Color(0xFF6366F1);
  static const Color indigoSoft = Color(0xFFEEF2FF);
  static const Color violet = Color(0xFF7C3AED);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);

  // ── Radii (v35 §8.4) ─────────────────────────────────────────────────
  static const double radiusInput = 10;
  static const double radiusCard = 12;
  static const double radiusHero = 14;
  static const double radiusGlass = 16;

  // ── Sizing (v35 §4.1) ────────────────────────────────────────────────
  /// Standard form control height — 42 dp mirrors the 42 px web rule.
  static const double formControlHeight = 42;

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
      // v46: Arabic typography slot. Cairo / Tajawal is the intended brand
      // family but no font asset is bundled yet — falling back to Roboto
      // keeps the UI rendering on every device today.
      //
      // To wire it up later, drop the .ttf files under
      //   assets/branding/fonts/Cairo/
      // then declare a `fonts:` section in pubspec.yaml pointing at them,
      // and change this line to `fontFamily: 'Cairo'`. No code elsewhere
      // depends on this — all text styles inherit through the theme.
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
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
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: indigoPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: indigoSoft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: muted, size: 22),
        ),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
