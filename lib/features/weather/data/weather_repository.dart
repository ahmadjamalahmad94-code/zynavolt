import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import '../../devices/state/selected_device_provider.dart';
import 'weather_models.dart';

/// v63: thin client for the v62 weather endpoint under
/// `mobile_devices_api_bp`. Owner-scoped server-side (same
/// `_device_allowed` guard as the v52 history / v56 statistics /
/// v59 reports endpoints), so the mobile repository does no
/// filtering — a 404 from the backend means the device isn't on
/// the user's account.
class WeatherRepository {
  WeatherRepository(this._api);

  final ApiClient _api;

  /// `GET /api/v1/devices/<id>/weather`
  ///
  /// Backend always responds 200 for the non-fatal "weather not
  /// available right now" cases; `available=false` plus a stable
  /// `reason` code carries the contract. Auth (401) / owner-scope
  /// (404) errors still come through as `ApiException`.
  Future<WeatherSnapshot> fetch({required int deviceId}) async {
    final response = await _api.get('/api/v1/devices/$deviceId/weather');
    return WeatherSnapshot.fromJson(response.data);
  }
}

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(ref.watch(apiClientProvider));
});

/// Weather snapshot for the currently-selected device. Re-fetches
/// when the user picks a different device (via the existing
/// `effectiveDeviceIdProvider`). Returns `null` while the devices
/// list is still loading and no other signal is available — the
/// screen renders the no-device empty state in that case rather
/// than triggering a fetch with an undefined id.
final weatherProvider = FutureProvider<WeatherSnapshot?>((ref) async {
  final deviceId = ref.watch(effectiveDeviceIdProvider);
  if (deviceId == null) return null;
  return ref.watch(weatherRepositoryProvider).fetch(deviceId: deviceId);
});
