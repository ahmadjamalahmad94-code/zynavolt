// Zynavolt Mobile DS v1 — Material 3 theme glue.
//
// All visual tokens live in `lib/core/design/zyn_tokens.dart`.
// This file's only job is to translate those tokens into a
// `ThemeData` that Material widgets consume.
//
// Strict rule: do not introduce ad-hoc colours or sizes here.
// Every value either comes from `ZynColors` / `ZynSpacing` /
// `ZynRadii` / `ZynText`, or is a documented Material control
// metric (e.g. minimum touch target).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/design/zyn_tokens.dart';

/// Backward-compatibility shim. Pre-DS-v1 screens import
/// `AppTheme.indigoPrimary`, `AppTheme.softBg`, etc. We keep those
/// symbol names here as aliases over [ZynColors] so existing files
/// continue to build while screens migrate one by one. Add no NEW
/// symbols here — new code reaches for [ZynColors] directly.
class AppTheme {
  const AppTheme._();

  // ── Aliases over the canonical palette ──────────────────────────
  static const Color ink = ZynColors.ink;
  static const Color softInk = ZynColors.inkSoft;
  static const Color muted = ZynColors.muted;
  static const Color faintMuted = ZynColors.faint;
  static const Color line = ZynColors.line;
  static const Color softBg = ZynColors.bg;
  static const Color surface = ZynColors.surface;
  static const Color indigoPrimary = ZynColors.primary700;
  static const Color indigoBright = ZynColors.primary500;
  static const Color indigoSoft = ZynColors.primary50;
  static const Color violet = ZynColors.accent;
  static const Color success = ZynColors.success;
  static const Color warning = ZynColors.warning;
  static const Color danger = ZynColors.danger;
  static const Color cyan = ZynColors.cyan;
  static const Color emerald = ZynColors.success;
  static const Color amber = ZynColors.warning;

  // ── Aliases over geometry ───────────────────────────────────────
  static const double radiusInput = ZynRadii.inner;
  static const double radiusCard = ZynRadii.card;
  static const double radiusHero = ZynRadii.xl;
  static const double radiusGlass = ZynRadii.xl;
  static const double formControlHeight = 42;

  static const double space2 = 2;
  static const double space4 = ZynSpacing.xs;
  static const double space6 = 6;
  static const double space8 = ZynSpacing.sm;
  static const double space10 = 10;
  static const double space12 = ZynSpacing.md;
  static const double space14 = 14;
  static const double space16 = ZynSpacing.lg;
  static const double space20 = ZynSpacing.xl;
  static const double space24 = ZynSpacing.xxl;
  static const double space32 = ZynSpacing.xxxl;

  // ── Aliases over shadows / gradients ────────────────────────────
  static List<BoxShadow> get softShadow => ZynShadows.soft();
  static List<BoxShadow> get liftedShadow => ZynShadows.med();
  static List<BoxShadow> glossShadow({Color? tint}) =>
      ZynShadows.med(tint: tint);
  static LinearGradient glossSurface({
    Color? tint,
    double tintAlpha = 0.05,
  }) =>
      ZynGradients.glossSurface(tint: tint, tintAlpha: tintAlpha);

  static const LinearGradient brandGradient = ZynColors.brandHero;
  static const LinearGradient pageBackdropGradient = ZynColors.pageBackdrop;

  static Color get glassSurface => Colors.white.withValues(alpha: 0.96);
  static Color get glassBorder => ZynColors.line;

  // ── Theme builder ────────────────────────────────────────────────
  //
  // Almarai is the canonical typeface for the entire app. Wired via
  // `google_fonts` so we don't have to ship .ttf files in the bundle
  // (the package fetches and caches on first launch). After all
  // existing screens migrate to ZynText / ZynComponents we can
  // optionally bundle Almarai locally and drop the dependency.
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: ZynColors.primary700,
      onPrimary: Colors.white,
      secondary: ZynColors.accent,
      onSecondary: Colors.white,
      surface: ZynColors.surface,
      onSurface: ZynColors.ink,
      error: ZynColors.danger,
      onError: Colors.white,
      outline: ZynColors.line,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ZynColors.bg,
    );

    final almaraiText = GoogleFonts.almaraiTextTheme(
      base.textTheme.apply(bodyColor: ZynColors.ink, displayColor: ZynColors.ink),
    );
    final almaraiPrimaryText =
        GoogleFonts.almaraiTextTheme(base.primaryTextTheme);

    return base.copyWith(
      textTheme: almaraiText.copyWith(
        bodySmall: almaraiText.bodySmall?.copyWith(
          color: ZynColors.faint,
          fontSize: 12,
        ),
        labelSmall: almaraiText.labelSmall?.copyWith(
          color: ZynColors.muted,
          fontSize: 12,
        ),
      ),
      primaryTextTheme: almaraiPrimaryText,
      appBarTheme: AppBarTheme(
        backgroundColor: ZynColors.surface,
        foregroundColor: ZynColors.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.almarai(
          color: ZynColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: ZynColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZynRadii.card),
          side: const BorderSide(color: ZynColors.line, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZynColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZynSpacing.md,
          vertical: ZynSpacing.sm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZynRadii.inner),
          borderSide: const BorderSide(color: ZynColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZynRadii.inner),
          borderSide: const BorderSide(color: ZynColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZynRadii.inner),
          borderSide: const BorderSide(color: ZynColors.primary500, width: 2),
        ),
        labelStyle: GoogleFonts.almarai(
          color: ZynColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: GoogleFonts.almarai(
          color: ZynColors.faint,
          fontSize: 12,
        ),
        errorStyle: GoogleFonts.almarai(
          color: ZynColors.danger,
          fontSize: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ZynColors.primary700,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZynRadii.inner),
          ),
          textStyle: GoogleFonts.almarai(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZynColors.primary700,
          textStyle: GoogleFonts.almarai(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ZynColors.surface,
        indicatorColor: ZynColors.primary500,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.almarai(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            color: selected ? ZynColors.primary700 : ZynColors.ink,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Colors.white : ZynColors.muted,
            size: 22,
          );
        }),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: ZynColors.surface,
        shadowColor: ZynColors.primary500.withValues(alpha: 0.18),
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(
        color: ZynColors.line,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
