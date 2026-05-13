// Mirror of GET /api/mobile/dashboard data envelope.
//
// Field names are taken verbatim from the backend payload builder
// (`_mobile_dashboard_payload` in `app/blueprints/mobile_api.py`). Every
// numeric value here is **server-computed** — the mobile app never derives
// or reinterprets these. Optional fields default to `null` / `0.0` so a
// partial payload never throws.

class DashboardScope {
  DashboardScope({
    required this.mode,
    required this.deviceId,
    required this.isAllDevices,
  });

  factory DashboardScope.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return DashboardScope(
      mode: (j['mode'] ?? '').toString(),
      deviceId: j['device_id'] is int ? j['device_id'] as int : null,
      isAllDevices: j['is_all_devices'] == true,
    );
  }

  /// `device` (one device) or `all` (aggregate across the user's devices).
  final String mode;
  final int? deviceId;
  final bool isAllDevices;
}

class DashboardCards {
  DashboardCards({
    required this.solarPowerW,
    required this.homeLoadW,
    required this.batterySocPercent,
    required this.batteryPowerW,
    required this.gridPowerW,
    required this.inverterPowerW,
    required this.generatorPowerW,
    required this.dailyProductionKwh,
    required this.monthlyProductionKwh,
    required this.totalProductionKwh,
  });

  factory DashboardCards.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    double n(String key) {
      final v = j[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return DashboardCards(
      solarPowerW: n('solar_power_w'),
      homeLoadW: n('home_load_w'),
      batterySocPercent: n('battery_soc_percent'),
      batteryPowerW: n('battery_power_w'),
      gridPowerW: n('grid_power_w'),
      inverterPowerW: n('inverter_power_w'),
      // v93r — Generator (external AC-IN) power for the new
      // flow-graph node. Defaults to 0 when the server hasn't
      // been upgraded yet, so older builds stay functional.
      generatorPowerW: n('generator_power_w'),
      dailyProductionKwh: n('daily_production_kwh'),
      monthlyProductionKwh: n('monthly_production_kwh'),
      totalProductionKwh: n('total_production_kwh'),
    );
  }

  static DashboardCards empty() => DashboardCards(
        solarPowerW: 0,
        homeLoadW: 0,
        batterySocPercent: 0,
        batteryPowerW: 0,
        gridPowerW: 0,
        inverterPowerW: 0,
        generatorPowerW: 0,
        dailyProductionKwh: 0,
        monthlyProductionKwh: 0,
        totalProductionKwh: 0,
      );

  final double solarPowerW;
  final double homeLoadW;
  final double batterySocPercent;
  final double batteryPowerW;
  final double gridPowerW;
  final double inverterPowerW;
  /// v93r — Generator / external AC-IN power (W). On a Deye hybrid
  /// inverter the AC-IN port carries either utility grid OR a
  /// backup generator; the server cannot distinguish the two, so
  /// this field reflects the AC-IN flow regardless of source.
  final double generatorPowerW;
  final double dailyProductionKwh;
  final double monthlyProductionKwh;
  final double totalProductionKwh;
}

class DashboardLatest {
  DashboardLatest({
    required this.createdAt,
    required this.statusText,
  });

  factory DashboardLatest.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return DashboardLatest(
      createdAt: j['created_at']?.toString(),
      statusText: (j['status_text'] ?? '').toString(),
    );
  }

  final String? createdAt;
  final String statusText;
}

class DashboardSnapshot {
  DashboardSnapshot({
    required this.scope,
    required this.cards,
    required this.latest,
    required this.empty,
    required this.generatedAt,
    required this.deviceName,
    required this.deviceConnectionStatus,
  });

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final device =
        (json['device'] as Map?)?.cast<String, dynamic>();
    return DashboardSnapshot(
      scope: DashboardScope.fromJson(
          (json['scope'] as Map?)?.cast<String, dynamic>()),
      cards: DashboardCards.fromJson(
          (json['cards'] as Map?)?.cast<String, dynamic>()),
      latest:
          DashboardLatest.fromJson((json['latest'] as Map?)?.cast<String, dynamic>()),
      empty: json['empty'] == true,
      generatedAt: json['generated_at']?.toString(),
      deviceName: (device?['name'] ?? '').toString(),
      deviceConnectionStatus:
          (device?['connection_status'] ?? '').toString(),
    );
  }

  final DashboardScope scope;
  final DashboardCards cards;
  final DashboardLatest latest;
  final bool empty;
  final String? generatedAt;
  final String deviceName;
  final String deviceConnectionStatus;
}
