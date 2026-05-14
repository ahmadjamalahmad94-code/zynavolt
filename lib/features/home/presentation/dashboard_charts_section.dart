import 'package:flutter/material.dart';

import '../../../core/design/zyn_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../dashboard/data/chart_range.dart';
import '../../dashboard/data/dashboard_models.dart';

/// v96 dashboard charts section.
///
/// Lives BELOW the existing energy flow / battery / production cards.
/// Lets the user pick a range (اليوم / الشهر / السنة) and an anchor
/// date, then renders ONLY what the current mobile API can support:
///
///   * `day`   + today          → daily_production_kwh
///   * `month` + current month  → monthly_production_kwh
///   * `year`  + current year   → total_production_kwh (cumulative)
///   * everything else          → honest empty state
///
/// No fake samples, no fabricated chart points. When the API has no
/// historical series for the chosen date, we say so in Arabic and stop.
class DashboardChartsSection extends StatefulWidget {
  const DashboardChartsSection({super.key, required this.cards});

  final DashboardCards cards;

  @override
  State<DashboardChartsSection> createState() => _DashboardChartsSectionState();
}

class _DashboardChartsSectionState extends State<DashboardChartsSection> {
  late DashboardRangeAnchor _state;

  @override
  void initState() {
    super.initState();
    _state = DashboardRangeAnchor.now(ChartRange.day);
  }

  void _setRange(ChartRange next) {
    if (next == _state.range) return;
    setState(() => _state = _state.withRange(next));
  }

  void _goBack() {
    if (!_state.canGoBack) return;
    setState(() => _state = _state.goBack());
  }

  void _goForward() {
    if (!_state.canGoForward) return;
    setState(() => _state = _state.goForward());
  }

  @override
  Widget build(BuildContext context) {
    final aggregate = _state.aggregateValueFromCards(widget.cards);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZynColors.primary50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart,
                  color: ZynColors.primary700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإنتاج عبر الزمن',
                      style: TextStyle(
                        color: ZynColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'اختر النطاق الزمني والتاريخ لعرض الإنتاج المتاح.',
                      style: TextStyle(
                        color: ZynColors.muted,
                        fontSize: 11.5,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Range selector
          _RangeSelector(
            selected: _state.range,
            onChanged: _setRange,
          ),
          const SizedBox(height: 10),

          // Date navigator
          _DateNavigator(
            label: _state.formatLabel(),
            canGoBack: _state.canGoBack,
            canGoForward: _state.canGoForward,
            isCurrent: _state.isCurrentPeriod,
            onBack: _goBack,
            onForward: _goForward,
          ),
          const SizedBox(height: 14),

          // Body — honest aggregate or honest empty state.
          if (aggregate != null)
            _AggregateBody(
              range: _state.range,
              value: aggregate,
            )
          else
            const _ChartsEmptyState(),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final ChartRange selected;
  final ValueChanged<ChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ZynColors.primary50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _RangeChip(
            label: 'اليوم',
            active: selected == ChartRange.day,
            onTap: () => onChanged(ChartRange.day),
          ),
          _RangeChip(
            label: 'الشهر',
            active: selected == ChartRange.month,
            onTap: () => onChanged(ChartRange.month),
          ),
          _RangeChip(
            label: 'السنة',
            active: selected == ChartRange.year,
            onTap: () => onChanged(ChartRange.year),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? ZynColors.primary700 : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : ZynColors.primary700,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({
    required this.label,
    required this.canGoBack,
    required this.canGoForward,
    required this.isCurrent,
    required this.onBack,
    required this.onForward,
  });

  final String label;
  final bool canGoBack;
  final bool canGoForward;
  final bool isCurrent;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    // RTL: chevron_right == previous, chevron_left == next.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZynColors.line),
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_right,
            tooltip: 'السابق',
            enabled: canGoBack,
            onTap: onBack,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                if (isCurrent)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'النطاق الحالي',
                      style: TextStyle(
                        color: ZynColors.success,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _NavButton(
            icon: Icons.chevron_left,
            tooltip: 'التالي',
            enabled: canGoForward,
            onTap: onForward,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? ZynColors.primary700 : ZynColors.line;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _AggregateBody extends StatelessWidget {
  const _AggregateBody({required this.range, required this.value});

  final ChartRange range;
  final double value;

  String get _title {
    switch (range) {
      case ChartRange.day:
        return 'الإنتاج اليومي';
      case ChartRange.month:
        return 'الإنتاج الشهري';
      case ChartRange.year:
        return 'الإجمالي التراكمي';
    }
  }

  String get _disclaimer {
    switch (range) {
      case ChartRange.day:
        return 'إجمالي إنتاج اليوم حتى الآن. تفاصيل النقاط الساعية تتطلب '
            'دعم تاريخ القراءات في الواجهة الخلفية للهاتف، وهي غير '
            'متوفرة حالياً.';
      case ChartRange.month:
        return 'إجمالي إنتاج الشهر الحالي حتى الآن. تفاصيل القيم اليومية '
            'تتطلب دعم تاريخ القراءات في الواجهة الخلفية للهاتف، وهي غير '
            'متوفرة حالياً.';
      case ChartRange.year:
        return 'هذه القيمة تمثّل إجمالي الإنتاج التراكمي للنظام منذ '
            'التشغيل — وليست إنتاج هذه السنة فقط. تفاصيل القيم الشهرية '
            'تتطلب دعم تاريخ القراءات في الواجهة الخلفية للهاتف.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: ZynColors.primary50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ZynColors.primary500.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(
              color: ZynColors.primary700,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatKwh(value),
                style: const TextStyle(
                  color: ZynColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'kWh',
                style: TextStyle(
                  color: ZynColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _disclaimer,
            style: const TextStyle(
              color: ZynColors.inkSoft,
              fontSize: 11.5,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartsEmptyState extends StatelessWidget {
  const _ChartsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: ZynColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZynColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZynColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZynColors.line),
            ),
            child: const Icon(
              Icons.info_outline,
              color: ZynColors.muted,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'لا توجد بيانات كافية لعرض المخطط لهذا التاريخ.',
              style: TextStyle(
                color: ZynColors.inkSoft,
                fontSize: 12.5,
                height: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "12.5" / "0.0" / "1,234.5" — one decimal, comma thousands. Matches the
/// number style already used in home_screen so the new card visually
/// belongs to the same dashboard.
String _formatKwh(double v) {
  final str = v.toStringAsFixed(1);
  final parts = str.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  final n = intPart.length;
  for (var i = 0; i < n; i++) {
    if (i > 0 && (n - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '$buf.${parts[1]}';
}
