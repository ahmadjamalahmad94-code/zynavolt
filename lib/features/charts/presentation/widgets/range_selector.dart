import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../data/energy_chart_models.dart';

/// Premium scope chips for the chart card (يوم / شهر / سنة / الإجمالي).
///
/// v77 art-direction polish — the selector now sits on a soft neutral
/// strip rather than a saturated indigo tray, so the active chip
/// (pale violet fill, dark violet text) reads as the only accent and
/// the row stops competing with the chart itself. Unsupported scopes
/// (year + total) render disabled honestly.
class ChartRangeSelector extends StatelessWidget {
  const ChartRangeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ChartScope value;
  final ValueChanged<ChartScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        // Calm neutral strip — sits quietly under the title row and
        // lets the active chip pop without saturating the whole row.
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          for (final s in ChartScope.values)
            Expanded(
              child: _RangeChip(
                scope: s,
                selected: s == value,
                onTap: s.isSupported ? () => onChanged(s) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.scope,
    required this.selected,
    required this.onTap,
  });

  final ChartScope scope;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    // Active: pale violet/indigo fill with darker violet text, soft
    // shadow — matches the addendum exactly.
    // Inactive: transparent, muted text, no border (the host strip
    // already carries the line).
    // Disabled: faded muted text, no surface — reads as "exists but
    // unavailable" without being noisy.
    final Color fg;
    final Color bg;
    final List<BoxShadow> shadow;
    if (disabled) {
      fg = AppTheme.faintMuted.withValues(alpha: 0.55);
      bg = Colors.transparent;
      shadow = const [];
    } else if (selected) {
      fg = AppTheme.indigoPrimary;
      bg = AppTheme.indigoSoft;
      shadow = [
        BoxShadow(
          color: AppTheme.indigoPrimary.withValues(alpha: 0.12),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
    } else {
      fg = AppTheme.muted;
      bg = Colors.transparent;
      shadow = const [];
    }

    return Tooltip(
      message: disabled ? 'هذا النطاق غير متاح حالياً' : '',
      triggerMode:
          disabled ? TooltipTriggerMode.longPress : TooltipTriggerMode.manual,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: shadow,
            border: selected
                ? Border.all(
                    color:
                        AppTheme.indigoBright.withValues(alpha: 0.22),
                  )
                : null,
          ),
          child: Text(
            scope.arabicLabel,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}
