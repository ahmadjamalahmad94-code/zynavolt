import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/solar_deye_app.dart';
import 'core/notifications/push_background_handler.dart';

Future<void> main() async {
  // v101 — `ensureInitialized` first, then Firebase, then the
  // background handler registration. Firebase MUST be initialized
  // before `FirebaseMessaging.onBackgroundMessage` is called or the
  // handler is lost across cold starts.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  registerPushBackgroundHandler();

  runApp(const ProviderScope(child: SolarDeyeApp()));
}
