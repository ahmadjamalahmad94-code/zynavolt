import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'load_models.dart';

class LoadsRepository {
  LoadsRepository(this._api);

  final ApiClient _api;

  /// `deviceId` is forwarded to the backend as `?device_id=…` when present.
  /// If omitted, the backend returns the user's full catalog with
  /// `scope.mode = "all"`.
  Future<LoadsPage> list({int? deviceId}) async {
    final response = await _api.get(
      '/api/mobile/loads',
      query: deviceId != null ? {'device_id': deviceId} : null,
    );
    return LoadsPage.fromJson(response.data);
  }
}

final loadsRepositoryProvider = Provider<LoadsRepository>((ref) {
  return LoadsRepository(ref.watch(apiClientProvider));
});

/// v48 reads the user's full load catalog (no device filter). The screen
/// renders the scope honestly so the user isn't misled into thinking the
/// list is filtered to the active device.
final loadsListProvider = FutureProvider<LoadsPage>((ref) {
  return ref.watch(loadsRepositoryProvider).list();
});
