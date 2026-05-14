import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return MaterialApp.router(
      title: 'Zynavolt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(font: activeFont),
      locale: const Locale(AppConfig.defaultLocale),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
