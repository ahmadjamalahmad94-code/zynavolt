import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'bootstrap_models.dart';

class BootstrapRepository {
  BootstrapRepository(this._api);

  final ApiClient _api;

  Future<AppBootstrap> fetch() async {
    final response = await _api.get('/api/mobile/bootstrap');
    return AppBootstrap.fromJson(response.data);
  }

  /// `GET /api/mobile/health` — unauthenticated probe used by the
  /// "تحقّق من الاتصال" diagnostic in the More tab. Sends no Bearer
  /// header so a stale/missing token does not produce a misleading 401.
  Future<HealthStatus> health() async {
    final response = await _api.get(
      '/api/mobile/health',
      options: ApiClient.skipAuth(),
    );
    return HealthStatus.fromJson(response.data);
  }
}

final bootstrapRepositoryProvider = Provider<BootstrapRepository>((ref) {
  return BootstrapRepository(ref.watch(apiClientProvider));
});

/// Lazy fetch — screens that want the bootstrap payload `ref.watch` this
/// FutureProvider and get caching + auto-refresh on retry for free.
final bootstrapProvider = FutureProvider<AppBootstrap>((ref) {
  return ref.watch(bootstrapRepositoryProvider).fetch();
});
