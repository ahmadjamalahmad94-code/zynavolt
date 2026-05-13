// Mirror of GET /api/v1/devices/<id>/insights (v74).
//
// Backend handler: `device_insights` in
// `web/app/blueprints/mobile_devices_api.py`. The endpoint always
// returns HTTP 200 even when underlying data isn't ready; the
// `available` flag + stable `reason` code carry the contract.
//
// Stable `reason` values (locked by v74 backend tests):
//   * `reading_unavailable`          — no recent reading row yet.
//   * `station_coords_unavailable`   — provider blob lacks lat/lng.
//   * `weather_unreachable`          — Open-Meteo couldn't be reached.
//
// We never fabricate values when `available=false`. Optional blocks
// default to `null` so the screen can branch cleanly.

/// Compact device summary surfaced even on the unavailable path so
/// the screen header renders consistently regardless of state.
class InsightsDevice {
  InsightsDevice({
    required this.id,
    required this.name,
    required this.timezone,
  });

  factory InsightsDevice.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return InsightsDevice(
      id: _asInt(j['id']),
      name: (j['name'] ?? '').toString(),
      timezone: (j['timezone'] ?? '').toString(),
    );
  }

  final int id;
  final String name;
  final String timezone;
}

/// Compact weather subset surfaced with the insights card so the
/// mobile screen doesn't have to fire a second `/weather` request
/// just to render the headline.
class InsightsWeatherContext {
  InsightsWeatherContext({
    required this.conditionAr,
    required this.icon,
    required this.cloudCoverPercent,
  });

  factory InsightsWeatherContext.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return InsightsWeatherContext(
      conditionAr: (j['condition_ar'] ?? '').toString(),
      icon: (j['icon'] ?? '').toString(),
      cloudCoverPercent: _asNullableDouble(j['cloud_cover_percent']),
    );
  }

  final String conditionAr;
  final String icon;
  final double? cloudCoverPercent;

  bool get isEmpty =>
      conditionAr.isEmpty && icon.isEmpty && cloudCoverPercent == null;
}

/// Compact pre-sunset prediction subset. Mirrors v74's
/// `_mobile_solar_prediction` mapper — six honest keys, no admin
/// internals.
///
/// v79 adds parsing for the v78 additive night-state fields
/// (`is_night` + `sun_state`) so the Home insights card can pivot
/// its copy honestly when the sun is down without leaving stale
/// sunset-coupled phrasing on screen. Both fields are optional in
/// the payload — older backends or future replays default to a
/// daytime view so the parser never crashes on missing keys.
class InsightsSolarPrediction {
  InsightsSolarPrediction({
    required this.sunsetTime,
    required this.effectiveSunsetTime,
    required this.timeToFullHours,
    required this.willFullBeforeSunset,
    required this.verdict,
    required this.advice,
    required this.isNight,
    required this.sunState,
  });

  factory InsightsSolarPrediction.fromJson(Map<String, dynamic> json) {
    // v79: parse `is_night` defensively (any non-`true` value
    // resolves to `false`). `sun_state` falls back to the literal
    // `'night'`/`'day'` derived from `is_night` when the field is
    // missing or carries an unknown value — keeps the binary view
    // consistent even on older backends.
    final isNight = json['is_night'] == true;
    final rawSunState =
        (json['sun_state'] ?? '').toString().trim().toLowerCase();
    final sunState = rawSunState == 'night' || rawSunState == 'day'
        ? rawSunState
        : (isNight ? 'night' : 'day');
    return InsightsSolarPrediction(
      sunsetTime: _asNullableString(json['sunset_time']),
      effectiveSunsetTime: _asNullableString(json['effective_sunset_time']),
      timeToFullHours: _asNullableDouble(json['time_to_full_hours']),
      willFullBeforeSunset: json['will_full_before_sunset'] == true,
      verdict: _asNullableString(json['verdict']),
      advice: _asNullableString(json['advice']),
      isNight: isNight,
      sunState: sunState,
    );
  }

  /// `HH:MM` strings or `null` when the upstream forecast omitted them.
  final String? sunsetTime;
  final String? effectiveSunsetTime;

  /// Time remaining to reach 100% SoC at the current charge rate.
  /// `null` when there is no charging activity or the helper couldn't
  /// derive a confident estimate. v78 forces this to `null` at night
  /// because the underlying derivation is sunset-coupled.
  final double? timeToFullHours;

  /// True only when the helper believes the battery will hit 100% on
  /// today's solar before the effective sunset. v78 forces this to
  /// `false` at night for the same reason as `timeToFullHours`.
  final bool willFullBeforeSunset;

  /// Arabic short-form verdict, e.g. "سيتم شحن البطارية قبل الغروب".
  /// `null` when the helper couldn't classify the period.
  final String? verdict;

  /// Arabic actionable advice, e.g. "الوضع جيد." `null` when the
  /// helper had nothing to recommend.
  final String? advice;

  /// v79 additive (from v78 backend): stable boolean for the "sun is
  /// down" state. Anchored on the geometric sunset/sunrise clamp
  /// server-side, so the mobile card can branch without recomputing
  /// the daylight window from local time.
  final bool isNight;

  /// v79 additive (from v78 backend): `'day'` whenever the sun is up,
  /// `'night'` whenever it's down. Redundant with [isNight] but
  /// stable across backends that may surface only one or the other.
  final String sunState;
}

/// Compact energy-advice subset (headline + detail + level).
class InsightsEnergyAdvice {
  InsightsEnergyAdvice({
    required this.headline,
    required this.detail,
    required this.level,
  });

  factory InsightsEnergyAdvice.fromJson(Map<String, dynamic> json) {
    final raw = (json['level'] ?? '').toString().trim().toLowerCase();
    return InsightsEnergyAdvice(
      headline: (json['headline'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      level: _validLevels.contains(raw) ? raw : 'unknown',
    );
  }

  /// Backend's status_label (e.g. "🟢 مطمئن"). The mobile card
  /// renders it verbatim — emoji prefix is intentional.
  final String headline;

  /// Best-effort Arabic detail combining `smart_warning` +
  /// `smart_recommendation`, or `decision_now` as a fallback.
  final String detail;

  /// One of `good` / `caution` / `warning` / `critical` / `unknown`
  /// — stable machine codes the mobile screen maps to soft tones.
  final String level;

  bool get isEmpty => headline.isEmpty && detail.isEmpty;
}

/// Top-level envelope. When `available=false` the three insight
/// blocks (`weatherContext`, `solarPrediction`, `energyAdvice`) are
/// `null`/empty and the calling screen branches on the `reason`.
class InsightsSnapshot {
  InsightsSnapshot({
    required this.available,
    required this.device,
    required this.weatherContext,
    required this.solarPrediction,
    required this.energyAdvice,
    required this.reason,
    required this.message,
    required this.generatedAt,
  });

  factory InsightsSnapshot.fromJson(Map<String, dynamic> json) {
    final available = json['available'] == true;
    InsightsSolarPrediction? prediction;
    if (available) {
      final rawPred = json['solar_prediction'];
      if (rawPred is Map) {
        prediction = InsightsSolarPrediction.fromJson(
          rawPred.cast<String, dynamic>(),
        );
      }
    }
    InsightsEnergyAdvice? advice;
    if (available) {
      final rawAdv = json['energy_advice'];
      if (rawAdv is Map) {
        advice = InsightsEnergyAdvice.fromJson(
          rawAdv.cast<String, dynamic>(),
        );
      }
    }
    return InsightsSnapshot(
      available: available,
      device: InsightsDevice.fromJson(
        (json['device'] as Map?)?.cast<String, dynamic>(),
      ),
      weatherContext: available
          ? InsightsWeatherContext.fromJson(
              (json['weather_context'] as Map?)?.cast<String, dynamic>(),
            )
          : null,
      solarPrediction: prediction,
      energyAdvice: advice,
      reason: _asNullableString(json['reason']),
      message: _asNullableString(json['message']),
      generatedAt: (json['generated_at'] ?? '').toString(),
    );
  }

  final bool available;
  final InsightsDevice device;

  /// `null` when `available=false`. Compact subset only.
  final InsightsWeatherContext? weatherContext;

  /// `null` when `available=false` OR the upstream helper returned
  /// `None` (no latest reading).
  final InsightsSolarPrediction? solarPrediction;

  /// `null` when `available=false`. Compact headline/detail/level.
  final InsightsEnergyAdvice? energyAdvice;

  /// Stable machine code when `available=false`. Known values
  /// (v74 backend): `reading_unavailable`, `station_coords_unavailable`,
  /// `weather_unreachable`. The screen maps these to localised Arabic
  /// copy; the backend's English `message` is the fallback for unknown
  /// future codes.
  final String? reason;

  /// Calm English fallback copy from the backend.
  final String? message;

  final String generatedAt;
}

// ── Stable vocabularies + helpers ─────────────────────────────────────

const Set<String> _validLevels = {
  'good',
  'caution',
  'warning',
  'critical',
  'unknown',
};

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

double? _asNullableDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }
  return null;
}

String? _asNullableString(Object? raw) {
  if (raw == null) return null;
  final s = raw.toString();
  return s.isEmpty ? null : s;
}
