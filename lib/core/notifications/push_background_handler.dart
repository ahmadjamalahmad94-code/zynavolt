import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// v101 — Background isolate handler for FCM messages that arrive
/// while the app is terminated or in the background.
///
/// FCM spawns a NEW Dart isolate for these — it does NOT have access
/// to the same Riverpod container, route stack, or providers as the
/// foreground app. So this handler can:
///   * Initialise Firebase again (the SDK requires it per-isolate).
///   * Log / show a local notification (later — Android already shows
///     the system notification automatically when the message contains
///     a `notification` payload, which is the default we use).
///   * Update local state via shared storage.
///
/// It CANNOT touch Riverpod providers or Flutter widgets, so we keep
/// it minimal — just a debugPrint until we wire local-notifications.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint(
      '[push:bg] received id=${message.messageId} '
      'title=${message.notification?.title} '
      'data=${message.data}',
    );
  }
}

/// Wires `_onBackgroundMessage` into FCM. Call once from `main.dart`
/// AFTER `Firebase.initializeApp()` and BEFORE `runApp()`.
void registerPushBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
}
