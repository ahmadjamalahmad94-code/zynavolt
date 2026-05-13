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

  /// v54: subscriber self-registration via `POST /api/mobile/auth/register`.
  ///
  /// Backend whitelist (verified against `mobile_register` in
  /// `web/app/blueprints/mobile_auth_api.py:80`):
  ///   * ``username`` — required, ≥3 chars; 409 on duplicate
  ///     (`username_taken`).
  ///   * ``password`` — required, ≥6 chars.
  ///   * ``email`` — optional; 409 on duplicate (`email_taken`).
  ///   * ``full_name`` — optional; trimmed server-side.
  ///   * ``preferred_language`` — optional, normalised to ar/en;
  ///     defaults to ar.
  ///   * ``device_label`` — optional; recorded on the issued refresh
  ///     token so it shows in the user's device list on web.
  ///
  /// Several additional fields exist on the backend
  /// (`country_code`, `city`, `timezone`, `phone_country_code`,
  /// `phone_number`, `has_energy_system`, `preferred_device_type`)
  /// but the v54 mobile register screen keeps the form minimal — the
  /// user fills those in afterwards through the existing onboarding
  /// flow (which already routes through `/profile` + the add-device
  /// surface). The backend safely defaults what isn't provided:
  /// `has_energy_system=yes`, `preferred_device_type='deye'`,
  /// `timezone='Asia/Hebron'`, `preferred_language='ar'`.
  ///
  /// Response shape mirrors login (`token_payload`) so the caller
  /// reuses the same session-establishment path; the extra `user`
  /// and `onboarding` keys in the response are ignored here — the
  /// session controller will refetch `/auth/me` immediately after
  /// writing tokens, same as the login path.
  Future<AuthLoginResult> register({
    required String username,
    required String password,
    String? fullName,
    String? email,
    String? preferredLanguage,
    String? deviceLabel,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'password': password,
    };
    if (fullName != null && fullName.trim().isNotEmpty) {
      body['full_name'] = fullName.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    if (preferredLanguage != null && preferredLanguage.trim().isNotEmpty) {
      body['preferred_language'] = preferredLanguage.trim();
    }
    if (deviceLabel != null && deviceLabel.isNotEmpty) {
      body['device_label'] = deviceLabel;
    }
    final response = await _api.post(
      '/api/mobile/auth/register',
      body: body,
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
