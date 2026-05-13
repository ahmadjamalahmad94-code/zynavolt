// Mirrors of GET /api/v1/devices/<id>/history items and
// GET /api/v1/devices/<id>/alerts items.
//
// Both endpoints live under the `mobile_devices_api_bp` blueprint in
// `web/app/blueprints/mobile_devices_api.py`. The mobile already uses
// `/api/mobile/devices` (the core blueprint) for primary read/write —
// the diagnostics surface is intentionally on the v1 path so it stays
// independently versionable.

// ─── History row ────────────────────────────────────────────────────

/// One historical `Reading` row. Mirrors `_reading_payload` in the
/// backend file above. v52 surfaces only the subset the UI actually
/// renders today (timestamp + headline powers + status); the other
/// fields are still parsed and stored as nullable doubles in case the
/// surface grows later, but the device-detail history card only reads
/// `createdAt + solarPowerW + homeLoadW + batterySocPercent +
/// statusText`.
class DeviceReadingRow {
  DeviceReadingRow({
    required this.id,
    required this.createdAt,
    required this.solarPowerW,
    required this.homeLoadW,
    required this.batterySocPercent,
    required this.batteryPowerW,
    required this.gridPowerW,
    required this.inverterPowerW,
    required this.dailyProductionKwh,
    required this.statusText,
  });

  factory DeviceReadingRow.fromJson(Map<String, dynamic> json) =>
      DeviceReadingRow(
        id: _asInt(json['id']),
        createdAt: json['created_at']?.toString(),
        solarPowerW: _asDouble(json['solar_power']),
        homeLoadW: _asDouble(json['home_load']),
        batterySocPercent: _asDouble(json['battery_soc']),
        batteryPowerW: _asDouble(json['battery_power']),
        gridPowerW: _asDouble(json['grid_power']),
        inverterPowerW: _asDouble(json['inverter_power']),
        dailyProductionKwh: _asDouble(json['daily_production']),
        statusText: (json['status_text'] ?? '').toString(),
      );

  final int id;
  final String? createdAt;
  final double solarPowerW;
  final double homeLoadW;
  final double batterySocPercent;
  final double batteryPowerW;
  final double gridPowerW;
  final double inverterPowerW;
  final double dailyProductionKwh;
  final String statusText;
}

// ─── Alert row ──────────────────────────────────────────────────────

/// One server-derived alert. Backend currently emits only two keys
/// (`battery_low`, `solar_zero`) — mobile localises them via
/// [alertMessageArabic] so the English `message` from the backend
/// never leaks into the Arabic-first UI. Unknown keys fall back to
/// the raw `message` so a future backend addition still renders.
class DeviceAlert {
  DeviceAlert({
    required this.level,
    required this.key,
    required this.message,
  });

  factory DeviceAlert.fromJson(Map<String, dynamic> json) => DeviceAlert(
        level: (json['level'] ?? '').toString().trim().toLowerCase(),
        key: (json['key'] ?? '').toString().trim().toLowerCase(),
        message: (json['message'] ?? '').toString(),
      );

  /// One of `warning` / `info` per the current backend handler. The
  /// raw string is stored so future levels (e.g. `critical`) render
  /// even if mobile doesn't know them yet.
  final String level;

  /// Stable machine key, e.g. `battery_low`, `solar_zero`.
  final String key;

  /// Raw backend message (English today). Use [alertMessageArabic]
  /// for user-facing rendering — this is kept only as fallback for
  /// unknown keys.
  final String message;
}

/// v52: Arabic-first localizer for the small set of alert keys the
/// backend currently emits. Returns the raw [DeviceAlert.message] for
/// unknown keys so the UI never goes blank if the backend expands the
/// alert vocabulary before the mobile catalog catches up.
String alertMessageArabic(DeviceAlert alert) {
  switch (alert.key) {
    case 'battery_low':
      return 'البطارية أقل من 20٪.';
    case 'solar_zero':
      return 'لا يوجد إنتاج شمسي حالياً.';
    default:
      // Fallback: never leak an empty bubble — the raw English
      // message is at least informative, and a future v53 can extend
      // the switch above.
      return alert.message.isNotEmpty ? alert.message : 'تنبيه من الجهاز.';
  }
}

/// v52: Arabic short title per key (used as the row's eyebrow line
/// above the message). Distinct from [alertMessageArabic] so the row
/// reads as a labelled note rather than a single long sentence.
String alertTitleArabic(DeviceAlert alert) {
  switch (alert.key) {
    case 'battery_low':
      return 'البطارية منخفضة';
    case 'solar_zero':
      return 'الإنتاج الشمسي صفر';
    default:
      return 'تنبيه';
  }
}

// ─── Defensive coercion helpers ─────────────────────────────────────

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

double _asDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return 0.0;
    return double.tryParse(t) ?? 0.0;
  }
  return 0.0;
}
