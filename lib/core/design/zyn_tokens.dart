/// Zynavolt Mobile DS v1 — canonical design tokens.
///
/// Strict, unified system tuned for a Modern Mobile SaaS Energy
/// platform: calm primary, balanced lavender/white/pale-blue
/// surfaces, premium-but-quiet hero gradients, no neon.
///
/// Strict rules (enforced socially via code review):
///
///   1. **No magic numbers in screens.** Every dimension, colour,
///      shadow, radius, gradient comes from this file.
///   2. **No inline gradients/shadows.** Use [ZynGradients] and
///      [ZynShadows] only.
///   3. **No raw Material widgets** for cards/chips/buttons. Use
///      `lib/core/design/zyn_components.dart`.
///   4. **Almarai everywhere.** Configured in `app_theme.dart`.
///   5. **RTL by default.** All widgets assume RTL.
///   6. **Touch targets ≥ 44 dp.** Even pills carry vertical padding
///      to clear this.
///   7. **One focal point per screen.** The hero card is loudest;
///      nothing competes.
///   8. **Empty / loading / error states** ship with every screen.
///
/// Backward-compat note: a handful of pre-DS-v1 token names
/// (`indigo`, `indigoBright`, `softBg`, `softInk`, `faintMuted`,
/// `emerald`) are retained as aliases pointing at the new tokens
/// so screens not yet migrated keep building. Each alias is marked
/// `@Deprecated` and will be deleted after all screens land on the
/// v1 names. Do NOT use the deprecated aliases in new code.
library;

import 'package:flutter/material.dart';

/// Canonical palette. Owner-tuned in 2026-05-14 design review:
///
/// * `primary500` calmed from `#6D5DFC` → `#675CFF` (less neon).
/// * Background is balanced (lavender → pale blue → white) not
///   monochromatic purple.
/// * Hero gradients stay quiet — no glow, no blur effects.
class ZynColors {
  const ZynColors._();

  // ── Brand primary ────────────────────────────────────────────────
  static const Color primary500 = Color(0xFF675CFF); // links, badges, bubble
  static const Color primary700 = Color(0xFF4338CA); // emphasis, active states
  static const Color primary50 = Color(0xFFEEF2FF); // subtle accent bg

  // ── Surfaces ─────────────────────────────────────────────────────
  static const Color bg = Color(0xFFF5F3FB); // page bg — lavender mist
  static const Color surface = Color(0xFFFFFFFF); // cards
  static const Color surfaceAlt = Color(0xFFFAFAFE); // subtle inset surfaces

  // ── Text ─────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF0F172A); // primary text
  static const Color inkSoft = Color(0xFF334155); // sub-headings, body emph
  static const Color muted = Color(0xFF64748B); // labels, helpers
  static const Color faint = Color(0xFF94A3B8); // captions, disabled

  // ── Lines ────────────────────────────────────────────────────────
  static const Color line = Color(0xFFE5E7EB); // default card borders
  static const Color lineSoft = Color(0xFFEEF0F4); // inner dividers

  // ── Semantic ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSoft = Color(0xFFDBEAFE);

  // ── Accent — used SPARINGLY for AI / smart-suggestion moments ───
  static const Color accent = Color(0xFFA78BFA);
  static const Color accentSoft = Color(0xFFEDE9FE);

  // ── Dark navy — Battery Lab + dark hero variant ─────────────────
  static const Color navy900 = Color(0xFF0E1A2E);
  static const Color navy800 = Color(0xFF152340);
  static const Color navy700 = Color(0xFF1B2C4A);

  // ── Page backdrop — owner-tuned: balanced (white + soft lavender
  //    + pale blue), NOT all-purple. Reads as a quiet gradient on
  //    real devices instead of a candy wash.
  static const LinearGradient pageBackdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF5F3FB), // lavender mist top — only ~5% off white
      Color(0xFFF7F9FC), // pale blue middle
      Color(0xFFFFFFFF), // white bottom for tab-bar/FAB clarity
    ],
    stops: [0.0, 0.55, 1.0],
  );

  // ── Hero gradients ──────────────────────────────────────────────
  //
  // "Premium calm" per the owner's brief — no neon, no glow, no
  // crypto-dashboard flashiness. Each is a single eased blend with
  // muted endpoints; the artwork on top of these stays subtle so
  // the focal point remains the data.

  /// Dark navy hero — Battery Lab style. Used for the Battery Lab
  /// hero card and any other "deep" surface.
  static const LinearGradient navyHero = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy700, navy800, navy900],
    stops: [0.0, 0.55, 1.0],
  );

  /// Sky hero — Weather "current conditions" card. Calmer than the
  /// reference image's saturated blue: starts from a soft blue-grey
  /// to avoid the candy-UI feel.
  static const LinearGradient skyHero = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF8AA1FF), // soft cool blue
      Color(0xFF5B6BFF), // calm primary blue
    ],
  );

  /// Brand hero — used for primary CTAs that take the full hero
  /// treatment. Rare; reserved for once-per-screen focal points.
  static const LinearGradient brandHero = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [primary500, primary700],
  );

  // ──────────────────────────────────────────────────────────────────
  // BACKWARD-COMPAT ALIASES (do not use in new code)
  // ──────────────────────────────────────────────────────────────────

  @Deprecated('Use ZynColors.primary700')
  static const Color indigo = primary700;
  @Deprecated('Use ZynColors.primary500')
  static const Color indigoBright = primary500;
  @Deprecated('Use ZynColors.primary50')
  static const Color indigoSoft = primary50;
  @Deprecated('Use ZynColors.primary700')
  static const Color indigoDeep = Color(0xFF3730A3);
  @Deprecated('Use ZynColors.bg')
  static const Color softBg = bg;
  @Deprecated('Use ZynColors.inkSoft')
  static const Color softInk = inkSoft;
  @Deprecated('Use ZynColors.muted')
  static const Color faintMuted = muted;
  @Deprecated('Use ZynColors.success')
  static const Color emerald = success;
  static const Color cyan = Color(0xFF06B6D4);
  static const Color violet = accent;

  @Deprecated('Use ZynColors.navyHero')
  static const LinearGradient heroGradient = navyHero;
}

/// 4-pt spacing scale. Modern SaaS leans generous; do not invent
/// off-grid values like 5 / 11 / 13 / 17 / 23.
class ZynSpacing {
  const ZynSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}

/// Corner radii.
///
/// `pill` is full-round; `card` is the default for content panels;
/// `tile` for sub-cards (stat tiles); `inner` for inputs and small
/// chips; `tight` for badges; `xl` / `hero` for the focal hero card.
class ZynRadii {
  const ZynRadii._();

  static const double pill = 999;
  static const double hero = 28;
  static const double xl = 22;
  static const double card = 16;
  static const double tile = 14;
  static const double inner = 12;
  static const double tight = 8;
}

/// Shadow stacks. Two intentional tiers + a hero/glow.
///
/// "Premium calm" per the owner's brief — modest blur radii, low
/// alpha. The violet tint keeps shadows aligned with the brand
/// palette instead of a generic neutral grey.
class ZynShadows {
  const ZynShadows._();

  /// Subtle elevation — default for cards on the page background.
  static List<BoxShadow> soft({Color? tint}) {
    final base = tint ?? ZynColors.primary500;
    return [
      BoxShadow(
        color: base.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Medium elevation — for hero cards on the page, stat summary
  /// rows, anything that should clearly float above the bg.
  static List<BoxShadow> med({Color? tint}) {
    final base = tint ?? ZynColors.primary500;
    return [
      BoxShadow(
        color: base.withValues(alpha: 0.10),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Hero — for the single focal card per screen. Slightly stronger
  /// violet tint to anchor the visual hierarchy.
  static List<BoxShadow> hero({Color? tint}) {
    final base = tint ?? ZynColors.primary700;
    return [
      BoxShadow(
        color: base.withValues(alpha: 0.18),
        blurRadius: 32,
        offset: const Offset(0, 16),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Used by deep navy cards (Battery Lab). Darker shadow so the
  /// card "punches" against the lighter page bg.
  static List<BoxShadow> navy() {
    return [
      BoxShadow(
        color: ZynColors.navy900.withValues(alpha: 0.32),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: ZynColors.navy700.withValues(alpha: 0.22),
        blurRadius: 28,
        offset: const Offset(0, 14),
      ),
    ];
  }

  /// Tight glow for filled icon glyph tiles.
  static List<BoxShadow> iconGlow(Color tint) {
    return [
      BoxShadow(
        color: tint.withValues(alpha: 0.30),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ];
  }

  // ── Backward-compat aliases (do not use in new code) ────────────
  @Deprecated('Use ZynShadows.med')
  static List<BoxShadow> gloss({Color? tint}) => med(tint: tint);
}

/// Gradient builders.
class ZynGradients {
  const ZynGradients._();

  /// White → tinted-accent gradient for the "glass card" treatment.
  /// Default tint is brand primary; pass another for accent surfaces.
  static LinearGradient glossSurface({
    Color? tint,
    double tintAlpha = 0.05,
  }) {
    final base = tint ?? ZynColors.primary500;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white,
        base.withValues(alpha: tintAlpha),
      ],
    );
  }

  /// Filled gradient for icon glyph tiles. Pair with
  /// [ZynShadows.iconGlow].
  static LinearGradient iconFill(Color tint) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        tint,
        tint.withValues(alpha: 0.78),
      ],
    );
  }

  /// Tinted soft gradient for accent stat tiles (background fill,
  /// low alpha so text on top is still readable).
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

/// Typography scale. Almarai-only. Configured in app_theme.dart so
/// every TextStyle in the app inherits the family automatically;
/// these tokens only set size / weight / colour.
class ZynText {
  const ZynText._();

  /// Hero numbers (e.g. SoC 89.0%, temperature 29.1°).
  static const TextStyle display = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -0.6,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ZynColors.ink,
  );

  /// Page titles ("الطقس", "الإشعارات", "المزيد").
  static const TextStyle pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.3,
    color: ZynColors.ink,
  );

  /// Section headings inside scrolls ("تنبيهات حرجة", "اقتراحات ذكية").
  static const TextStyle section = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.2,
    color: ZynColors.ink,
  );

  /// Card titles ("تحليل ما قبل الغروب").
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.1,
    color: ZynColors.ink,
  );

  /// Stat values (compact, in-card numbers).
  static const TextStyle stat = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ZynColors.ink,
  );

  /// Body copy.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: ZynColors.inkSoft,
  );

  /// Body emphasis — for short labels next to a stronger value.
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: ZynColors.ink,
  );

  /// Helper / caption text.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: ZynColors.muted,
  );

  /// Subtle eyebrow / chip text.
  static const TextStyle micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.2,
    color: ZynColors.muted,
  );

  // ── Backward-compat aliases (do not use in new code) ────────────
  @Deprecated('Use ZynText.pageTitle')
  static const TextStyle title = pageTitle;
  @Deprecated('Use ZynText.cardTitle')
  static const TextStyle heading = cardTitle;
}

/// Helper: glass card decoration (white → faint tint, line border,
/// soft shadow). Use [ZynCard] in `zyn_components.dart` instead of
/// reaching for this directly.
BoxDecoration zynGlassCardDecoration({
  Color? tint,
  double radius = ZynRadii.card,
  double tintAlpha = 0.05,
}) {
  return BoxDecoration(
    gradient: ZynGradients.glossSurface(tint: tint, tintAlpha: tintAlpha),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: ZynColors.line, width: 1),
    boxShadow: ZynShadows.soft(tint: tint),
  );
}

/// Helper: dark hero outer shell decoration (shadow only — gradient
/// goes inside via `ClipRRect`).
BoxDecoration zynNavyHeroDecoration({double radius = ZynRadii.hero}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    boxShadow: ZynShadows.navy(),
  );
}

/// Backward-compat alias for the previous symbol name.
@Deprecated('Use zynNavyHeroDecoration')
BoxDecoration zynHeroOuterDecoration({double radius = ZynRadii.xl}) {
  return zynNavyHeroDecoration(radius: radius);
}
