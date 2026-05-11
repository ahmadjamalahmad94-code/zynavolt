import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'account_models.dart';

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  /// GET /api/mobile/account — single payload with user, role,
  /// subscription, device counts, and capabilities.
  Future<AccountSnapshot> fetch() async {
    final response = await _api.get('/api/mobile/account');
    return AccountSnapshot.fromJson(response.data);
  }

  /// v89: `POST /api/mobile/account/change-password` with
  /// `{current_password, new_password}`. Returns `{changed: true}` on
  /// success, or throws an [ApiException] (e.g. `invalid_current_password`,
  /// `weak_password`, `missing_field`).
  ///
  /// Passwords are never logged or cached.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/api/mobile/account/change-password',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  /// v89: `POST /api/mobile/account/logout-all` — revokes every refresh
  /// token issued to the user. The active access token stays valid until
  /// it naturally expires (the backend marks this in
  /// `access_tokens_revoked: false`). Returns the count of revoked
  /// refresh tokens.
  Future<int> logoutAll() async {
    final response = await _api.post(
      '/api/mobile/account/logout-all',
      body: const <String, dynamic>{},
    );
    final v = response.data['revoked_refresh_tokens'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(apiClientProvider));
});

final accountSnapshotProvider = FutureProvider<AccountSnapshot>((ref) {
  return ref.watch(accountRepositoryProvider).fetch();
});
