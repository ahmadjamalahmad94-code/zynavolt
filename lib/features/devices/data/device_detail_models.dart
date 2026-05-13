// Mirror of GET /api/mobile/devices/<id> data envelope.
//
// Field names are taken verbatim from the backend payload builder
// (`_mobile_device_detail_payload` + `_mobile_reading_payload`/`_mobile_reading_cards`
// in `app/blueprints/mobile_api.py`). All numeric values come from the
// server's `cards` block — already passed through `_reading_number()` —
// so the mobile app never re-derives or reinterprets them.
//
// Security note (v47):
// `auth_mode` is part of the backend payload but is intentionally NOT
// surfaced in the model. It describes how credentials are stored
// server-side and has no UX value to the end user. Skipping it here means
// no screen can accidentally render it.

class DeviceDetail {
  DeviceDetail({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.apiProvider,
    required this.connectionStatus,
    required this.lastConnectedAt,
    required this.isActive,
    required this.plantName,
    required this.timezone,
    required this.createdAt,
    required this.updatedAt,
    required this.safeSettings,
    this.providerSupportTier,
    this.providerSupportTierLabel,
  });

  factory DeviceDetail.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    final rawSettings = j['safe_settings'];
    final settings = <String, String>{};
    if (rawSettings is Map) {
      rawSettings.forEach((key, value) {
        if (key == null || value == null) return;
        final k = key.toString();
        final v = value.toString();
        if (k.isEmpty || v.isEmpty) return;
        settings[k] = v;
      });
    }
    return DeviceDetail(
      id: (j['id'] is int) ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
      name: (j['name'] ?? '').toString(),
      deviceType: (j['device_type'] ?? '').toString(),
      apiProvider: (j['api_provider'] ?? '').toString(),
      connectionStatus: (j['connection_status'] ?? '').toString(),
      lastConnectedAt: j['last_connected_at']?.toString(),
      isActive: j['is_active'] == true,
      plantName: (j['plant_name'] ?? '').toString(),
      timezone: (j['timezone'] ?? '').toString(),
      createdAt: j['created_at']?.toString(),
      updatedAt: j['updated_at']?.toString(),
      safeSettings: settings,
      // v45 additive: see `device_models.dart` for the contract notes.
      providerSupportTier:
          _optionalString(j['provider_support_tier']),
      providerSupportTierLabel:
          _optionalString(j['provider_support_tier_label']),
    );
  }

  final int id;
  final String name;
  final String deviceType;
  final String apiProvider;
  final String connectionStatus;
  final String? lastConnectedAt;
  final bool isActive;
  final String plantName;
  final String timezone;
  final String? createdAt;
  final String? updatedAt;

  /// Whitelisted public settings from the backend `_SAFE_DEVICE_SETTING_KEYS`
  /// set (battery_capacity_kwh, battery_reserve_percent). Empty when the
  /// device has no safe settings configured.
  final Map<String, String> safeSettings;

  /// Structured tier value (v45). See `device_models.dart` for the
  /// fallback semantics.
  final String? providerSupportTier;

  /// Polished Arabic label for the tier. Null when the backend
  /// predates v45 or the device's provider code is unknown.
  final String? providerSupportTierLabel;
}

String? _optionalString(Object? raw) {
  if (raw is! String) return null;
  final t = raw.trim();
  return t.isEmpty ? null : t;
}

/// Latest reading summary for a single device. Mirrors the `cards` block of
/// the detail payload — all values are server-computed via
/// `_reading_number()`. `hasReading` is `false` when `latest` is null in
/// the payload (i.e., the device has not reported yet).
class DeviceLatestSummary {
  DeviceLatestSummary({
    required this.hasReading,
    required this.createdAt,
    required this.statusText,
    required this.solarPowerW,
    required this.homeLoadW,
    required this.batterySocPercent,
    required this.batteryPowerW,
    required this.gridPowerW,
  });

  factory DeviceLatestSummary.fromJson({
    required Map<String, dynamic>? latest,
    required Map<String, dynamic>? cards,
  }) {
    final hasReading = latest != null;
    final l = latest ?? const <String, dynamic>{};
    final c = cards ?? const <String, dynamic>{};
    double n(String key) {
      final v = c[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return DeviceLatestSummary(
      hasReading: hasReading,
      createdAt: l['created_at']?.toString(),
      statusText: (l['status_text'] ?? '').toString(),
      solarPowerW: n('solar_power_w'),
      homeLoadW: n('home_load_w'),
      batterySocPercent: n('battery_soc_percent'),
      batteryPowerW: n('battery_power_w'),
      gridPowerW: n('grid_power_w'),
    );
  }

  static DeviceLatestSummary empty() => DeviceLatestSummary(
        hasReading: false,
        createdAt: null,
        statusText: '',
        solarPowerW: 0,
        homeLoadW: 0,
        batterySocPercent: 0,
        batteryPowerW: 0,
        gridPowerW: 0,
      );

  final bool hasReading;
  final String? createdAt;
  final String statusText;
  final double solarPowerW;
  final double homeLoadW;
  final double batterySocPercent;
  final double batteryPowerW;
  final double gridPowerW;
}

class DeviceDetailSnapshot {
  DeviceDetailSnapshot({required this.device, required this.latest});

  factory DeviceDetailSnapshot.fromJson(Map<String, dynamic> json) {
    return DeviceDetailSnapshot(
      device: DeviceDetail.fromJson(
        (json['device'] as Map?)?.cast<String, dynamic>(),
      ),
      latest: DeviceLatestSummary.fromJson(
        latest: (json['latest'] as Map?)?.cast<String, dynamic>(),
        cards: (json['cards'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  final DeviceDetail device;
  final DeviceLatestSummary latest;
}
