import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_models.dart';
import '../../features/auth/data/auth_repository.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../storage/secure_token_storage.dart';

/// Coarse auth phase that drives the router. The unknown phase exists so we
/// can show a splash while we resolve tokens at cold start without flashing
/// the login screen.
enum AppSessionPhase { unknown, unauthenticated, authenticated }

class AppSessionState {
  const AppSessionState({
    required this.phase,
    this.user,
    this.lastError,
  });

  const AppSessionState.unknown()
      : phase = AppSessionPhase.unknown,
        user = null,
        lastError = null;

  const AppSessionState.unauthenticated({this.lastError})
      : phase = AppSessionPhase.unauthenticated,
        user = null;

  const AppSessionState.authenticated(AuthUser this.user)
      : phase = AppSessionPhase.authenticated,
        lastError = null;

  final AppSessionPhase phase;
  final AuthUser? user;
  final ApiException? lastError;
}

/// Singleton-ish secure storage. We create one instance and reuse it.
final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

/// Wires the ApiClient to storage + the session expiry hook. The hook is a
/// callback (not a direct provider read) so the client never imports UI code.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureTokenStorageProvider);
  final client = ApiClient(
    tokenStorage: storage,
    onSessionExpired: () {
      // Refresh-token rotation failed; let the session controller drop the
      // user back to unauthenticated.
      ref.read(appSessionProvider.notifier).onSessionExpired();
    },
  );
  return client;
});

final appSessionProvider =
    StateNotifierProvider<AppSessionController, AppSessionState>((ref) {
  return AppSessionController(ref);
});

class AppSessionController extends StateNotifier<AppSessionState> {
  AppSessionController(this._ref) : super(const AppSessionState.unknown()) {
    // Resolve session on construction; the splash screen waits on this.
    // ignore: discarded_futures
    restore();
  }

  final Ref _ref;

  AuthRepository get _auth => _ref.read(authRepositoryProvider);
  SecureTokenStorage get _storage => _ref.read(secureTokenStorageProvider);

  /// Boot flow:
  /// 1. If we have an access token, call `/auth/me`. Success → authenticated.
  /// 2. On 401 / invalid token, try to refresh and re-fetch `/auth/me`.
  /// 3. Otherwise unauthenticated.
  Future<void> restore() async {
    try {
      final access = await _storage.readAccessToken();
      if (access == null || access.isEmpty) {
        state = const AppSessionState.unauthenticated();
        return;
      }
      final user = await _auth.fetchMe();
      state = AppSessionState.authenticated(user);
    } on ApiException catch (e) {
      if (e.isAuth) {
        // The api client interceptor already attempted a refresh; if we
        // landed here it failed.
        await _storage.clearAll();
        state = const AppSessionState.unauthenticated();
      } else {
        // Network/server problem at cold start — surface but keep the
        // unknown phase so the splash can offer a retry.
        state = AppSessionState.unauthenticated(lastError: e);
      }
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
    String? deviceLabel,
  }) async {
    try {
      final result = await _auth.login(
        username: username,
        password: password,
        deviceLabel: deviceLabel,
      );
      await _storage.writeTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      final user = await _auth.fetchMe();
      state = AppSessionState.authenticated(user);
    } on ApiException catch (e) {
      state = AppSessionState.unauthenticated(lastError: e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final refresh = await _storage.readRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        // Best-effort revoke. Failure here is non-fatal: we still drop the
        // local tokens.
        await _auth.logout(refreshToken: refresh);
      }
    } on ApiException {
      // ignore — we are signing out anyway
    } finally {
      await _storage.clearAll();
      state = const AppSessionState.unauthenticated();
    }
  }

  void onSessionExpired() {
    state = const AppSessionState.unauthenticated();
  }
}

/// Convenience wrapper so widgets can `ref.watch(appSessionProvider)` and
/// receive the state directly without manually unwrapping the controller.
final appSessionStateProvider = Provider<AppSessionState>((ref) {
  // ignore: avoid_redundant_argument_values
  return ref.watch(appSessionProvider);
});

// Lets `state.phase` be read elsewhere.
extension AppSessionStateX on AppSessionState {
  bool get isAuthenticated => phase == AppSessionPhase.authenticated;
  bool get isUnknown => phase == AppSessionPhase.unknown;
  bool get isUnauthenticated => phase == AppSessionPhase.unauthenticated;
}

extension AppSessionPhaseRead on AppSessionState {
  AppSessionPhase get phaseOnly => phase;
}
