import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// Backend contract (Phase A.8):
///   `POST /api/mobile/account/push-token` with JSON body
///   `{ "token": "<fcm>", "platform": "android" }`. The endpoint
///   stores / refreshes the row keyed on `(user_id, token)`.
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
    if (token != null) {
      await _sendToBackend(token);
    }

    _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      if (kDebugMode) {
        debugPrint('[push] token refreshed → ${newToken.substring(0, 12)}…');
      }
      _sendToBackend(newToken);
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

  /// Phase A.8 will wire this to a real Dio call once the backend
  /// endpoint exists. Logged-only for now so the v101 mobile commit
  /// stands on its own — pushing the token before the endpoint
  /// exists would just produce spurious 404s.
  Future<void> _sendToBackend(String token) async {
    if (kDebugMode) {
      debugPrint(
        '[push] would POST /api/mobile/account/push-token '
        '(deferred until backend endpoint lands in Phase A.8)',
      );
    }
    // Touch _ref so the analyzer doesn't flag it as unused while
    // we're between phases. The reference IS used as soon as the
    // Dio call lands.
    _ref.toString();
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
  }
}

/// Mounts a single [PushService] for the app's lifetime. Watched
/// from `solar_deye_app.dart` so the bootstrap kicks off on the
/// first frame.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  // Fire-and-forget: `start()` does its own awaiting internally.
  // We don't `await` it from the provider factory because providers
  // must return synchronously.
  unawaited(service.start());
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});
