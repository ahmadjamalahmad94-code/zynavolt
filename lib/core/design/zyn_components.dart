/// v100 — Zynavolt Design System (mobile) — base components.
///
/// Every screen rebuilt against the v100 system imports these widgets
/// instead of hand-rolling its own card / tile / chip / button. The
/// goal is "one component, used everywhere" so a single tweak to the
/// surface treatment cascades across the app.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'zyn_tokens.dart';

// ─── Card ──────────────────────────────────────────────────────────

/// Glossy gradient card surface. The default treatment for any
/// content panel — secondary panels, stat sections, list groups.
class ZynCard extends StatelessWidget {
  const ZynCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZynSpacing.lg),
    this.accent,
    this.radius = ZynRadii.xl,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: zynGlassCardDecoration(tint: accent, radius: radius),
      padding: padding,
      child: child,
    );
  }
}

// ─── Section header ────────────────────────────────────────────────

/// Tinted-square icon + bold label + gradient hairline divider.
/// Used to introduce a vertical group of cards or rows.
class ZynSectionHeader extends StatelessWidget {
  const ZynSectionHeader({
    super.key,
    required this.label,
    required this.icon,
    this.trailing,
    this.onDark = false,
  });

  final String label;
  final IconData icon;
  final Widget? trailing;

  /// True when rendered on a dark navy surface (the hero strip).
  /// Defaults to false — every non-Home page body uses the light
  /// lavender backdrop in v102b, so section headers render as
  /// dark text on a light surface by default.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = onDark ? Colors.white : ZynColors.ink;
    final iconColor = onDark
        ? Colors.white
        : ZynColors.primary700;
    final iconBg = onDark
        ? Colors.white.withValues(alpha: 0.12)
        : ZynColors.primary500.withValues(alpha: 0.10);
    final dividerStart = onDark
        ? Colors.white.withValues(alpha: 0.28)
        : ZynColors.line.withValues(alpha: 0.80);
    final dividerEnd = onDark
        ? Colors.white.withValues(alpha: 0.00)
        : ZynColors.line.withValues(alpha: 0.00);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZynSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(ZynRadii.tight),
              border: onDark
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                      width: 0.6,
                    )
                  : null,
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: ZynSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [dividerStart, dividerEnd],
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: ZynSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ─── Card header (used inside ZynCard) ─────────────────────────────

class ZynCardHeader extends StatelessWidget {
  const ZynCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? ZynColors.indigo;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tint.withValues(alpha: 0.18),
                tint.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(ZynRadii.inner),
            border: Border.all(
              color: tint.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Icon(icon, color: tint, size: 18),
        ),
        const SizedBox(width: ZynSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ZynText.heading,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: ZynText.caption.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: ZynSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

// ─── Stat tile ─────────────────────────────────────────────────────

/// Compact stat tile — accent gradient surface, filled gradient icon
/// glyph, label above value. Used inside cards for stat grids.
class ZynStatTile extends StatelessWidget {
  const ZynStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.muted = false,
    this.helperText,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final bool muted;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final effective = muted ? ZynColors.faintMuted : tone;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            effective.withValues(alpha: muted ? 0.04 : 0.10),
            effective.withValues(alpha: muted ? 0.02 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(ZynRadii.tile),
        border: Border.all(
          color: effective.withValues(alpha: muted ? 0.12 : 0.22),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: ZynGradients.iconFill(effective),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: effective,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (helperText != null)
                Text(
                  helperText!,
                  style: TextStyle(
                    color: effective.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Action tile ───────────────────────────────────────────────────

/// Tappable row with leading icon, label + subtitle, optional badge,
/// trailing chevron. Used for nav lists (Settings, More).
class ZynActionTile extends StatelessWidget {
  const ZynActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color tone;
  final VoidCallback onTap;

  /// Optional small pill rendered next to the title (e.g. "ويب", "جديد").
  final String? badge;

  /// Optional widget at the trailing edge (replaces the chevron).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        child: Ink(
          decoration: BoxDecoration(
            gradient: ZynGradients.glossSurface(tint: tone),
            borderRadius: BorderRadius.circular(ZynRadii.card),
            border: Border.all(color: ZynColors.line, width: 1),
            boxShadow: ZynShadows.gloss(tint: tone),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: ZynGradients.iconFill(tone),
                    borderRadius: BorderRadius.circular(ZynRadii.inner),
                    boxShadow: ZynShadows.iconGlow(tone),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: ZynColors.ink,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 7),
                            ZynBadge(text: badge!, tone: tone),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: ZynText.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                trailing ??
                    Icon(
                      Icons.chevron_left_rounded,
                      color: ZynColors.faintMuted.withValues(alpha: 0.75),
                      size: 22,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Chip ──────────────────────────────────────────────────────────

/// Small pill, icon + text. Use for status indicators on hero cards.
class ZynChip extends StatelessWidget {
  const ZynChip({
    super.key,
    required this.text,
    this.icon,
    this.onLight = true,
    this.tone,
  });

  final String text;
  final IconData? icon;

  /// `true` (default) when the chip sits on a light surface; `false`
  /// when on a dark hero. Adjusts colours accordingly.
  final bool onLight;

  /// Optional accent colour. When provided + `onLight`, the chip uses
  /// the tone as its fill + text colour. Ignored on dark surfaces.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    if (!onLight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(ZynRadii.pill),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 11),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }
    final accent = tone ?? ZynColors.indigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        border: Border.all(
          color: accent.withValues(alpha: 0.30),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: accent, size: 12),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Badge ─────────────────────────────────────────────────────────

class ZynBadge extends StatelessWidget {
  const ZynBadge({
    super.key,
    required this.text,
    required this.tone,
  });

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tone.withValues(alpha: 0.16),
            tone.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(ZynRadii.tight),
        border: Border.all(
          color: tone.withValues(alpha: 0.30),
          width: 0.6,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tone,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Button ────────────────────────────────────────────────────────

enum ZynButtonVariant { primary, secondary, danger }

class ZynButton extends StatelessWidget {
  const ZynButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.variant = ZynButtonVariant.primary,
    this.busy = false,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final ZynButtonVariant variant;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (List<Color> colors, Color glow) = switch (variant) {
      ZynButtonVariant.primary => (
        [ZynColors.indigoBright, ZynColors.indigo],
        ZynColors.indigo,
      ),
      ZynButtonVariant.secondary => (
        [Colors.white, Colors.white],
        ZynColors.indigo,
      ),
      ZynButtonVariant.danger => (
        [ZynColors.danger, const Color(0xFFB91C1C)],
        ZynColors.danger,
      ),
    };
    final isSecondary = variant == ZynButtonVariant.secondary;
    final foreground = isSecondary ? ZynColors.indigo : Colors.white;
    final disabled = onTap == null || busy;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.tile),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(ZynRadii.tile),
        child: Ink(
          width: expand ? double.infinity : null,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(ZynRadii.tile),
            border: isSecondary
                ? Border.all(color: ZynColors.line, width: 1)
                : null,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 13, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, color: foreground, size: 17),
                if ((busy || icon != null)) const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────

class ZynEmptyState extends StatelessWidget {
  const ZynEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.onDark = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  /// True when rendered on a dark navy surface. Defaults to false
  /// — v102b restores the light lavender page backdrop so empty
  /// states sit on a light surface.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final titleColor = onDark ? Colors.white : ZynColors.ink;
    final subtitleColor =
        onDark ? Colors.white.withValues(alpha: 0.72) : ZynColors.muted;
    final iconBg = onDark
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.14),
              Colors.white.withValues(alpha: 0.06),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
          );
    final iconBorder = onDark
        ? Colors.white.withValues(alpha: 0.24)
        : ZynColors.primary500.withValues(alpha: 0.18);
    final iconColor = onDark ? Colors.white : ZynColors.primary700;
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: ZynSpacing.xxxl, horizontal: ZynSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: iconBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: iconBorder, width: 1),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(height: ZynSpacing.md),
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.1,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: ZynSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

// ─── Page scaffold ─────────────────────────────────────────────────

/// Legacy page shell. Kept for older callers; new code prefers
/// [ZynScreen] + [ZynPageHero], which apply the v102 dark hero
/// pattern uniformly across every non-Home screen.
class ZynPage extends StatelessWidget {
  const ZynPage({
    super.key,
    required this.child,
    this.appBar,
    this.padding = const EdgeInsets.fromLTRB(
      ZynSpacing.lg, ZynSpacing.sm, ZynSpacing.lg, ZynSpacing.xxl,
    ),
    this.scrollable = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ZynColors.pageBackdrop),
        child: SafeArea(
          child: scrollable
              ? SingleChildScrollView(
                  padding: padding,
                  child: child,
                )
              : Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ─── Unified hero header (v102) ────────────────────────────────────

/// v102 — unified dark-navy hero header. Every non-Home screen
/// renders this strip at the top with the same height/colour/font.
///
/// Layout:
///   [back button | (trailing actions)]   ← 44 dp top row
///        Title (22 pt, white, bold)
///        Subtitle (12.5 pt, white@72 %, optional 2 lines)
///
/// When [showBackButton] is false (tabs), the row stays the same
/// height so every screen's hero ends at the same vertical offset.
class ZynPageHero extends StatelessWidget {
  const ZynPageHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBackButton = true,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool showBackButton;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    // v102c — Stack-based layout so the title + subtitle sit in
    // the visual middle of the hero strip while the back button
    // (and optional trailing action) overlay at the top edge.
    // Adds an `AnnotatedRegion` so the OS status-bar icons render
    // in light tone over the dark navy gradient, and a quiet
    // watermark (sun + solar panels + bolt) for energy identity.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: ZynColors.navyHero),
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: 112,
          child: Stack(
            children: [
              // Subtle energy watermark — sun, solar panels, bolt.
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: ZynHeroWatermark()),
                ),
              ),
              // Centred title + subtitle block.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZynSpacing.xxl,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Top action row — back on the start side (right in
              // RTL), trailing on the end side. Positioned so the
              // centred text underneath isn't pushed downward.
              Positioned(
                top: 6,
                left: ZynSpacing.md,
                right: ZynSpacing.md,
                child: Row(
                  children: [
                    if (showBackButton)
                      const _HeroBackButton()
                    else
                      const SizedBox(width: 36),
                    const Spacer(),
                    ?trailing,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// v102c — quiet "energy" watermark painted behind the hero text.
/// Sun disc + radial rays in one corner, tilted solar-panel strip
/// in the opposite corner, and a small lightning bolt. Painted at
/// low alpha so the title + subtitle always read clearly.
class ZynHeroWatermark extends CustomPainter {
  const ZynHeroWatermark();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sun + rays — top-leading corner (right in RTL, left in LTR;
    // we paint at a fixed canvas position since RTL flipping is
    // handled by the parent Directionality).
    final sunCx = w * 0.86;
    final sunCy = h * 0.42;
    final sunR = h * 0.22;

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(sunCx, sunCy), radius: sunR * 2.4),
      );
    canvas.drawCircle(Offset(sunCx, sunCy), sunR * 2.4, haloPaint);

    final sunPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09);
    canvas.drawCircle(Offset(sunCx, sunCy), sunR, sunPaint);

    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final start = Offset(
        sunCx + math.cos(angle) * sunR * 1.30,
        sunCy + math.sin(angle) * sunR * 1.30,
      );
      final end = Offset(
        sunCx + math.cos(angle) * sunR * 1.65,
        sunCy + math.sin(angle) * sunR * 1.65,
      );
      canvas.drawLine(start, end, rayPaint);
    }

    // Solar panel strip — bottom-trailing corner. A pair of tilted
    // rounded rectangles with cell grid lines.
    canvas.save();
    canvas.translate(w * 0.06, h * 0.62);
    canvas.transform(_skew(skewX: -0.32, skewY: 0.16).storage);

    final panelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06);
    final cellPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    final p1 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-6, -22, 90, 36),
      const Radius.circular(4),
    );
    canvas.drawRRect(p1, panelPaint);
    for (var i = 1; i < 4; i++) {
      final x = -6 + (90.0 * i / 4);
      canvas.drawLine(Offset(x, -22), Offset(x, 14), cellPaint);
    }
    canvas.drawLine(const Offset(-6, -4), const Offset(84, -4), cellPaint);

    final p2 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-16, 12, 96, 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(p2, panelPaint);
    for (var i = 1; i < 4; i++) {
      final x = -16 + (96.0 * i / 4);
      canvas.drawLine(Offset(x, 12), Offset(x, 46), cellPaint);
    }
    canvas.drawLine(const Offset(-16, 29), const Offset(80, 29), cellPaint);

    canvas.restore();

    // Lightning bolt — small accent between the sun and the
    // centred text.
    final boltPath = Path()
      ..moveTo(w * 0.40, h * 0.18)
      ..lineTo(w * 0.34, h * 0.50)
      ..lineTo(w * 0.40, h * 0.50)
      ..lineTo(w * 0.34, h * 0.82)
      ..lineTo(w * 0.44, h * 0.46)
      ..lineTo(w * 0.38, h * 0.46)
      ..close();
    final boltPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawPath(boltPath, boltPaint);
  }

  Matrix4 _skew({required double skewX, required double skewY}) {
    return Matrix4.identity()
      ..setEntry(0, 1, skewX)
      ..setEntry(1, 0, skewY);
  }

  @override
  bool shouldRepaint(covariant ZynHeroWatermark oldDelegate) => false;
}

class _HeroBackButton extends StatelessWidget {
  const _HeroBackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkResponse(
        onTap: () => Navigator.of(context).maybePop(),
        radius: 20,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// v102 — circular hero action button used in the trailing slot of
/// [ZynPageHero] for refresh / today / etc. Mirrors the back-button
/// style so AppBar-style actions on dark navy stay consistent.
class ZynHeroActionButton extends StatelessWidget {
  const ZynHeroActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkResponse(
        onTap: onPressed,
        radius: 20,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// v102 — unified screen scaffold. Renders the dark navy backdrop
/// (so short pages keep their bottom black), pins a [ZynPageHero]
/// at the top, and gives the body a scrollable area below.
///
/// Use everywhere except `/home` (which has its own bespoke hero
/// + navy gradient already) and the auth flow.
class ZynScreen extends StatelessWidget {
  const ZynScreen({
    super.key,
    required this.hero,
    required this.child,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(
      ZynSpacing.lg, ZynSpacing.md, ZynSpacing.lg, 110,
    ),
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.scrollController,
  });

  final ZynPageHero hero;
  final Widget child;
  final bool scrollable;

  /// Default bottom padding is 110 dp so the scroll body clears
  /// the floating bottom-nav bubble on tab screens (HomeShell uses
  /// `extendBody: true`, so the bar overlays whatever sits at the
  /// bottom of the body). Pushed screens see a bit of extra scroll
  /// space at the end, which is harmless.
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBody;

  /// Optional controller attached to the screen's inner scroll view
  /// (only used when [scrollable] is `true`). Pass when the host
  /// needs scroll-offset listeners (e.g. auto-mark-read in
  /// Notifications).
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    // v102b — light page backdrop returned. The dark navy hero
    // floats above a soft lavender backdrop (same as the rest of
    // the app), so short pages no longer leave a heavy dark band
    // below the content.
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: extendBody,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ZynColors.pageBackdrop),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            Expanded(
              child: scrollable
                  ? SingleChildScrollView(
                      controller: scrollController,
                      padding: padding,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: child,
                    )
                  : Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}
