import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'device_models.dart';

class DevicesRepository {
  DevicesRepository(this._api);

  final ApiClient _api;

  Future<List<Device>> list({int page = 1, int pageSize = 30}) async {
    final response = await _api.get(
      '/api/mobile/devices',
      query: {'page': page, 'page_size': pageSize},
    );
    final items = (response.data['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Device.fromJson)
        .toList();
  }
}

final devicesRepositoryProvider = Provider<DevicesRepository>((ref) {
  return DevicesRepository(ref.watch(apiClientProvider));
});

final devicesListProvider = FutureProvider<List<Device>>((ref) {
  return ref.watch(devicesRepositoryProvider).list();
});
