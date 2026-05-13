import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import '../../devices/state/selected_device_provider.dart';
import 'insights_models.dart';

/// v75: thin client for the v74 smart-insights endpoint under
/// `mobile_devices_api_bp`. Owner-scoped server-side (same
/// `_device_allowed` guard as `/history`, `/statistics`,
/// `/reports/summary`, `/weather`), so the mobile repository does
/// no filtering — a 404 from the backend means the device isn't on
/// the user's account.
class InsightsRepository {
  InsightsRepository(this._api);

  final ApiClient _api;

  /// `GET /api/v1/devices/<id>/insights`
  ///
  /// Backend always responds 200 for the non-fatal unavailable
  /// cases (`reading_unavailable` / `station_coords_unavailable` /
  /// `weather_unreachable`). Auth (401) / owner-scope (404) still
  /// surface as `ApiException`.
  Future<InsightsSnapshot> fetch({required int deviceId}) async {
    final response = await _api.get('/api/v1/devices/$deviceId/insights');
    return InsightsSnapshot.fromJson(response.data);
  }
}

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(ref.watch(apiClientProvider));
});

/// Insights snapshot for the currently-selected device. Returns
/// `null` while the devices list is still loading and no other
/// signal is available — the Home card renders nothing rather
/// than firing a fetch with an undefined id. Re-fetches when the
/// user switches the active device.
final insightsProvider = FutureProvider<InsightsSnapshot?>((ref) async {
  final deviceId = ref.watch(effectiveDeviceIdProvider);
  if (deviceId == null) return null;
  return ref.watch(insightsRepositoryProvider).fetch(deviceId: deviceId);
});
