import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/push_overlay.dart';
import '../core/notifications/push_service.dart';
import '../core/state/auto_refresh.dart';
import '../core/state/font_pref.dart';
import '../core/state/time_format_provider.dart';
import 'app_config.dart';
import 'app_router.dart';
import 'app_theme.dart';

class SolarDeyeApp extends ConsumerWidget {
  const SolarDeyeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // v99d — instantiate the time-format provider early so its
    // controller hydrates `TimeFormatPref.current` from secure
    // storage during the first frame. Any timestamp formatted
    // before this watch returns will use the default (12-hour),
    // then re-rendering after hydration picks up the saved value.
    ref.watch(timeFormatPrefProvider);
    // v100-fonts — watch the font preference so changing it from
    // the Settings card rebuilds `MaterialApp.router` with a fresh
    // theme that uses the new typeface app-wide.
    final activeFont = ref.watch(appFontPrefProvider);
    // v101 — mount the shared AppLifecycle observer once, here at
    // the root, so every screen using AutoRefreshScope can react to
    // foreground / background transitions. Without this watch the
    // observer would never be added and timers would keep ticking
    // while the app sits in the background.
    ref.watch(appLifecycleObserverProvider);
    // v101 — kick off the FCM bootstrap (permission prompt, token
    // fetch, refresh listener). The provider runs `start()` as a
    // fire-and-forget so the first frame doesn't block on the
    // permission dialog.
    ref.watch(pushServiceProvider);

    return MaterialApp.router(
      title: 'Zynavolt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(font: activeFont),
      locale: const Locale(AppConfig.defaultLocale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // v101 Phase D — PushOverlay sits between MaterialApp.router
        // and the page content. It owns a ScaffoldMessenger that
        // shows in-app banners for foreground push messages, and
        // listens to push-tap events to deep-link into the relevant
        // screen. Both behaviours are passive and add no layout.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: PushOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: router,
    );
  }
}
