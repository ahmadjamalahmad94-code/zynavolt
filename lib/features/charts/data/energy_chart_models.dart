// v77 — Home advanced energy chart models.
//
// We deliberately do NOT introduce a parallel backend payload. Instead
// we *derive* a chart-friendly view over the existing v56
// `/api/v1/devices/<id>/statistics` response (already parsed by
// `StatisticsSnapshot`). The web statistics endpoint exposes per-bucket
// arrays for production + consumption only; battery / grid / SOC are
// available as period-level totals. The mobile chart honours that:
//   * two real per-bucket line series  → الإنتاج, الاستهلاك
//   * one calm reference line          → متوسط حالة الشحن (from
//                                         `totals.avg_battery_soc`)
//   * battery / grid contribution      → rendered as honest energy
//                                         summary bars below the chart,
//                                         never as fake per-bucket
//                                         time series.
//
// `ChartScope` captures the four scopes shown on the visual reference
// (يوم / شهر / سنة / الإجمالي) but flags each one with a `supported`
// boolean so the UI can disable the unsupported scopes honestly — no
// fake data, no silent fallback.

import '../../statistics/data/statistics_models.dart';

/// Range scope shown by the chart card. Only `day` and `month` are
/// currently backed by the v56 statistics endpoint.
enum ChartScope {
  day,
  month,
  year,
  total;

  /// Server-side `view` query parameter. Only meaningful for the
  /// supported scopes; the others throw so callers can't silently fetch
  /// fake data.
  String get apiView {
    switch (this) {
      case ChartScope.day:
        return 'day';
      case ChartScope.month:
        return 'month';
      case ChartScope.year:
      case ChartScope.total:
        throw StateError(
          'ChartScope.$name has no backend view — call sites must '
          'gate on `isSupported` before requesting data.',
        );
    }
  }

  /// Arabic chip label used by the range selector.
  String get arabicLabel {
    switch (this) {
      case ChartScope.day:
        return 'يوم';
      case ChartScope.month:
        return 'شهر';
      case ChartScope.year:
        return 'سنة';
      case ChartScope.total:
        return 'الإجمالي';
    }
  }

  /// True when the backend currently serves real data for this scope.
  bool get isSupported =>
      this == ChartScope.day || this == ChartScope.month;
}

/// One sample on the power curve. `xIndex` is the integer bucket index
/// for the x-axis; `label` is the raw bucket label coming from the
/// server (e.g. "09:00" for day view, "12 مايو" for month view).
class EnergyChartSample {
  const EnergyChartSample({
    required this.xIndex,
    required this.label,
    required this.productionKwh,
    required this.consumptionKwh,
  });

  final int xIndex;
  final String label;
  final double productionKwh;
  final double consumptionKwh;
}

/// Honest derivation of the chart-friendly view over the v56 statistics
/// snapshot. We never invent buckets we don't have, and we surface
/// "empty" honestly so the UI shows a calm empty state instead of a
/// flat-zero line that reads like data.
class EnergyChartSeries {
  EnergyChartSeries({
    required this.samples,
    required this.productionKwh,
    required this.consumptionKwh,
    required this.batteryInKwh,
    required this.gridInKwh,
    required this.avgSocPercent,
    required this.maxSolarW,
    required this.empty,
    required this.titleHint,
    required this.scope,
    required this.anchor,
  });

  factory EnergyChartSeries.fromStatistics(
    StatisticsSnapshot s, {
    required ChartScope scope,
    required String anchor,
  }) {
    final labels = s.buckets.labels;
    final prod = s.buckets.productionKwh;
    final cons = s.buckets.consumptionKwh;
    // Defensive: the three arrays should be the same length, but the
    // network is not infallible — pick the shortest so we never index
    // out of bounds.
    final n = [labels.length, prod.length, cons.length]
        .reduce((a, b) => a < b ? a : b);
    final out = <EnergyChartSample>[];
    for (var i = 0; i < n; i++) {
      out.add(EnergyChartSample(
        xIndex: i,
        label: labels[i],
        productionKwh: prod[i],
        consumptionKwh: cons[i],
      ));
    }
    return EnergyChartSeries(
      samples: out,
      productionKwh: s.totals.productionKwh,
      consumptionKwh: s.totals.consumptionKwh,
      batteryInKwh: s.totals.batteryInKwh,
      gridInKwh: s.totals.gridInKwh,
      avgSocPercent: s.totals.avgBatterySocPercent,
      maxSolarW: s.totals.maxSolarW,
      empty: s.empty || out.isEmpty,
      titleHint: s.titleHint,
      scope: scope,
      anchor: anchor,
    );
  }

  /// Per-bucket samples (length == backend `buckets.labels.length`).
  final List<EnergyChartSample> samples;

  /// Period-level totals — used by the summary bars and the legend
  /// "current period" labels. These come straight from
  /// `StatisticsSnapshot.totals` so they match what the server-side
  /// energy helpers computed; the mobile never forks the math.
  final double productionKwh;
  final double consumptionKwh;
  final double batteryInKwh;
  final double gridInKwh;
  final double avgSocPercent;
  final double maxSolarW;

  /// Calm meta surfaced in the card title area.
  final String titleHint;
  final ChartScope scope;
  final String anchor;

  /// True when the period genuinely has no readings. The card renders a
  /// quiet empty card instead of a flat-zero line.
  final bool empty;

  /// Largest production or consumption value across all buckets. Used
  /// to scale the y-axis honestly — `0` when [empty] is true so the
  /// caller can fall back to a 1.0 floor for the axis maximum.
  double get peakKwh {
    if (samples.isEmpty) return 0.0;
    var p = 0.0;
    for (final s in samples) {
      if (s.productionKwh > p) p = s.productionKwh;
      if (s.consumptionKwh > p) p = s.consumptionKwh;
    }
    return p;
  }

  /// Sum of the four energy buckets used by the summary split bar.
  /// Floored at 0.01 so the segment percentages stay numerically
  /// stable on all-zero periods (the empty-state still hides the bar
  /// entirely, so this only matters when the period has a single non-
  /// zero value).
  double get _splitDenominator {
    final t = productionKwh + consumptionKwh + batteryInKwh + gridInKwh;
    return t > 0.01 ? t : 0.01;
  }

  /// Percent each energy stream contributes to the split bar. Each
  /// value is clamped to `[0, 100]` so a defensive non-zero floor on
  /// the denominator never inflates a slice past 100.
  double get productionSharePercent =>
      ((productionKwh / _splitDenominator) * 100).clamp(0.0, 100.0);
  double get consumptionSharePercent =>
      ((consumptionKwh / _splitDenominator) * 100).clamp(0.0, 100.0);
  double get batterySharePercent =>
      ((batteryInKwh / _splitDenominator) * 100).clamp(0.0, 100.0);
  double get gridSharePercent =>
      ((gridInKwh / _splitDenominator) * 100).clamp(0.0, 100.0);
}
