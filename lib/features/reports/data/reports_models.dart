// Mirror of GET /api/v1/devices/<id>/reports/summary (v59).
//
// Backend handler: `device_reports_summary` in
// `web/app/blueprints/mobile_devices_api.py`. The endpoint accepts
// `view=day|month&date=YYYY-MM-DD` and returns a summary-only
// payload — no per-bucket time series (the v56 statistics endpoint
// already exposes those).
//
// Payload contract (locked by v59 backend tests):
//
//   {
//     "view":          "day" | "month",
//     "anchor":        "YYYY-MM-DD" (day) | "YYYY-MM" (month),
//     "title_hint":    Arabic label, e.g. "يوم 2026-05-12",
//     "summary": {
//        "production_kwh":           0.0,
//        "consumption_kwh":          0.0,
//        "battery_in_kwh":           0.0,
//        "grid_in_kwh":              0.0,
//        "solar_share_percent":      0.0,
//        "battery_share_percent":    0.0,
//        "grid_share_percent":       0.0,
//        "self_sufficiency_percent": 0.0,
//        "average_load_w":           0.0,
//        "solar_surplus_kwh":        0.0,
//     },
//     "empty":         bool,
//     "generated_at":  ISO timestamp,
//   }
//
// When `empty=true` the backend explicitly zeroes every derived
// metric — the mobile model preserves that honestly. We never
// fabricate values.

class ReportsSummary {
  ReportsSummary({
    required this.productionKwh,
    required this.consumptionKwh,
    required this.batteryInKwh,
    required this.gridInKwh,
    required this.solarSharePercent,
    required this.batterySharePercent,
    required this.gridSharePercent,
    required this.selfSufficiencyPercent,
    required this.averageLoadW,
    required this.solarSurplusKwh,
  });

  factory ReportsSummary.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return ReportsSummary(
      productionKwh: _asDouble(j['production_kwh']),
      consumptionKwh: _asDouble(j['consumption_kwh']),
      batteryInKwh: _asDouble(j['battery_in_kwh']),
      gridInKwh: _asDouble(j['grid_in_kwh']),
      solarSharePercent: _asDouble(j['solar_share_percent']),
      batterySharePercent: _asDouble(j['battery_share_percent']),
      gridSharePercent: _asDouble(j['grid_share_percent']),
      selfSufficiencyPercent: _asDouble(j['self_sufficiency_percent']),
      averageLoadW: _asDouble(j['average_load_w']),
      solarSurplusKwh: _asDouble(j['solar_surplus_kwh']),
    );
  }

  static ReportsSummary empty() => ReportsSummary(
        productionKwh: 0,
        consumptionKwh: 0,
        batteryInKwh: 0,
        gridInKwh: 0,
        solarSharePercent: 0,
        batterySharePercent: 0,
        gridSharePercent: 0,
        selfSufficiencyPercent: 0,
        averageLoadW: 0,
        solarSurplusKwh: 0,
      );

  final double productionKwh;
  final double consumptionKwh;
  final double batteryInKwh;
  final double gridInKwh;
  final double solarSharePercent;
  final double batterySharePercent;
  final double gridSharePercent;
  final double selfSufficiencyPercent;
  final double averageLoadW;
  final double solarSurplusKwh;
}

class ReportsSnapshot {
  ReportsSnapshot({
    required this.view,
    required this.anchor,
    required this.titleHint,
    required this.summary,
    required this.empty,
    required this.generatedAt,
  });

  factory ReportsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawView = (json['view'] ?? 'day').toString().trim().toLowerCase();
    return ReportsSnapshot(
      view: rawView == 'month' ? 'month' : 'day',
      anchor: (json['anchor'] ?? '').toString(),
      titleHint: (json['title_hint'] ?? '').toString(),
      summary: ReportsSummary.fromJson(
          (json['summary'] as Map?)?.cast<String, dynamic>()),
      empty: json['empty'] == true,
      generatedAt: (json['generated_at'] ?? '').toString(),
    );
  }

  final String view;
  final String anchor;
  final String titleHint;
  final ReportsSummary summary;
  final bool empty;
  final String generatedAt;
}

// ── Defensive coercion ────────────────────────────────────────────────

double _asDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return 0.0;
    return double.tryParse(t) ?? 0.0;
  }
  return 0.0;
}
