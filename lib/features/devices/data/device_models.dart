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
}
