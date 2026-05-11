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
}

final bootstrapRepositoryProvider = Provider<BootstrapRepository>((ref) {
  return BootstrapRepository(ref.watch(apiClientProvider));
});

/// Lazy fetch — screens that want the bootstrap payload `ref.watch` this
/// FutureProvider and get caching + auto-refresh on retry for free.
final bootstrapProvider = FutureProvider<AppBootstrap>((ref) {
  return ref.watch(bootstrapRepositoryProvider).fetch();
});
