import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Soft, calm card surface — the mobile analogue of the web `.ns-card`
/// pattern from v35 §2.3. Default radius/padding mirrors the form-step card
/// (12 dp), with optional overrides for hero or tile contexts.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = AppTheme.radiusCard,
    this.borderColor = AppTheme.line,
    this.background = AppTheme.surface,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color borderColor;
  final Color background;

  /// v58: when true, the card adopts the [AppTheme.softShadow] elevation
  /// for hero / featured surfaces. Default `false` preserves the flat
  /// look of every existing screen so older callers don't accidentally
  /// pick up a new visual treatment.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      // v74: clip child contents to the rounded border so InkWell
      // ripples and any nested Material splashes respect the card's
      // shape — important on small screens where children can flush
      // against the card edge.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: elevated ? AppTheme.softShadow : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
