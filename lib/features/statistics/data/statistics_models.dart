// Mirror of GET /api/v1/devices/<id>/statistics (v56).
//
// Backend handler: `device_statistics` in
// `web/app/blueprints/mobile_devices_api.py`. The endpoint only
// supports `view=day|month`; mobile UI matches that — `year` is
// intentionally deferred until backend supports it.
//
// Payload contract (locked by v56 tests):
//
//   {
//     "view":          "day" | "month",
//     "anchor":        "YYYY-MM-DD" (day) | "YYYY-MM" (month),
//     "title_hint":    Arabic label, e.g. "يوم 2026-05-12",
//     "totals":        { production_kwh, consumption_kwh,
//                        battery_in_kwh, grid_in_kwh,
//                        avg_battery_soc, max_solar_w,
//                        samples, data_gaps },
//     "buckets":       { labels: [...], production_kwh: [...],
//                        consumption_kwh: [...] },
//     "empty":         bool,
//     "generated_at":  ISO timestamp,
//   }

class StatisticsTotals {
  StatisticsTotals({
    required this.productionKwh,
    required this.consumptionKwh,
    required this.batteryInKwh,
    required this.gridInKwh,
    required this.avgBatterySocPercent,
    required this.maxSolarW,
    required this.samples,
    required this.dataGaps,
  });

  factory StatisticsTotals.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return StatisticsTotals(
      productionKwh: _asDouble(j['production_kwh']),
      consumptionKwh: _asDouble(j['consumption_kwh']),
      batteryInKwh: _asDouble(j['battery_in_kwh']),
      gridInKwh: _asDouble(j['grid_in_kwh']),
      avgBatterySocPercent: _asDouble(j['avg_battery_soc']),
      maxSolarW: _asDouble(j['max_solar_w']),
      samples: _asInt(j['samples']),
      dataGaps: _asInt(j['data_gaps']),
    );
  }

  static StatisticsTotals empty() => StatisticsTotals(
        productionKwh: 0,
        consumptionKwh: 0,
        batteryInKwh: 0,
        gridInKwh: 0,
        avgBatterySocPercent: 0,
        maxSolarW: 0,
        samples: 0,
        dataGaps: 0,
      );

  final double productionKwh;
  final double consumptionKwh;
  final double batteryInKwh;
  final double gridInKwh;
  final double avgBatterySocPercent;
  final double maxSolarW;
  final int samples;
  final int dataGaps;
}

class StatisticsBuckets {
  StatisticsBuckets({
    required this.labels,
    required this.productionKwh,
    required this.consumptionKwh,
  });

  factory StatisticsBuckets.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return StatisticsBuckets(
      labels: _asStringList(j['labels']),
      productionKwh: _asDoubleList(j['production_kwh']),
      consumptionKwh: _asDoubleList(j['consumption_kwh']),
    );
  }

  static StatisticsBuckets empty() => StatisticsBuckets(
        labels: const [],
        productionKwh: const [],
        consumptionKwh: const [],
      );

  final List<String> labels;
  final List<double> productionKwh;
  final List<double> consumptionKwh;

  /// True when every bucket array is empty. The backend already sets
  /// `empty=true` in that case but consumers without that flag can
  /// fall back to this helper.
  bool get isEmpty =>
      labels.isEmpty && productionKwh.isEmpty && consumptionKwh.isEmpty;
}

class StatisticsSnapshot {
  StatisticsSnapshot({
    required this.view,
    required this.anchor,
    required this.titleHint,
    required this.totals,
    required this.buckets,
    required this.empty,
    required this.generatedAt,
  });

  factory StatisticsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawView = (json['view'] ?? 'day').toString().trim().toLowerCase();
    return StatisticsSnapshot(
      view: rawView == 'month' ? 'month' : 'day',
      anchor: (json['anchor'] ?? '').toString(),
      titleHint: (json['title_hint'] ?? '').toString(),
      totals: StatisticsTotals.fromJson(
          (json['totals'] as Map?)?.cast<String, dynamic>()),
      buckets: StatisticsBuckets.fromJson(
          (json['buckets'] as Map?)?.cast<String, dynamic>()),
      empty: json['empty'] == true,
      generatedAt: (json['generated_at'] ?? '').toString(),
    );
  }

  final String view;
  final String anchor;
  final String titleHint;
  final StatisticsTotals totals;
  final StatisticsBuckets buckets;
  final bool empty;
  final String generatedAt;
}

// ── Defensive coercion helpers ────────────────────────────────────────

double _asDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return 0.0;
    return double.tryParse(t) ?? 0.0;
  }
  return 0.0;
}

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

List<String> _asStringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => (e ?? '').toString()).toList(growable: false);
}

List<double> _asDoubleList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map(_asDouble).toList(growable: false);
}
