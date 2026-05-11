import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'account_models.dart';

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  /// GET /api/mobile/account — single payload with user, role,
  /// subscription, device counts, and capabilities. v51 is read-only;
  /// PATCH / change-password / logout-all / delete endpoints exist on the
  /// backend but are NOT wired here.
  Future<AccountSnapshot> fetch() async {
    final response = await _api.get('/api/mobile/account');
    return AccountSnapshot.fromJson(response.data);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(apiClientProvider));
});

final accountSnapshotProvider = FutureProvider<AccountSnapshot>((ref) {
  return ref.watch(accountRepositoryProvider).fetch();
});
