// Mirror of GET /api/mobile/loads/recommendations (Heavy v10.5.35+).
//
// The endpoint always returns HTTP 200 — `available=false`
// envelopes carry a stable `reason` code instead of an error
// status. `decision` and `items` are populated only on the
// available path.

class LoadsScope {
  const LoadsScope({required this.mode, required this.deviceId});

  factory LoadsScope.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return LoadsScope(
      mode: (j['mode'] ?? '').toString(),
      deviceId: j['device_id'] is int ? j['device_id'] as int : null,
    );
  }

  final String mode;
  final int? deviceId;
}

class LoadsDecision {
  const LoadsDecision({
    required this.headline,
    required this.summary,
    required this.level,
    required this.confidence,
  });

  factory LoadsDecision.fromJson(Map<String, dynamic> json) {
    return LoadsDecision(
      headline: (json['headline'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      level: (json['level'] ?? 'unknown').toString(),
      confidence: (json['confidence'] ?? 'unknown').toString(),
    );
  }

  final String headline;
  final String summary;

  /// `good` / `caution` / `warning` / `critical` / `unknown`.
  final String level;

  /// `low` / `medium` / `high` / `unknown`.
  final String confidence;
}

class LoadItem {
  const LoadItem({
    required this.loadId,
    required this.name,
    required this.powerW,
    required this.priority,
    required this.allowed,
    required this.reason,
  });

  factory LoadItem.fromJson(Map<String, dynamic> json) {
    final raw = json['power_w'];
    return LoadItem(
      loadId: (json['load_id'] is int) ? json['load_id'] as int : 0,
      name: (json['name'] ?? '').toString(),
      powerW: raw is num ? raw.toDouble() : 0.0,
      priority: (json['priority'] is int) ? json['priority'] as int : 0,
      allowed: json['allowed'] == true,
      reason: (json['reason'] ?? '').toString(),
    );
  }

  final int loadId;
  final String name;
  final double powerW;
  final int priority;
  final bool allowed;
  final String reason;
}

class LoadsTotals {
  const LoadsTotals({
    required this.enabledLoadCount,
    required this.allowedCount,
    required this.deniedCount,
    required this.allowedPowerW,
    required this.deniedPowerW,
  });

  factory LoadsTotals.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    double asDouble(Object? raw) =>
        raw is num ? raw.toDouble() : 0.0;
    int asInt(Object? raw) => raw is int ? raw : 0;
    return LoadsTotals(
      enabledLoadCount: asInt(j['enabled_load_count']),
      allowedCount: asInt(j['allowed_count']),
      deniedCount: asInt(j['denied_count']),
      allowedPowerW: asDouble(j['allowed_power_w']),
      deniedPowerW: asDouble(j['denied_power_w']),
    );
  }

  final int enabledLoadCount;
  final int allowedCount;
  final int deniedCount;
  final double allowedPowerW;
  final double deniedPowerW;
}

/// Heavy v10.5.37+ — surplus headline metrics, mirrored from the
/// web dashboard so the mobile UI can show the same numbers the
/// dashboard shows ("الفائض الفعلي" / "احتياج البطارية" / ...).
class LoadsSurplus {
  const LoadsSurplus({
    required this.safeAvailableW,
    required this.rawW,
    required this.batteryNeedW,
    required this.actualW,
    required this.phase,
    required this.nightMaxW,
  });

  factory LoadsSurplus.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    double asDouble(Object? raw) =>
        raw is num ? raw.toDouble() : 0.0;
    return LoadsSurplus(
      safeAvailableW: asDouble(j['safe_available_w']),
      rawW: asDouble(j['raw_w']),
      batteryNeedW: asDouble(j['battery_need_w']),
      actualW: asDouble(j['actual_w']),
      phase: (j['phase'] ?? 'night').toString(),
      nightMaxW: asDouble(j['night_max_w']),
    );
  }

  final double safeAvailableW;
  final double rawW;
  final double batteryNeedW;
  final double actualW;

  /// `'day'` or `'night'`.
  final String phase;

  final double nightMaxW;
}

class LoadsRecommendationsSnapshot {
  const LoadsRecommendationsSnapshot({
    required this.available,
    required this.reason,
    required this.message,
    required this.scope,
    required this.decision,
    required this.items,
    required this.totals,
    required this.surplus,
    required this.generatedAt,
  });

  factory LoadsRecommendationsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(LoadItem.fromJson)
        .toList(growable: false);
    LoadsDecision? decision;
    final rawDecision = json['decision'];
    if (rawDecision is Map) {
      decision = LoadsDecision.fromJson(rawDecision.cast<String, dynamic>());
    }
    return LoadsRecommendationsSnapshot(
      available: json['available'] == true,
      reason: json['reason']?.toString(),
      message: json['message']?.toString(),
      scope: LoadsScope.fromJson(
        (json['scope'] as Map?)?.cast<String, dynamic>(),
      ),
      decision: decision,
      items: items,
      totals: LoadsTotals.fromJson(
        (json['totals'] as Map?)?.cast<String, dynamic>(),
      ),
      surplus: LoadsSurplus.fromJson(
        (json['surplus'] as Map?)?.cast<String, dynamic>(),
      ),
      generatedAt: (json['generated_at'] ?? '').toString(),
    );
  }

  final bool available;
  final String? reason;
  final String? message;
  final LoadsScope scope;
  final LoadsDecision? decision;
  final List<LoadItem> items;
  final LoadsTotals totals;
  final LoadsSurplus surplus;
  final String generatedAt;

  List<LoadItem> get allowed =>
      [for (final i in items) if (i.allowed) i];
  List<LoadItem> get denied =>
      [for (final i in items) if (!i.allowed) i];
}
