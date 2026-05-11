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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color borderColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
