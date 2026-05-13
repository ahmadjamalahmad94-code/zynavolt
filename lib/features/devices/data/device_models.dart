/// Mirror of GET /api/mobile/devices items.
///
/// Identifiers are masked by the backend by default — we store the masked
/// values as-is and never attempt to unmask client-side.
class Device {
  Device({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.apiProvider,
    required this.connectionStatus,
    required this.lastConnectedAt,
    required this.isActive,
    required this.plantName,
    required this.timezone,
    this.providerSupportTier,
    this.providerSupportTierLabel,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: (json['id'] ?? 0) as int,
        name: (json['name'] ?? '').toString(),
        deviceType: (json['device_type'] ?? '').toString(),
        apiProvider: (json['api_provider'] ?? '').toString(),
        connectionStatus: (json['connection_status'] ?? '').toString(),
        lastConnectedAt: json['last_connected_at']?.toString(),
        isActive: json['is_active'] == true,
        plantName: (json['plant_name'] ?? '').toString(),
        timezone: (json['timezone'] ?? '').toString(),
        // v45 additive: backend now embeds the provider readiness tier
        // straight into the device row so the detail screen can render
        // a small Arabic badge without a separate fetch to
        // /api/mobile/device-providers. Both fields are `null` on
        // older backends or for devices whose provider code is
        // unknown — the UI hides the badge in that case.
        providerSupportTier: _optionalString(json['provider_support_tier']),
        providerSupportTierLabel:
            _optionalString(json['provider_support_tier_label']),
      );

  final int id;
  final String name;
  final String deviceType;
  final String apiProvider;
  final String connectionStatus;
  final String? lastConnectedAt;
  final bool isActive;
  final String plantName;
  final String timezone;

  /// Structured tier value (v45): `live-supported` / `beta-supported` /
  /// `blueprint-only`. `null` when the backend predates v45 or the
  /// device's provider code is unknown to the catalog.
  final String? providerSupportTier;

  /// Polished Arabic label for the tier (already localised by the
  /// backend). `null` under the same conditions as
  /// [providerSupportTier]; the UI must hide the badge when null.
  final String? providerSupportTierLabel;
}

/// Returns the trimmed string when [raw] is a non-empty string, else
/// `null`. Keeps the v45 optional fields cleanly absent when the
/// backend does not provide them.
String? _optionalString(Object? raw) {
  if (raw is! String) return null;
  final t = raw.trim();
  return t.isEmpty ? null : t;
}
