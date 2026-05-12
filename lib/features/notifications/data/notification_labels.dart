// Arabic display labels for notification metadata slugs.
//
// The backend stores short English identifiers (`event_type`,
// `source_type`, `status`) that the mobile app should NEVER show
// verbatim to a normal user. This helper is the single source of truth
// for the Arabic strings the UI surfaces, including a small fallback
// table so unknown values still render politely.
//
// Backend whitelist this helper must cover (v43 + earlier):
//   event_type:
//     load_alert, load_recommendation, solar_status, solar_surplus,
//     pre_sunset, periodic_day, periodic_night, daily_report,
//     weather_alert, battery_status, battery_warning, night_discharge,
//     grid_status, inverter_status, energy_status_change,
//     support_case_updated, support_reply, support_message,
//     account_update, system_notice, sync_status,
//     (legacy) system, phase_change, battery_priority,
//     actual_surplus, actual_surplus_shift, status_change, support,
//     alert, info, warning, error
//   source_type:
//     energy, support, ticket, message, account, system, sync,
//     notification, admin, device, inverter, support_case,
//     subscription
//   status:
//     new, unread, read, info, warning, critical, success, failed,
//     error, pending
//
// Raw values stay untouched in the model — this helper is for
// presentation only.

class NotificationLabels {
  const NotificationLabels._();

  // ── Friendly Arabic fallbacks ─────────────────────────────────────
  /// Fallback used by [eventTypeLabel] when the slug is unknown OR
  /// empty. The task brief explicitly requires that the UI never
  /// render the raw English slug to a normal user.
  static const String unknownEventLabel = 'تنبيه';

  /// Fallback used by [sourceTypeLabel] when the slug is unknown OR
  /// empty.
  static const String unknownSourceLabel = 'النظام';

  /// Fallback used by [statusLabel] when the slug is unknown OR empty.
  static const String unknownStatusLabel = 'حالة غير محددة';

  /// Used when a field is structurally absent (e.g. no `read_at` yet,
  /// no profile timezone configured). Render a single em-dash instead
  /// of an English placeholder.
  static const String emptyFieldLabel = 'غير محدد';

  // ── Event type table ──────────────────────────────────────────────
  static const Map<String, String> _eventTypes = {
    // v43 backend mirror whitelist
    'load_alert': 'اقتراح الأحمال',
    'load_recommendation': 'توصية تشغيل الأحمال',
    'solar_status': 'حالة الإنتاج الشمسي',
    'solar_surplus': 'الفائض الشمسي',
    'pre_sunset': 'تحليل ما قبل الغروب',
    'periodic_day': 'تحديث نهاري للطاقة',
    'periodic_night': 'تحديث ليلي للطاقة',
    'daily_report': 'التقرير اليومي',
    'weather_alert': 'تنبيه الطقس',
    'battery_status': 'حالة البطارية',
    'battery_warning': 'تحذير البطارية',
    'night_discharge': 'تفريغ ليلي',
    'grid_status': 'حالة الشبكة',
    'inverter_status': 'حالة الانفرتر',
    'energy_status_change': 'تغيّر حالة الطاقة',

    // Support / account / system event_type values
    'support_case_updated': 'تحديث طلب الدعم',
    'support_reply': 'رد الدعم',
    'support_message': 'رسالة دعم',
    'account_update': 'تحديث الحساب',
    'system_notice': 'تنبيه النظام',
    'sync_status': 'حالة المزامنة',

    // Legacy / pre-v43 event_type values kept for back-compat with
    // older rows already in the database.
    'system': 'تنبيه النظام',
    'phase_change': 'تغيير المرحلة',
    'battery_priority': 'أولوية البطارية',
    'actual_surplus': 'فائض فعلي',
    'actual_surplus_shift': 'تحويل فائض',
    'status_change': 'تغيير الحالة',
    'support': 'الدعم',
    'alert': 'تنبيه',
    'info': 'معلومة',
    'warning': 'تحذير',
    'error': 'خطأ',
  };

  // ── Source type table ─────────────────────────────────────────────
  static const Map<String, String> _sourceTypes = {
    'energy': 'متابعة الطاقة',
    'support': 'الدعم',
    'ticket': 'تذكرة الدعم',
    'message': 'رسالة',
    'account': 'الحساب',
    'system': 'النظام',
    'sync': 'المزامنة',
    'notification': 'الإشعارات',
    'admin': 'الإدارة',
    'device': 'الجهاز',
    'inverter': 'العاكس',
    'support_case': 'طلب دعم',
    'subscription': 'الاشتراك',
  };

  // ── Status / severity table ───────────────────────────────────────
  static const Map<String, String> _statuses = {
    'new': 'جديد',
    'unread': 'غير مقروء',
    'read': 'مقروء',
    'info': 'معلومة',
    'warning': 'تحذير',
    'critical': 'حرج',
    'success': 'ناجح',
    'failed': 'فشل',
    'error': 'خطأ',
    'pending': 'قيد الانتظار',
  };

  // ── Boolean / flag table ──────────────────────────────────────────
  /// Localised yes/no — used by [boolLabel] and the flag rows in the
  /// developer technical section. Defined as a const map for static
  /// analysis cleanliness.
  static const Map<bool, String> _bools = {
    true: 'نعم',
    false: 'لا',
  };

  // ── Lookup APIs ───────────────────────────────────────────────────

  /// Translate an `event_type` slug into a user-facing Arabic label.
  /// Unknown or empty slugs return [unknownEventLabel] (never the raw
  /// English slug — that would defeat the localisation pass).
  static String eventTypeLabel(String slug) {
    final n = slug.trim().toLowerCase();
    if (n.isEmpty) return unknownEventLabel;
    return _eventTypes[n] ?? unknownEventLabel;
  }

  /// Translate a `source_type` slug. Same fallback policy as
  /// [eventTypeLabel].
  static String sourceTypeLabel(String slug) {
    final n = slug.trim().toLowerCase();
    if (n.isEmpty) return unknownSourceLabel;
    return _sourceTypes[n] ?? unknownSourceLabel;
  }

  /// Translate a `status` slug. Returns [unknownStatusLabel] when the
  /// slug is unknown or empty.
  static String statusLabel(String slug) {
    final n = slug.trim().toLowerCase();
    if (n.isEmpty) return unknownStatusLabel;
    return _statuses[n] ?? unknownStatusLabel;
  }

  /// Localised yes/no.
  static String boolLabel(bool v) => _bools[v] ?? unknownStatusLabel;

  /// Localised label for the `delivered_to_user` flag — surfaced in the
  /// technical-details panel when applicable.
  static String deliveredFlagLabel(bool delivered) =>
      delivered ? 'تم التسليم' : 'لم يُسلَّم';

  /// Localised label for the `appeared_in_bell` flag.
  static String appearedInBellFlagLabel(bool appeared) =>
      appeared ? 'ظهر في مركز الإشعارات' : 'لم يظهر في مركز الإشعارات';

  /// Resolve the chip label for a notification — prefers `event_type`,
  /// falls back to `source_type`, returns `''` only when both fields
  /// are structurally empty (so the caller can suppress the chip).
  /// When a value is present but unknown the friendly fallback labels
  /// are used so the chip never leaks an English slug.
  static String chipLabel({
    required String eventType,
    required String sourceType,
  }) {
    if (eventType.trim().isNotEmpty) return eventTypeLabel(eventType);
    if (sourceType.trim().isNotEmpty) return sourceTypeLabel(sourceType);
    return '';
  }
}
