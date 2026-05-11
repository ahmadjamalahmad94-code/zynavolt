import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'auth_models.dart';

/// Skeleton repository for the /api/mobile/auth/* surface.
///
/// Only the calls that the v37 foundation actually needs are implemented:
/// login, logout, refresh-on-demand, and fetch-me. Register and password
/// change come in later phases (v37 ships infrastructure, not full UI).
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthLoginResult> login({
    required String username,
    required String password,
    String? deviceLabel,
  }) async {
    final response = await _api.post(
      '/api/mobile/auth/login',
      body: {
        'username': username,
        'password': password,
        if (deviceLabel != null && deviceLabel.isNotEmpty)
          'device_label': deviceLabel,
      },
      options: ApiClient.skipAuth(),
    );
    return AuthLoginResult.fromJson(response.data);
  }

  Future<void> logout({required String refreshToken}) async {
    await _api.post(
      '/api/mobile/auth/logout',
      body: {'refresh_token': refreshToken},
      options: ApiClient.skipAuth(),
    );
  }

  Future<AuthUser> fetchMe() async {
    final response = await _api.get('/api/mobile/auth/me');
    return AuthUser.fromJson(response.data);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthRepository(api);
});
