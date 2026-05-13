// Mirror of GET /api/v1/devices/<id>/weather (v62).
//
// Backend handler: `device_weather` in
// `web/app/blueprints/mobile_devices_api.py`. The endpoint is HTTP
// 200 even for the "weather isn't available right now" case — the
// `available` flag + stable `reason` string carry the contract:
//
//   * `available=true`  → `current` + `sun` + `next_hour` +
//                         `day_parts` + `timeline` are populated.
//   * `available=false` → those blocks are absent; `reason` is one of:
//       - `station_coords_unavailable`
//       - `weather_unreachable`
//     `message` carries the calm fallback copy. `device` summary is
//     still present so the screen header renders consistently.
//
// We never fabricate values when `available=false`. Optional blocks
// default to `null` / `WeatherSnapshot.empty()` so the screen can
// branch cleanly.

class WeatherDevice {
  WeatherDevice({
    required this.id,
    required this.name,
    required this.timezone,
  });

  factory WeatherDevice.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return WeatherDevice(
      id: _asInt(j['id']),
      name: (j['name'] ?? '').toString(),
      timezone: (j['timezone'] ?? '').toString(),
    );
  }

  final int id;
  final String name;
  final String timezone;
}

class WeatherCurrent {
  WeatherCurrent({
    required this.temperatureC,
    required this.windSpeed,
    required this.cloudCoverPercent,
    required this.precipitationProbabilityPercent,
    required this.conditionAr,
    required this.category,
    required this.icon,
    required this.code,
    required this.currentTime,
  });

  factory WeatherCurrent.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return WeatherCurrent(
      temperatureC: _asNullableDouble(j['temperature_c']),
      windSpeed: _asNullableDouble(j['wind_speed']),
      cloudCoverPercent: _asNullableDouble(j['cloud_cover_percent']),
      precipitationProbabilityPercent:
          _asNullableDouble(j['precipitation_probability_percent']),
      conditionAr: (j['condition_ar'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      icon: (j['icon'] ?? '').toString(),
      code: _asNullableInt(j['code']),
      currentTime: (j['current_time'] ?? '').toString(),
    );
  }

  /// Nullable Celsius temperature — Open-Meteo occasionally returns
  /// `null` for very edge regions; the UI renders a `--` placeholder
  /// rather than fabricating a number.
  final double? temperatureC;
  final double? windSpeed;
  final double? cloudCoverPercent;
  final double? precipitationProbabilityPercent;
  final String conditionAr;
  final String category;
  final String icon;
  final int? code;
  final String currentTime;
}

class WeatherSun {
  WeatherSun({
    required this.sunriseTime,
    required this.sunsetTime,
    required this.effectiveSunriseTime,
    required this.effectiveSunsetTime,
  });

  factory WeatherSun.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return WeatherSun(
      sunriseTime: _asNullableString(j['sunrise_time']),
      sunsetTime: _asNullableString(j['sunset_time']),
      effectiveSunriseTime: _asNullableString(j['effective_sunrise_time']),
      effectiveSunsetTime: _asNullableString(j['effective_sunset_time']),
    );
  }

  /// `HH:MM` strings or `null` when the upstream forecast omitted
  /// them (rare — some Open-Meteo edge regions skip a sunrise/sunset
  /// entry near the poles).
  final String? sunriseTime;
  final String? sunsetTime;
  final String? effectiveSunriseTime;
  final String? effectiveSunsetTime;
}

class WeatherSlot {
  WeatherSlot({
    required this.time,
    required this.timeLabel,
    required this.temperature,
    required this.cloudCover,
    required this.precipitationProbability,
    required this.conditionAr,
    required this.category,
    required this.icon,
    required this.solarRating,
    required this.advice,
  });

  factory WeatherSlot.fromJson(Map<String, dynamic> json) => WeatherSlot(
        time: _asNullableString(json['time']),
        timeLabel: _asNullableString(json['time_label']),
        temperature: _asNullableDouble(json['temperature']),
        cloudCover: _asNullableDouble(json['cloud_cover']),
        precipitationProbability:
            _asNullableDouble(json['precipitation_probability']),
        conditionAr: (json['condition_ar'] ?? '').toString(),
        category: (json['category'] ?? '').toString(),
        icon: (json['icon'] ?? '').toString(),
        solarRating: (json['solar_rating'] ?? '').toString(),
        advice: (json['advice'] ?? '').toString(),
      );

  /// Day-part slots from `_slot_from_hourly` carry `time` (ISO).
  /// Timeline entries carry `time_label` (already-Arabic `HH:MM ص/م`).
  /// The UI picks whichever is present.
  final String? time;
  final String? timeLabel;
  final double? temperature;
  final double? cloudCover;
  final double? precipitationProbability;
  final String conditionAr;
  final String category;
  final String icon;
  final String solarRating;
  final String advice;

  /// Human-friendly time string: prefer the already-Arabic
  /// `timeLabel` (e.g. `'8:00 ص'`), fall back to the ISO `time`
  /// trimmed to `HH:MM` when present.
  String get displayTime {
    if (timeLabel != null && timeLabel!.trim().isNotEmpty) return timeLabel!;
    final iso = time ?? '';
    if (iso.length >= 16) return iso.substring(11, 16); // `HH:MM`
    return '';
  }
}

class WeatherDayParts {
  WeatherDayParts({
    required this.morning,
    required this.noon,
    required this.afternoon,
  });

  factory WeatherDayParts.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    WeatherSlot? slot(Object? raw) {
      if (raw is Map) {
        return WeatherSlot.fromJson(raw.cast<String, dynamic>());
      }
      return null;
    }

    return WeatherDayParts(
      morning: slot(j['morning']),
      noon: slot(j['noon']),
      afternoon: slot(j['afternoon']),
    );
  }

  final WeatherSlot? morning;
  final WeatherSlot? noon;
  final WeatherSlot? afternoon;
}

class WeatherSnapshot {
  WeatherSnapshot({
    required this.available,
    required this.device,
    required this.current,
    required this.sun,
    required this.nextHour,
    required this.dayParts,
    required this.timeline,
    required this.reason,
    required this.message,
    required this.generatedAt,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final available = json['available'] == true;
    final rawTimeline = json['timeline'];
    final timeline = <WeatherSlot>[];
    if (rawTimeline is List) {
      for (final entry in rawTimeline) {
        if (entry is Map) {
          timeline.add(WeatherSlot.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
    // next_hour is a single slot dict OR null on cold/partial payloads.
    WeatherSlot? nextHour;
    final rawNext = json['next_hour'];
    if (rawNext is Map) {
      nextHour = WeatherSlot.fromJson(rawNext.cast<String, dynamic>());
    }

    return WeatherSnapshot(
      available: available,
      device: WeatherDevice.fromJson(
          (json['device'] as Map?)?.cast<String, dynamic>()),
      current: available
          ? WeatherCurrent.fromJson(
              (json['current'] as Map?)?.cast<String, dynamic>())
          : null,
      sun: available
          ? WeatherSun.fromJson(
              (json['sun'] as Map?)?.cast<String, dynamic>())
          : null,
      nextHour: available ? nextHour : null,
      dayParts: available
          ? WeatherDayParts.fromJson(
              (json['day_parts'] as Map?)?.cast<String, dynamic>())
          : null,
      timeline: available ? timeline : const <WeatherSlot>[],
      reason: _asNullableString(json['reason']),
      message: _asNullableString(json['message']),
      generatedAt: (json['generated_at'] ?? '').toString(),
    );
  }

  final bool available;
  final WeatherDevice device;
  final WeatherCurrent? current;
  final WeatherSun? sun;
  final WeatherSlot? nextHour;
  final WeatherDayParts? dayParts;
  final List<WeatherSlot> timeline;

  /// Stable machine code when `available == false`. Known values
  /// (v62 backend): `station_coords_unavailable`, `weather_unreachable`.
  final String? reason;

  /// Calm fallback copy from the backend; localised Arabic copy is
  /// the screen's responsibility (we don't trust an English message
  /// to render verbatim).
  final String? message;

  final String generatedAt;
}

// ── Defensive coercion ────────────────────────────────────────────────

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

int? _asNullableInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }
  return null;
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
