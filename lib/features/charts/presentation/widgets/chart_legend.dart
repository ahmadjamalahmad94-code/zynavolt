import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../data/energy_chart_models.dart';
import 'chart_palette.dart';

/// Compact RTL legend.
///
/// v77 polish: trimmed from five markers to four. The chart already
/// labels its own SOC reference line ("متوسط الشحن XX%") and the
/// right-side % axis carries the percentage scale, so a fifth legend
/// chip would have duplicated information and crowded the wrap on
/// small phones. Markers semantic:
///   * solid dot   → per-bucket line traces (الإنتاج, الاستهلاك)
///   * ringed dot  → period-total only (البطارية, الشبكة)
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.series});

  final EnergyChartSeries series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: [
        _LegendItem(
          color: ChartPalette.production,
          label: 'الإنتاج',
          value: '${_fmt(series.productionKwh)} kWh',
        ),
        _LegendItem(
          color: ChartPalette.consumption,
          label: 'الاستهلاك',
          value: '${_fmt(series.consumptionKwh)} kWh',
        ),
        _LegendItem(
          color: ChartPalette.battery,
          label: 'البطارية',
          value: '${_fmt(series.batteryInKwh)} kWh',
          ringed: true,
        ),
        _LegendItem(
          color: ChartPalette.grid,
          label: 'الشبكة',
          value: '${_fmt(series.gridInKwh)} kWh',
          ringed: true,
        ),
      ],
    );
  }

  static String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    this.ringed = false,
  });

  final Color color;
  final String label;
  final String value;

  /// `ringed=true` renders an outlined dot (period-total semantics).
  /// Solid dots (the default) represent per-bucket line traces. The
  /// SOC reference line is no longer surfaced here — the chart's own
  /// dashed line + right-axis % scale already labels it, so a
  /// separate chip would have duplicated information.
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LegendDot(color: color, ringed: ringed),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: ZynColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: ZynColors.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.ringed,
  });

  final Color color;
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    // Solid dot reads slightly larger with a subtle outer halo so it
    // catches the eye without being saturated.
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: ringed ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(999),
        border: ringed ? Border.all(color: color, width: 2) : null,
        boxShadow: ringed
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
      ),
    );
  }
}
