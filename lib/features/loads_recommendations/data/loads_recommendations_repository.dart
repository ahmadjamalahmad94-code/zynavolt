import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import '../../devices/state/selected_device_provider.dart';
import 'loads_recommendations_models.dart';

/// Thin client for `GET /api/mobile/loads/recommendations` (Heavy
/// v10.5.35+). Owner-scoped on the backend; passing `device_id`
/// pins the recommendation to that device's latest reading +
/// weather. When `device_id` is null the backend falls back to
/// the user's first active device.
class LoadsRecommendationsRepository {
  LoadsRecommendationsRepository(this._api);

  final ApiClient _api;

  Future<LoadsRecommendationsSnapshot> fetch({int? deviceId}) async {
    final response = await _api.get(
      '/api/mobile/loads/recommendations',
      query: {
        'device_id': ?deviceId,
      },
    );
    return LoadsRecommendationsSnapshot.fromJson(response.data);
  }
}

final loadsRecommendationsRepositoryProvider =
    Provider<LoadsRecommendationsRepository>((ref) {
  return LoadsRecommendationsRepository(ref.watch(apiClientProvider));
});

/// Loads recommendations for the currently-selected device.
/// Returns `null` while devices are still loading and no device
/// id is known — the strip then renders nothing rather than
/// firing with an undefined id. Re-fetches when the user switches
/// devices.
final loadsRecommendationsProvider =
    FutureProvider<LoadsRecommendationsSnapshot?>((ref) async {
  final deviceId = ref.watch(effectiveDeviceIdProvider);
  if (deviceId == null) return null;
  return ref
      .read(loadsRecommendationsRepositoryProvider)
      .fetch(deviceId: deviceId);
});
