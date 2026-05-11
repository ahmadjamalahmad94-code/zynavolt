import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'device_detail_models.dart';

class DeviceDetailRepository {
  DeviceDetailRepository(this._api);

  final ApiClient _api;

  Future<DeviceDetailSnapshot> fetch(int deviceId) async {
    final response = await _api.get('/api/mobile/devices/$deviceId');
    return DeviceDetailSnapshot.fromJson(response.data);
  }
}

final deviceDetailRepositoryProvider =
    Provider<DeviceDetailRepository>((ref) {
  return DeviceDetailRepository(ref.watch(apiClientProvider));
});

/// Per-id provider so multiple device-detail views (or a navigated-back-to
/// view) reuse the same in-flight fetch and result without colliding.
final deviceDetailProvider =
    FutureProvider.family<DeviceDetailSnapshot, int>((ref, id) {
  return ref.watch(deviceDetailRepositoryProvider).fetch(id);
});
