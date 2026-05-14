import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../state/app_session.dart';

/// v101 — FCM lifecycle controller for the foreground app.
///
/// Responsibilities:
///   1. Request notification permission on first attempt (Android 13+
///      requires this; older versions auto-grant).
///   2. Fetch the per-install FCM token.
///   3. Listen for token refresh events (Google rotates them
///      occasionally).
///   4. Forward the token to the backend so server-side rule
///      processing can dispatch FCM sends to this device.
///   5. Surface foreground messages so screens can react in-app.
///
/// What this file deliberately does NOT do (yet — landing in
/// follow-up commits):
///   * Show in-app banners for foreground messages.
///   * Deep-link from a tapped notification to the relevant screen.
///   * Persist a "push enabled?" preference — for now the user opts
///     in by tapping the system permission prompt; we always try to
///     register on launch.
///
/// Backend contract (already shipped on the backend):
///   `POST   /api/v1/notifications/push-tokens`  → register / refresh.
///   `DELETE /api/v1/notifications/push-tokens`  → revoke.
/// Body for both: `{ "token": "[fcm]", "platform": "android",
/// "device_label"?: str, "app_version"?: str }`. The endpoint stores
/// / refreshes the row keyed on (user_id, sha256(token)).
///
/// Note: an earlier draft of this file referenced
/// `/api/mobile/account/push-token`. The backend already exposed
/// the equivalent endpoints under `/api/v1/notifications/...`, so
/// we use those instead of duplicating.
class PushService {
  PushService(this._ref);

  final Ref _ref;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  /// Latest known token. `null` while we haven't fetched it yet, or
  /// when the user has revoked notification permission.
  String? _currentToken;
  String? get currentToken => _currentToken;

  /// One-shot bootstrap. Called from a Riverpod provider so the
  /// lifecycle is tied to the app's container disposal.
  ///
  /// On cold start the user is almost always unauthenticated for the
  /// first frame — `appSessionProvider` is still in the `unknown`
  /// phase while it restores tokens from secure storage. So we:
  ///
  ///   1. Request notification permission immediately (cheap).
  ///   2. Fetch the FCM token immediately (independent of auth).
  ///   3. Try a backend register — if no bearer is set yet the
  ///      request fails with 401 (caught, logged) and we move on.
  ///   4. Subscribe to session changes via `pushServiceProvider`;
  ///      every transition into the authenticated phase fires a
  ///      retry of the register through [registerCurrentTokenIfReady].
  ///
  /// Net effect: a cold-started user opening the app gets the system
  /// permission prompt right away, and the moment they finish the
  /// login screen the token lands on the backend — no manual
  /// hot-restart required.
  Future<void> start() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint(
        '[push] permission=${settings.authorizationStatus.name}',
      );
    }
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // The user explicitly said no. We don't fetch a token because
      // even if we had one, FCM wouldn't deliver visible
      // notifications anyway. Re-attempt next cold start.
      return;
    }

    final token = await _fcm.getToken();
    _currentToken = token;
    if (kDebugMode) {
      debugPrint(
        '[push] token=${token == null ? '<null>' : '${token.substring(0, 12)}…'}',
      );
    }
    // First attempt — usually a no-op on cold start because the
    // session hasn't restored yet. The session-change listener below
    // (wired in `pushServiceProvider`) retries the moment we're
    // authenticated.
    await registerCurrentTokenIfReady();

    _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      if (kDebugMode) {
        debugPrint('[push] token refreshed → ${newToken.substring(0, 12)}…');
      }
      registerCurrentTokenIfReady();
    });

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      if (kDebugMode) {
        debugPrint(
          '[push:fg] ${message.notification?.title} :: ${message.data}',
        );
      }
      // TODO(v102): bubble through a Riverpod provider so the
      // Notifications inbox can refresh and a banner can appear.
    });
  }

  /// Register the current FCM token with the backend, but ONLY when
  /// the app session is authenticated. Idempotent and non-throwing —
  /// safe to call from anywhere (cold start, login, token refresh,
  /// foreground resume).
  Future<void> registerCurrentTokenIfReady() async {
    final token = _currentToken;
    if (token == null) return;
    final session = _ref.read(appSessionProvider);
    if (!session.isAuthenticated) {
      if (kDebugMode) {
        debugPrint(
          '[push] register deferred — session=${session.phase.name}',
        );
      }
      return;
    }
    await _sendToBackend(token);
  }

  /// POSTs the FCM token to the backend so server-side rule
  /// processing can dispatch FCM sends to this device.
  ///
  /// Failures are logged but never thrown — push registration is a
  /// best-effort side concern; the user opening the app should not
  /// be blocked by a transient backend hiccup. The next cold start
  /// (or token-refresh event) will retry naturally.
  Future<void> _sendToBackend(String token) async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.post(
        '/api/v1/notifications/push-tokens',
        body: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
      if (kDebugMode) {
        debugPrint('[push] token registered with backend');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[push] backend register failed: ${e.kind.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[push] backend register failed: ${e.runtimeType}');
      }
    }
  }

  /// Revokes the current device's token on the backend. Called from
  /// the logout flow so notifications stop reaching a logged-out
  /// install. Best-effort — failure is non-fatal.
  Future<void> revokeOnBackend() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      final api = _ref.read(apiClientProvider);
      await api.delete(
        '/api/v1/notifications/push-tokens',
        body: {'token': token},
      );
      if (kDebugMode) {
        debugPrint('[push] token revoked on backend');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[push] backend revoke failed: ${e.runtimeType}');
      }
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
  }
}

/// Mounts a single [PushService] for the app's lifetime. Watched
/// from `solar_deye_app.dart` so the bootstrap kicks off on the
/// first frame.
///
/// The session listener is the second half of the cold-start race
/// fix: the user is unauthenticated for the very first frame while
/// `appSessionProvider` restores tokens from secure storage, so the
/// initial `_sendToBackend` call returns 401. The moment the session
/// flips into the authenticated phase (either via restored tokens
/// or after the user types a password) we retry the register.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  // Fire-and-forget: `start()` does its own awaiting internally.
  // We don't `await` it from the provider factory because providers
  // must return synchronously.
  unawaited(service.start());
  ref.listen<AppSessionState>(appSessionProvider, (previous, next) {
    final wasAuthed = previous?.isAuthenticated ?? false;
    if (!wasAuthed && next.isAuthenticated) {
      unawaited(service.registerCurrentTokenIfReady());
    }
  });
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});
