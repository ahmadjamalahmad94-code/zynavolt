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
/// Strategy (v96):
///   1. **Trust the backend's structured signal first.** Backend v43
///      stamps every mirrored energy/load/solar/weather notification
///      with `source_type = "energy"`. When that field is present, we
///      route to the Energy tab immediately — no keyword matching, no
///      ambiguity.
///   2. As a second structured fallback, route by `event_type` against
///      the v43 whitelist (`battery_status`, `load_alert`,
///      `weather_alert`, …) so a clipped or missing `source_type`
///      still lands the notification on the right tab.
///   3. Only when neither structured signal is present do we fall back
///      to the v91/v92/v94 keyword scan over event_type / source_type
///      / title / message.
///   4. If nothing matches at all, default to [NotificationScope.app]
///      as instructed in the v91 spec ("default to App notifications
///      unless it clearly belongs to Energy/Loads").
NotificationScope classifyNotification(AppNotification n) {
  // (1) backend-structured signal — source_type=energy from v43.
  final src = n.sourceType.toLowerCase().trim();
  if (src == 'energy') return NotificationScope.energy;

  // (2) backend-structured signal — known v43 event_type whitelist.
  final ev = n.eventType.toLowerCase().trim();
  if (_v43EnergyEventTypes.contains(ev)) return NotificationScope.energy;

  // (3) keyword fallback (preserved from v91/v92/v94).
  final fields = <String>[
    ev,
    src,
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
  // (4) safe default — App tab.
  return NotificationScope.app;
}

/// v96: machine-readable energy event_type values the backend (v43+)
/// stamps onto mirrored energy notifications. An exact (case-insensitive,
/// trimmed) match here routes the notification to the Energy tab even
/// when the upstream `source_type` field is empty or unexpected.
const Set<String> _v43EnergyEventTypes = {
  'battery_status',
  'battery_warning',
  'load_alert',
  'load_recommendation',
  'solar_status',
  'solar_surplus',
  'weather_alert',
  'daily_report',
  'periodic_day',
  'periodic_night',
  'pre_sunset',
  'night_discharge',
  'grid_status',
  'inverter_status',
  'energy_status_change',
};

/// Coarse category inside the Energy tab — drives the v92 local filter
/// chips (الكل / البطارية / الأحمال / الشمس والطقس / التقارير).
enum EnergyCategory { all, battery, load, sunWeather, reports, other }

String energyCategoryLabel(EnergyCategory c) {
  switch (c) {
    // v94: rename `الكل` → `كل الفئات` so it doesn't sit ambiguously
    // next to the read-state filter's own `الكل` pill.
    case EnergyCategory.all:
      return 'كل الفئات';
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
  'case', 'ticket', 'comment', 'reply', 'message',
  'account', 'auth', 'login', 'sync',
  'device', 'system', 'subscription', 'plan',
  'onboarding', 'profile', 'billing',
  // Arabic
  'الدعم', 'الحساب', 'اشتراك', 'الباقة', 'الملف',
  'تسجيل الدخول', 'مزامنة',
  // v94b: explicit Arabic synonyms for admin replies on support cases.
  // Energy keywords win in the classifier, so adding these can't pull
  // a battery/load/weather notification into the App tab by accident.
  'تذكرة', 'رسالة الدعم', 'تعليق', 'رد',
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
