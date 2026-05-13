/// v100 — Zynavolt Design System (mobile) — base components.
///
/// Every screen rebuilt against the v100 system imports these widgets
/// instead of hand-rolling its own card / tile / chip / button. The
/// goal is "one component, used everywhere" so a single tweak to the
/// surface treatment cascades across the app.
library;

import 'package:flutter/material.dart';

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
  });

  final String label;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZynSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZynColors.indigo.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ZynRadii.tight),
            ),
            child: Icon(icon, color: ZynColors.indigo, size: 13),
          ),
          const SizedBox(width: ZynSpacing.sm),
          Text(
            label,
            style: ZynText.heading.copyWith(fontSize: 13.5),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ZynColors.line.withValues(alpha: 0.80),
                    ZynColors.line.withValues(alpha: 0.00),
                  ],
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEEF2FF),
                  Color(0xFFE0E7FF),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: ZynColors.indigo.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Icon(icon, color: ZynColors.indigo, size: 30),
          ),
          const SizedBox(height: ZynSpacing.md),
          Text(
            title,
            style: ZynText.heading.copyWith(fontSize: 14.5),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: ZynText.caption,
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

/// Full-page scaffold with the soft-bg gradient backdrop + SafeArea.
/// Use as the root of any screen so backgrounds match across the app.
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
