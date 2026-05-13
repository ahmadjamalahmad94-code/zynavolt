import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import '../../devices/state/selected_device_provider.dart';
import 'battery_lab_models.dart';

/// v100 — Battery Lab repository / Riverpod provider.
///
/// Calls `GET /api/mobile/battery-lab?device_id=<id>` and maps the
/// JSON into `BatteryLabSnapshot`. Provider auto-refetches whenever
/// the effective selected device changes — same pattern as the
/// dashboard / insights providers.
class BatteryLabRepository {
  BatteryLabRepository(this._api);

  final ApiClient _api;

  Future<BatteryLabSnapshot> fetch({int? deviceId}) async {
    final response = await _api.get(
      '/api/mobile/battery-lab',
      query: {
        'device_id': ?deviceId,
      },
    );
    // ApiClient.get returns `ApiResponse<Map<String, dynamic>>`, so
    // `response.data` is already a typed map — no defensive cast.
    return BatteryLabSnapshot.fromJson(response.data);
  }
}

final batteryLabRepositoryProvider = Provider<BatteryLabRepository>((ref) {
  return BatteryLabRepository(ref.watch(apiClientProvider));
});

final batteryLabProvider = FutureProvider<BatteryLabSnapshot>((ref) async {
  final deviceId = ref.watch(effectiveDeviceIdProvider);
  return ref.watch(batteryLabRepositoryProvider).fetch(deviceId: deviceId);
});
