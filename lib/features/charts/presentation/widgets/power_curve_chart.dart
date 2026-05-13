import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../data/energy_chart_models.dart';
import 'chart_palette.dart';

/// Premium power-curve chart.
///
/// v77 art-direction polish:
///   * Two real per-bucket series with smooth Bezier curves and soft
///     translucent area fills (الإنتاج, الاستهلاك).
///   * A calm dashed SOC reference line at the period's average
///     state-of-charge — drawn over a **real dual-axis** treatment:
///     the left axis labels read in kWh, the right axis labels read
///     in % (0–100), and the SOC line sits visually at its true
///     percentage position. The right axis is rendered intentionally
///     subtle so it reads as "secondary scale", not a competing one.
///   * The chart canvas itself has no border box — only soft dashed
///     horizontal gridlines, so the chart breathes inside the card.
///
/// Chart math note: the backend only exposes the **period mean** SOC
/// (`totals.avg_battery_soc`). We honour that honestly — no per-bucket
/// SOC line is faked. The dashed reference line + right-axis %
/// labels make the dual-scale intent crystal clear without inventing
/// a trace we don't have.
class PowerCurveChart extends StatelessWidget {
  const PowerCurveChart({
    super.key,
    required this.series,
  });

  final EnergyChartSeries series;

  /// Height tuned for one-thumb Home scroll — visible at a glance,
  /// readable on small phones, never dominates the screen.
  static const double _height = 232;

  @override
  Widget build(BuildContext context) {
    final samples = series.samples;
    final peak = series.peakKwh;
    // Floor the axis at 1.0 kWh so a quiet period (e.g. a cloudy
    // morning) still draws a visible curve rather than collapsing
    // into a flat line at zero. Round up to the next nice step for
    // tidy left-axis labels.
    final axisMax = _niceCeil(peak < 1.0 ? 1.0 : peak * 1.08);
    final stepY = axisMax / 4.0;

    // Wrap the chart in an LTR Directionality so fl_chart's left/right
    // axis terminology stays unambiguous — the surrounding card is
    // RTL, so this is the one place we explicitly opt out. The chart
    // itself reads time → forward as it does on every premium
    // monitoring app, even on Arabic locales.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: _height,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: axisMax,
            minX: 0,
            maxX: (samples.length - 1).toDouble().clamp(1, double.infinity),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: stepY,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppTheme.line.withValues(alpha: 0.45),
                strokeWidth: 1,
                dashArray: const [4, 5],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              // ─ Right axis = SOC % (subtle, secondary scale) ─────
              rightTitles: AxisTitles(
                axisNameWidget: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '%',
                    style: TextStyle(
                      color: ChartPalette.soc.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                axisNameSize: 14,
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: stepY,
                  reservedSize: 26,
                  getTitlesWidget: (value, meta) {
                    // Map kWh axis fraction → percent label so the
                    // right ticks (0/25/50/75/100) sit visually
                    // aligned with the left kWh gridlines.
                    final pct = (value / axisMax * 100).round();
                    if (pct < 0 || pct > 100) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '$pct',
                        style: TextStyle(
                          color: AppTheme.faintMuted
                              .withValues(alpha: 0.85),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // ─ Left axis = kWh (primary scale) ───────────────────
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: stepY,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _fmtKwh(value),
                      style: const TextStyle(
                        color: AppTheme.faintMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: _bottomLabelInterval(samples.length),
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= samples.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _shortLabel(samples[i].label),
                        style: const TextStyle(
                          color: AppTheme.faintMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) =>
                    AppTheme.ink.withValues(alpha: 0.93),
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                tooltipMargin: 12,
                getTooltipItems: (spots) {
                  if (spots.isEmpty) return const [];
                  final first = spots.first;
                  final i = first.x.round();
                  if (i < 0 || i >= samples.length) return const [];
                  final s = samples[i];
                  final lines = <LineTooltipItem>[
                    LineTooltipItem(
                      s.label,
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                      children: [
                        const TextSpan(text: '\n'),
                        TextSpan(
                          text: 'الإنتاج: ${_fmtKwh(s.productionKwh)} kWh',
                          style: TextStyle(
                            color: ChartPalette.production,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(text: '\n'),
                        TextSpan(
                          text:
                              'الاستهلاك: ${_fmtKwh(s.consumptionKwh)} kWh',
                          style: TextStyle(
                            color: ChartPalette.consumption,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ];
                  while (lines.length < spots.length) {
                    lines.add(LineTooltipItem(
                      '',
                      const TextStyle(color: Colors.transparent),
                    ));
                  }
                  return lines;
                },
              ),
            ),
            lineBarsData: [
              _lineFor(
                samples,
                (s) => s.productionKwh,
                color: ChartPalette.production,
                fillTop: ChartPalette.production.withValues(alpha: 0.26),
                fillBottom: ChartPalette.production.withValues(alpha: 0.02),
              ),
              _lineFor(
                samples,
                (s) => s.consumptionKwh,
                color: ChartPalette.consumption,
                fillTop: ChartPalette.consumption.withValues(alpha: 0.20),
                fillBottom: ChartPalette.consumption.withValues(alpha: 0.02),
              ),
            ],
            // Calm dashed SOC reference line at the period's average
            // SOC (placed visually at the corresponding fraction of
            // the left axis so it lines up with the right-axis %
            // ticks). Drawn only when SOC > 0 to avoid implying a
            // zero-battery state when the field is simply unset.
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (series.avgSocPercent > 0)
                  HorizontalLine(
                    y: axisMax *
                        (series.avgSocPercent / 100.0).clamp(0.0, 1.0),
                    color: ChartPalette.soc.withValues(alpha: 0.72),
                    strokeWidth: 1.6,
                    dashArray: const [6, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.only(left: 42, bottom: 3),
                      style: TextStyle(
                        color: ChartPalette.soc,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                      labelResolver: (_) =>
                          'متوسط الشحن ${series.avgSocPercent.toStringAsFixed(0)}%',
                    ),
                  ),
              ],
            ),
          ),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  static LineChartBarData _lineFor(
    List<EnergyChartSample> samples,
    double Function(EnergyChartSample) pick, {
    required Color color,
    required Color fillTop,
    required Color fillBottom,
  }) {
    return LineChartBarData(
      spots: [
        for (final s in samples) FlSpot(s.xIndex.toDouble(), pick(s)),
      ],
      isCurved: true,
      curveSmoothness: 0.36,
      preventCurveOverShooting: true,
      // v77 final polish: 2.6 px clean stroke. The previous 2.8 px +
      // drop-shadow combo read as a "decorated" line — premium energy
      // dashboards keep their strokes clean and let the area fill
      // carry the visual weight. No shadow.
      barWidth: 2.6,
      color: color,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillTop, fillBottom],
        ),
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────

  /// Round up to a "nice" multiple so axis labels stay clean across
  /// orders of magnitude. Tuned so 4 ticks always land on round
  /// numbers (0 / step / 2step / 3step / 4step).
  static double _niceCeil(double v) {
    if (v <= 1) return ((v * 2).ceilToDouble()) / 2.0;
    if (v <= 4) return v.ceilToDouble();
    if (v <= 10) return ((v / 2).ceilToDouble()) * 2;
    if (v <= 40) return ((v / 4).ceilToDouble()) * 4;
    if (v <= 100) return ((v / 10).ceilToDouble()) * 10;
    if (v <= 400) return ((v / 20).ceilToDouble()) * 20;
    return ((v / 50).ceilToDouble()) * 50;
  }

  /// Show roughly 5 bottom-axis labels regardless of bucket density so
  /// labels never overlap on a phone-width chart.
  static double _bottomLabelInterval(int n) {
    if (n <= 6) return 1;
    if (n <= 12) return 2;
    if (n <= 24) return 4;
    if (n <= 31) return 5;
    return (n / 6).ceilToDouble();
  }

  /// Day labels like "09:00" stay verbatim; month labels like
  /// "2026-05-12" get trimmed to "05-12" so they fit a phone-width
  /// axis without rotation.
  static String _shortLabel(String raw) {
    if (raw.length <= 5) return raw;
    if (raw.length >= 10 && raw[4] == '-' && raw[7] == '-') {
      return raw.substring(5);
    }
    return raw.substring(0, 5);
  }

  static String _fmtKwh(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}
