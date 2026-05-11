import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import '../../devices/state/selected_device_provider.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._api);

  final ApiClient _api;

  /// `GET /api/mobile/dashboard?device_id=<id>` — when [deviceId] is null,
  /// the backend resolves to the user's preferred device. Passing the
  /// effective id from [selectedDeviceProvider] keeps the mobile selection
  /// in sync with the rendered data.
  Future<DashboardSnapshot> fetch({int? deviceId}) async {
    final response = await _api.get(
      '/api/mobile/dashboard',
      query: {
        'device_id': ?deviceId,
      },
    );
    return DashboardSnapshot.fromJson(response.data);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

/// Active dashboard snapshot, scoped to the effective selected device.
/// Re-fetches automatically when the user picks a different device.
final dashboardProvider = FutureProvider<DashboardSnapshot>((ref) async {
  final deviceId = ref.watch(effectiveDeviceIdProvider);
  return ref.watch(dashboardRepositoryProvider).fetch(deviceId: deviceId);
});
