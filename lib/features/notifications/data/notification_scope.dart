import 'notification_models.dart';

/// Top-level grouping for the Notifications feed (v91).
///
/// The backend serves one flat list at `GET /api/mobile/notifications`.
/// Mobile splits it into two product-meaningful tabs so users can quickly
/// triage *system / account / support* signals separately from
/// *energy / battery / load / weather* signals.
enum NotificationScope { app, energy }

/// Calm Arabic copy for each tab — used both for the tab label and the
/// scope intro card on the Notifications screen.
String notificationScopeTitle(NotificationScope s) {
  switch (s) {
    case NotificationScope.app:
      return 'إشعارات التطبيق';
    case NotificationScope.energy:
      return 'متابعة الطاقة والأحمال';
  }
}

String notificationScopeIntro(NotificationScope s) {
  switch (s) {
    case NotificationScope.app:
      return 'تنبيهات تخص الحساب، الدعم، المزامنة، الأجهزة، وحالة التطبيق.';
    case NotificationScope.energy:
      return 'تنبيهات تخص البطارية، الأحمال، الشمس، الفائض، '
          'والتنبيهات التي تهم تشغيل النظام.';
  }
}

/// Classify a single notification into one of the two tabs.
///
/// Strategy:
///   * Score each notification by checking its `event_type`,
///     `source_type`, `title`, and `message` against keyword sets.
///   * Energy keywords win in any tie — they're the more specific
///     signal, and the only ones we want to never mis-route.
///   * If neither set matches, default to [NotificationScope.app] as
///     instructed in the v91 spec ("default to App notifications unless
///     it clearly belongs to Energy/Loads").
NotificationScope classifyNotification(AppNotification n) {
  final fields = <String>[
    n.eventType.toLowerCase(),
    n.sourceType.toLowerCase(),
    n.title.toLowerCase(),
    n.message.toLowerCase(),
  ];

  bool anyContains(Iterable<String> needles) {
    for (final f in fields) {
      if (f.isEmpty) continue;
      for (final k in needles) {
        if (f.contains(k)) return true;
      }
    }
    return false;
  }

  if (anyContains(_energyKeywords)) return NotificationScope.energy;
  if (anyContains(_appKeywords)) return NotificationScope.app;
  return NotificationScope.app;
}

/// Coarse category inside the Energy tab — drives the v92 local filter
/// chips (الكل / البطارية / الأحمال / الشمس والطقس / التقارير).
enum EnergyCategory { all, battery, load, sunWeather, reports, other }

String energyCategoryLabel(EnergyCategory c) {
  switch (c) {
    case EnergyCategory.all:
      return 'الكل';
    case EnergyCategory.battery:
      return 'البطارية';
    case EnergyCategory.load:
      return 'الأحمال';
    case EnergyCategory.sunWeather:
      return 'الشمس والطقس';
    case EnergyCategory.reports:
      return 'التقارير';
    case EnergyCategory.other:
      return 'أخرى';
  }
}

/// Sub-classify an energy-scoped notification into one of the v92 chips.
/// Returns [EnergyCategory.other] when no specific signal is present —
/// the chip filter explicitly handles the "other" bucket.
EnergyCategory classifyEnergyCategory(AppNotification n) {
  final fields = <String>[
    n.eventType.toLowerCase(),
    n.sourceType.toLowerCase(),
    n.title.toLowerCase(),
    n.message.toLowerCase(),
  ];
  bool any(Iterable<String> needles) {
    for (final f in fields) {
      if (f.isEmpty) continue;
      for (final k in needles) {
        if (f.contains(k)) return true;
      }
    }
    return false;
  }

  if (any(_batteryKeywords)) return EnergyCategory.battery;
  if (any(_loadKeywords)) return EnergyCategory.load;
  if (any(_sunWeatherKeywords)) return EnergyCategory.sunWeather;
  if (any(_reportKeywords)) return EnergyCategory.reports;
  return EnergyCategory.other;
}

// ─── keyword tables ──────────────────────────────────────────────────────
//
// Each entry is a substring match against the lowercased
// event_type / source_type / title / message. The lists mix the English
// backend slugs we know exist (`battery_priority`, `pre_sunset`, …) with
// the Arabic substrings the backend may put into title / message bodies.

const Set<String> _energyKeywords = {
  // English / slug
  'battery', 'battery_priority', 'battery_test',
  'load', 'load_alert',
  'solar',
  'pre_sunset', 'sunset',
  'weather', 'weather_test',
  'discharge', 'charge', 'charging', 'discharging',
  'daily_report',
  'night_discharge', 'night_thresholds',
  'surplus', 'actual_surplus', 'actual_surplus_shift',
  'grid', 'inverter',
  'phase_change', 'status_change',
  'forecast', 'periodic_day', 'periodic_night',
  // Arabic
  'البطارية', 'الأحمال', 'حمل', 'الشمس', 'الشمسي',
  'الطقس', 'تفريغ', 'شحن', 'التقرير اليومي',
  'فائض', 'العاكس', 'الشبكة', 'الإنتاج', 'الإنتاجية',
  'تنبيه طاقة', 'تنبيه أحمال',
};

const Set<String> _appKeywords = {
  // English / slug
  'support', 'support_case', 'support_ticket',
  'account', 'auth', 'login', 'sync',
  'device', 'system', 'subscription', 'plan',
  'onboarding', 'profile', 'billing',
  // Arabic
  'الدعم', 'الحساب', 'اشتراك', 'الباقة', 'الملف',
  'تسجيل الدخول', 'مزامنة',
};

const Set<String> _batteryKeywords = {
  'battery', 'battery_priority', 'battery_test',
  'discharge', 'charge', 'charging', 'discharging',
  'night_discharge',
  'البطارية', 'تفريغ', 'شحن',
};

const Set<String> _loadKeywords = {
  'load', 'load_alert',
  'الأحمال', 'حمل',
};

const Set<String> _sunWeatherKeywords = {
  'solar', 'pre_sunset', 'sunset',
  'weather', 'weather_test',
  'forecast',
  'الشمس', 'الشمسي', 'الطقس', 'الإنتاج',
};

const Set<String> _reportKeywords = {
  'daily_report',
  'periodic_day', 'periodic_night',
  'التقرير', 'التقرير اليومي',
};
