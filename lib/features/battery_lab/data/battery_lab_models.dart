/// v100 — Battery Lab data models.
///
/// Mirrors the JSON payload served by `GET /api/mobile/battery-lab`,
/// which itself wraps the same `battery_insights` + `battery_details`
/// helpers the web `/battery-lab` page renders. We keep the model
/// shape conservative: every field is nullable so a backend that
/// omits a metric (e.g. an inverter with no temperature sensor)
/// doesn't crash the screen.
library;

class BatteryLabSnapshot {
  BatteryLabSnapshot({
    required this.scope,
    required this.latest,
    required this.insights,
    required this.details,
    required this.hourly,
    required this.generatedAt,
  });

  factory BatteryLabSnapshot.fromJson(Map<String, dynamic> json) {
    final hourlyRaw = (json['hourly'] as List?) ?? const [];
    return BatteryLabSnapshot(
      scope: BatteryLabScope.fromJson(
        (json['scope'] as Map?)?.cast<String, dynamic>(),
      ),
      latest: (json['latest'] as Map?)?.cast<String, dynamic>(),
      insights: BatteryInsights.fromJson(
        (json['battery_insights'] as Map?)?.cast<String, dynamic>(),
      ),
      details: BatteryDetails.fromJson(
        (json['battery_details'] as Map?)?.cast<String, dynamic>(),
      ),
      hourly: [
        for (final raw in hourlyRaw)
          if (raw is Map)
            BatteryLabHourly.fromJson(raw.cast<String, dynamic>()),
      ],
      generatedAt: (json['generated_at'] ?? '').toString(),
    );
  }

  final BatteryLabScope scope;
  final Map<String, dynamic>? latest;
  final BatteryInsights insights;
  final BatteryDetails details;
  final List<BatteryLabHourly> hourly;
  final String generatedAt;
}

class BatteryLabScope {
  const BatteryLabScope({
    required this.mode,
    required this.deviceId,
    required this.deviceName,
  });

  factory BatteryLabScope.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return BatteryLabScope(
      mode: (j['mode'] ?? '').toString(),
      deviceId: j['device_id'] is int ? j['device_id'] as int : null,
      deviceName: (j['device_name'] ?? '').toString().isEmpty
          ? null
          : j['device_name'].toString(),
    );
  }

  final String mode;
  final int? deviceId;
  final String? deviceName;
  bool get isAllDevices => mode == 'all';
}

/// Mirrors the server's `battery_insights` dict
/// (`helpers.build_battery_insights` → v93l..v93s + v93q).
class BatteryInsights {
  const BatteryInsights({
    required this.capacityKwh,
    required this.reservePercent,
    required this.reserveKwh,
    required this.storedKwh,
    required this.usableNowKwh,
    required this.remainingToFullKwh,
    required this.modeLabel,
    required this.chargeEta,
    required this.dischargeEta,
    required this.chargePowerW,
    required this.dischargePowerW,
    required this.liveFlowW,
    required this.liveFlowLabel,
    required this.liveFlowDirection,
    required this.activeTimeCaption,
    required this.activeTimeLabel,
    required this.dailyChargeKwh,
    required this.dailyDischargeKwh,
    required this.externalAcInputW,
    required this.feedInW,
    required this.gridInputW,
    required this.generatorInputW,
    required this.acInSourceLabel,
    required this.gridStatusLabel,
    required this.gridRelayStatusLabel,
    required this.dailyGeneratorKwh,
    required this.totalGeneratorKwh,
    required this.stationGenerationW,
    required this.inferredExternalW,
  });

  factory BatteryInsights.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    double n(String key) {
      final v = j[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    double? nNullable(String key) {
      final v = j[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    String s(String key) {
      final v = j[key];
      if (v == null) return '';
      return v.toString();
    }

    return BatteryInsights(
      capacityKwh: n('capacity_kwh'),
      reservePercent: n('reserve_percent'),
      reserveKwh: n('reserve_kwh'),
      storedKwh: n('stored_kwh'),
      usableNowKwh: n('usable_now_kwh'),
      remainingToFullKwh: n('remaining_to_full_kwh'),
      modeLabel: s('mode_label'),
      chargeEta: s('charge_eta'),
      dischargeEta: s('discharge_eta'),
      chargePowerW: n('charge_power_w'),
      dischargePowerW: n('discharge_power_w'),
      liveFlowW: n('live_flow_w'),
      liveFlowLabel: s('live_flow_label'),
      liveFlowDirection: s('live_flow_direction'),
      activeTimeCaption: s('active_time_caption'),
      activeTimeLabel: s('active_time_label'),
      dailyChargeKwh: nNullable('daily_charge_kwh'),
      dailyDischargeKwh: nNullable('daily_discharge_kwh'),
      externalAcInputW: n('external_ac_input_w'),
      feedInW: n('feed_in_w'),
      gridInputW: n('grid_input_w'),
      generatorInputW: n('generator_input_w'),
      acInSourceLabel: s('ac_in_source_label'),
      gridStatusLabel: s('grid_status_label'),
      gridRelayStatusLabel: s('grid_relay_status_label'),
      dailyGeneratorKwh: nNullable('daily_generator_kwh'),
      totalGeneratorKwh: nNullable('total_generator_kwh'),
      stationGenerationW: nNullable('station_generation_w'),
      inferredExternalW: nNullable('inferred_external_w'),
    );
  }

  final double capacityKwh;
  final double reservePercent;
  final double reserveKwh;
  final double storedKwh;
  final double usableNowKwh;
  final double remainingToFullKwh;
  final String modeLabel;
  final String chargeEta;
  final String dischargeEta;
  final double chargePowerW;
  final double dischargePowerW;
  final double liveFlowW;
  final String liveFlowLabel;
  final String liveFlowDirection; // 'charging' | 'discharging' | 'idle'
  final String activeTimeCaption;
  final String activeTimeLabel;
  final double? dailyChargeKwh;
  final double? dailyDischargeKwh;
  final double externalAcInputW;
  final double feedInW;
  final double gridInputW;
  final double generatorInputW;
  final String acInSourceLabel;
  final String gridStatusLabel;
  final String gridRelayStatusLabel;
  final double? dailyGeneratorKwh;
  final double? totalGeneratorKwh;
  final double? stationGenerationW;
  final double? inferredExternalW;

  /// Convenience getter for the SoC percent (0..100).
  double get socPercent {
    if (capacityKwh <= 0) return 0;
    return ((storedKwh / capacityKwh) * 100).clamp(0, 100).toDouble();
  }
}

/// Mirrors the server's `battery_details` dict
/// (`helpers.build_battery_details`).
class BatteryDetails {
  const BatteryDetails({
    required this.batteryVoltage,
    required this.batteryCurrent,
    required this.batteryTemp,
    required this.batteryCycles,
    required this.batterySoh,
    required this.batteryStatus,
    required this.batteryHealth,
    required this.batteryTotalCapacityAh,
    required this.batteryType,
    required this.batteryCapacityAh,
    required this.batterySnMain,
    required this.batterySnModule,
  });

  factory BatteryDetails.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    double? n(String key) {
      final v = j[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    String s(String key) {
      final v = j[key];
      if (v == null) return '';
      return v.toString();
    }

    int? iVal(String key) {
      final v = j[key];
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return BatteryDetails(
      batteryVoltage: n('battery_voltage'),
      batteryCurrent: n('battery_current'),
      batteryTemp: n('battery_temp'),
      batteryCycles: iVal('battery_cycles'),
      batterySoh: n('battery_soh'),
      batteryStatus: s('battery_status'),
      batteryHealth: n('battery_health'),
      batteryTotalCapacityAh: n('battery_total_capacity_ah'),
      batteryType: s('battery_type'),
      batteryCapacityAh: n('battery_capacity_ah'),
      batterySnMain: s('battery_sn_main'),
      batterySnModule: s('battery_sn_module'),
    );
  }

  final double? batteryVoltage;
  final double? batteryCurrent;
  final double? batteryTemp;
  final int? batteryCycles;
  final double? batterySoh;
  final String batteryStatus;
  final double? batteryHealth;
  final double? batteryTotalCapacityAh;
  final String batteryType;
  final double? batteryCapacityAh;
  final String batterySnMain;
  final String batterySnModule;
}

class BatteryLabHourly {
  const BatteryLabHourly({
    required this.timeLabel,
    required this.timeIso,
    required this.soc,
    required this.powerW,
    required this.voltage,
    required this.current,
  });

  factory BatteryLabHourly.fromJson(Map<String, dynamic> json) {
    double? n(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return BatteryLabHourly(
      timeLabel: (json['time_label'] ?? '').toString(),
      timeIso: (json['time_iso'] ?? '').toString(),
      soc: n('soc') ?? 0,
      powerW: n('power_w') ?? 0,
      voltage: n('voltage'),
      current: n('current'),
    );
  }

  final String timeLabel;
  final String timeIso;
  final double soc;
  final double powerW;
  final double? voltage;
  final double? current;
}
