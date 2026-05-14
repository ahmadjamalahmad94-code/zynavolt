// Zynavolt Mobile DS v1 — Notification bucket classifier.
//
// The new Notifications screen displays a flat scroll grouped into
// three semantic buckets instead of the v96 App/Energy tabs:
//
//   * critical    — anything the user should react to NOW.
//   * suggestion  — smart recommendations / proactive hints.
//   * update      — periodic reports + routine status changes.
//
// Classification is heuristic (the backend does NOT label events
// with a bucket today). It looks at, in order of precedence:
//
//   1. Backend `level` if it ever lands on `AppNotification` (today
//      that field is part of `NotificationLog`, not exposed here —
//      kept as a forward-compat hook).
//   2. Event-type whitelist for the structured energy events from
//      `app/services/notifications/mobile_mirror.py` (battery_status,
//      load_alert, weather_alert, etc.).
//   3. Title/message keyword scan in Arabic + English so legacy /
//      support / account notifications still land in a sensible
//      bucket.
//   4. Default → `update`.
//
// Defaults to `update` rather than `critical` because the new
// summary cards count critical items and a wrong critical answer
// would scream at the user.

import 'notification_models.dart';

enum NotificationBucket { critical, suggestion, update }

String notificationBucketLabel(NotificationBucket b) {
  switch (b) {
    case NotificationBucket.critical:
      return 'تنبيهات حرجة';
    case NotificationBucket.suggestion:
      return 'اقتراحات ذكية';
    case NotificationBucket.update:
      return 'تحديثات دورية';
  }
}

NotificationBucket classifyBucket(AppNotification n) {
  final ev = n.eventType.toLowerCase().trim();
  final fields = <String>[
    ev,
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

  // (1) Structured event-type whitelist — most reliable signal.
  if (_criticalEvents.contains(ev)) return NotificationBucket.critical;
  if (_suggestionEvents.contains(ev)) return NotificationBucket.suggestion;
  if (_updateEvents.contains(ev)) return NotificationBucket.update;

  // (2) Keyword scan — covers free-form support / account / legacy.
  if (any(_criticalKeywords)) return NotificationBucket.critical;
  if (any(_suggestionKeywords)) return NotificationBucket.suggestion;

  // (3) Default.
  return NotificationBucket.update;
}

// ─── Event-type whitelists ───────────────────────────────────────

const Set<String> _criticalEvents = {
  'battery_warning',
  'pre_sunset',
  'night_discharge',
  'inverter_overheat',
  'grid_outage',
  'system_alert',
};

const Set<String> _suggestionEvents = {
  'load_recommendation',
  'solar_surplus',
  'energy_optimization',
  'smart_suggestion',
};

const Set<String> _updateEvents = {
  'daily_report',
  'periodic_day',
  'periodic_night',
  'battery_status',
  'solar_status',
  'weather_alert',
  'grid_status',
  'inverter_status',
  'energy_status_change',
  'load_alert',
};

// ─── Keyword scan (case-insensitive, Arabic + English) ──────────

const Set<String> _criticalKeywords = {
  // English
  'critical', 'warning', 'alert', 'danger', 'overheat', 'outage',
  'deficit', 'low_battery', 'emergency',
  // Arabic
  'حرج', 'خطر', 'تحذير', 'انخفاض', 'عجز', 'ارتفاع حرارة',
  'تنبيه عاجل', 'انقطاع',
};

const Set<String> _suggestionKeywords = {
  // English
  'suggestion', 'recommend', 'optimize', 'surplus', 'tip',
  // Arabic
  'اقتراح', 'توصية', 'تحسين', 'فائض', 'استفادة', 'ينصح',
};
