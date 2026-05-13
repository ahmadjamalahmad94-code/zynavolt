import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'device_provider_models.dart';

/// v48: thin client for `GET /api/mobile/device-providers`. Used by the
/// add-device flow's provider picker. The backend already returns
/// every catalog entry with v45 support-tier fields, so this layer is
/// pure parsing — no client-side merging or sorting.
class DeviceProvidersRepository {
  DeviceProvidersRepository(this._api);

  final ApiClient _api;

  Future<List<ProviderOption>> list() async {
    final response = await _api.get('/api/mobile/device-providers');
    final items = (response.data['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ProviderOption.fromJson)
        .where((p) => p.code.isNotEmpty)
        .toList(growable: false);
  }
}

final deviceProvidersRepositoryProvider =
    Provider<DeviceProvidersRepository>((ref) {
  return DeviceProvidersRepository(ref.watch(apiClientProvider));
});

/// v48: lazily-loaded list of providers for the picker. The provider
/// catalog is small (~20 entries) and never changes mid-session, so
/// one fetch per app launch is enough — the FutureProvider caches it
/// until the user invalidates.
final deviceProvidersListProvider =
    FutureProvider<List<ProviderOption>>((ref) {
  return ref.watch(deviceProvidersRepositoryProvider).list();
});
