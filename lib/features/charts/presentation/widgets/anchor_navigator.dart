import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../data/energy_chart_models.dart';

/// RTL-aware date navigator. Renders as:  [‹ previous]  [date label]  [next ›]
///
/// The buttons are wired to logical "previous period" and "next period"
/// actions — the parent decides what one step means for the active
/// scope (day → ±1 day, month → ±1 month). Forward navigation is
/// disabled when the resulting anchor would fall in the future so the
/// user can never query a period the backend has no data for.
class ChartAnchorNavigator extends StatelessWidget {
  const ChartAnchorNavigator({
    super.key,
    required this.scope,
    required this.anchor,
    required this.onPrevious,
    required this.onNext,
    required this.onTapAnchor,
    required this.canGoForward,
  });

  final ChartScope scope;
  final DateTime anchor;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTapAnchor;
  final bool canGoForward;

  @override
  Widget build(BuildContext context) {
    // v99d — arrow icons flipped so each chevron points OUTWARD
    // (away from the centred date label). In RTL contexts, Material
    // sometimes mirrors `chevron_right`/`chevron_left`; we side-step
    // that by anchoring the icons to the BUTTON POSITION rather than
    // to a semantic "previous/next" direction. The right-positioned
    // button uses `chevron_left` (which, after RTL flip, renders as
    // an outward-right arrow), and vice-versa for the left button.
    return Row(
      children: [
        _NavButton(
          icon: Icons.chevron_left, // visually OUTWARD on the right side
          enabled: true,
          onTap: onPrevious,
          tooltip: scope == ChartScope.month ? 'الشهر السابق' : 'اليوم السابق',
        ),
        Expanded(
          child: GestureDetector(
            onTap: onTapAnchor,
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatAnchor(),
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'اضغط لاختيار تاريخ',
                    style: TextStyle(
                      color: AppTheme.faintMuted.withValues(alpha: 0.85),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _NavButton(
          icon: Icons.chevron_right, // visually OUTWARD on the left side
          enabled: canGoForward,
          onTap: canGoForward ? onNext : null,
          tooltip: scope == ChartScope.month ? 'الشهر التالي' : 'اليوم التالي',
        ),
      ],
    );
  }

  String _formatAnchor() {
    final y = anchor.year.toString().padLeft(4, '0');
    final m = anchor.month.toString().padLeft(2, '0');
    final d = anchor.day.toString().padLeft(2, '0');
    if (scope == ChartScope.month) return '$y-$m';
    return '$y-$m-$d';
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? tooltip : '',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled
                  ? Colors.white
                  : AppTheme.softBg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: enabled
                    ? AppTheme.line
                    : AppTheme.line.withValues(alpha: 0.5),
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppTheme.indigoPrimary
                            .withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? AppTheme.indigoPrimary
                  : AppTheme.faintMuted.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
