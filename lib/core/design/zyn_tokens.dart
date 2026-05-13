/// v100 — Zynavolt Design System (mobile).
///
/// Single source of truth for every visual decision in the app.
/// Mirrors the design language we landed on in v99d (glossy gradient
/// surfaces, layered shadows, tinted-accent icon tiles, dark navy hero)
/// and gathers the loose tokens into one place so all screens speak
/// the same vocabulary.
///
/// Design principles (synthesised from a survey of top-rated SaaS
/// mobile apps — Linear, Stripe, Mercury, Cash App, Revolut, Tesla,
/// Notion):
///
///   1. **Surface hierarchy** — page → card → tile. Each level has its
///      own surface treatment (background → glossy gradient white →
///      accent-tinted tile) and shadow profile. No flat squares.
///   2. **Limited palette, strategic accent** — a single brand colour
///      (indigo) with semantic accents (success/warning/danger/cyan/
///      violet) used only to signal state, not decoration.
///   3. **Strong typography hierarchy** — 5 sizes, 3 weights. Numbers
///      are always tabular figures. Arabic uses Alexandria.
///   4. **Generous, predictable spacing** — 4-pt grid: xs/sm/md/lg/xl.
///   5. **3-D depth without skeuomorphism** — multi-layer shadows +
///      gradient fills + thin inner-edge highlights, not bevels.
///   6. **Touch targets ≥ 44 pt** — every tappable surface, even pills.
///   7. **One focal point per screen** — the hero card is the
///      strongest visual on the page; nothing else competes.
///   8. **Empty / loading / error states** — every screen ships all
///      three, no silent blank surfaces.
library;

import 'package:flutter/material.dart';

/// Core colour palette. The brand is indigo; semantic colours have a
/// consistent saturation so they sit comfortably next to each other
/// in stat tiles without competing.
class ZynColors {
  const ZynColors._();

  // ── Text & surfaces ──────────────────────────────────────────────
  static const Color ink = Color(0xFF0F172A);
  static const Color softInk = Color(0xFF1E293B);
  static const Color muted = Color(0xFF475569);
  static const Color faintMuted = Color(0xFF64748B);
  static const Color line = Color(0xFFCBD5E1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color softBg = Color(0xFFF8FAFC);

  // ── Brand (indigo) ───────────────────────────────────────────────
  static const Color indigo = Color(0xFF4338CA);
  static const Color indigoBright = Color(0xFF6366F1);
  static const Color indigoSoft = Color(0xFFEEF2FF);
  static const Color indigoDeep = Color(0xFF3730A3);

  // ── Semantic accents ─────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color violet = Color(0xFF7C3AED);
  static const Color emerald = Color(0xFF10B981);

  // ── Dark hero palette ────────────────────────────────────────────
  static const Color navy900 = Color(0xFF0E1A2E);
  static const Color navy800 = Color(0xFF152340);
  static const Color navy700 = Color(0xFF1B2C4A);

  // ── Page background gradient ────────────────────────────────────
  static const LinearGradient pageBackdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE0E7FF),
      Color(0xFFF1F5FF),
      Color(0xFFF8FAFC),
    ],
    stops: [0.0, 0.35, 0.85],
  );

  // ── Hero (dark navy) gradient ───────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy700, navy800, navy900],
    stops: [0.0, 0.55, 1.0],
  );
}

/// Spacing scale (4-pt base). Used everywhere — padding, gaps, margins.
class ZynSpacing {
  const ZynSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii. Pill is full-round, card is the default "rounded box",
/// tile is for smaller inner surfaces, tight is for chips / inputs.
class ZynRadii {
  const ZynRadii._();

  static const double pill = 999;
  static const double xl = 22;
  static const double card = 18;
  static const double tile = 14;
  static const double inner = 11;
  static const double tight = 8;
}

/// Shadow stacks. Each stack is a list of `BoxShadow` you can spread
/// onto a `Container.decoration`. All shadows tint with the supplied
/// accent so cards keep their colour identity even on shadow.
class ZynShadows {
  const ZynShadows._();

  /// Soft, low-emphasis card surface. Used for secondary panels.
  static List<BoxShadow> soft({Color? tint}) {
    final base = tint ?? ZynColors.indigo;
    return [
      BoxShadow(
        color: base.withValues(alpha: 0.06),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Glossy / lifted card surface. Used for primary panels +
  /// the redesigned Home / More / Battery Lab cards.
  static List<BoxShadow> gloss({Color? tint}) {
    final base = tint ?? ZynColors.indigo;
    return [
      BoxShadow(
        color: base.withValues(alpha: 0.10),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
      BoxShadow(
        color: base.withValues(alpha: 0.18),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];
  }

  /// Dark hero shadow stack. Used by hero / dark-gradient cards.
  static List<BoxShadow> hero() {
    return [
      BoxShadow(
        color: ZynColors.navy900.withValues(alpha: 0.32),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: ZynColors.navy700.withValues(alpha: 0.22),
        blurRadius: 36,
        offset: const Offset(0, 18),
      ),
    ];
  }

  /// Small inner-glow style accent shadow used for filled gradient
  /// icon tiles ("filled glyph" pattern). Returns a stack appropriate
  /// for a 30–42 px icon tile.
  static List<BoxShadow> iconGlow(Color tint) {
    return [
      BoxShadow(
        color: tint.withValues(alpha: 0.40),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

/// Gradient builders for surfaces.
class ZynGradients {
  const ZynGradients._();

  /// White → tinted-accent gradient for the "glass card" treatment.
  static LinearGradient glossSurface({Color? tint, double tintAlpha = 0.06}) {
    final base = tint ?? ZynColors.indigo;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white,
        base.withValues(alpha: tintAlpha),
      ],
    );
  }

  /// Filled gradient for icon glyph tiles. Use with `ZynShadows.iconGlow`.
  static LinearGradient iconFill(Color tint) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        tint,
        tint.withValues(alpha: 0.75),
      ],
    );
  }

  /// Tinted soft gradient for accent stat tiles (background fill, low
  /// alpha so text on top is still readable).
  static LinearGradient accentSurface(Color tint) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        tint.withValues(alpha: 0.10),
        tint.withValues(alpha: 0.04),
      ],
    );
  }
}

/// Typography. All sizes derived from a 4-pt vertical grid (with
/// half-steps allowed for body / caption). Defaults to weight 700/900
/// to render boldly inside Alexandria; w400/600 are reserved for body
/// copy where readability matters more than impact.
class ZynText {
  const ZynText._();

  /// Hero numbers (e.g. SoC 89.0%).
  static const TextStyle display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -1.0,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ZynColors.ink,
  );

  /// Big stat numbers inside cards.
  static const TextStyle stat = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -0.4,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ZynColors.ink,
  );

  /// Page / hero greeting titles.
  static const TextStyle title = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w900,
    height: 1.2,
    letterSpacing: -0.2,
    color: ZynColors.ink,
  );

  /// Card headings.
  static const TextStyle heading = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    height: 1.25,
    letterSpacing: -0.1,
    color: ZynColors.ink,
  );

  /// Body copy.
  static const TextStyle body = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    height: 1.45,
    color: ZynColors.softInk,
  );

  /// Captions (labels above values, helper text).
  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: ZynColors.faintMuted,
  );

  /// Tiny eyebrow / chip text.
  static const TextStyle micro = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w900,
    height: 1.3,
    letterSpacing: 0.2,
    color: ZynColors.faintMuted,
  );
}

/// Helper to combine a base [BoxDecoration] with the design system's
/// glass-card treatment.
BoxDecoration zynGlassCardDecoration({
  Color? tint,
  double radius = ZynRadii.card,
  double tintAlpha = 0.06,
}) {
  return BoxDecoration(
    gradient: ZynGradients.glossSurface(tint: tint, tintAlpha: tintAlpha),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: ZynColors.line, width: 1),
    boxShadow: ZynShadows.gloss(tint: tint),
  );
}

/// Helper for the dark hero card decoration. Caller is expected to
/// `ClipRRect` around it because the gradient + radial bloom overflow
/// the corners.
BoxDecoration zynHeroOuterDecoration({double radius = ZynRadii.xl}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    boxShadow: ZynShadows.hero(),
  );
}
