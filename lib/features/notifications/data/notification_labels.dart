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

  // ── v44 phase 2 — Arabic payload formatters ──────────────────────
  //
  // These small helpers turn raw backend payload values (kWh / W /
  // percent / minutes / booleans) into polished Arabic display strings
  // for the v44 phase 2 detail-sheet summary block. Every helper
  // gracefully degrades to [emptyFieldLabel] when the input is missing
  // or malformed — the UI never crashes on a partial payload.

  /// Placeholder for any payload row whose value is missing or
  /// untranslatable. Calmer than an em-dash for full Arabic readability.
  static const String payloadEmpty = 'غير متوفر';

  /// Battery state-of-charge as "78%". Returns [payloadEmpty] when the
  /// value isn't a number.
  static String formatSocPercent(Object? raw) {
    final n = _coerceNum(raw);
    if (n == null) return payloadEmpty;
    return '${n.round()}%';
  }

  /// Power in watts, e.g. "1,230 واط". Rounded to the nearest integer
  /// since instantaneous watt values are reported to mobile as ints
  /// already on the backend.
  static String formatWatts(Object? raw) {
    final n = _coerceNum(raw);
    if (n == null) return payloadEmpty;
    return '${_formatThousands(n.round())} واط';
  }

  /// Energy in kWh. "12.5 كيلوواط·ساعة" (one decimal, comma thousands).
  static String formatKwh(Object? raw) {
    final n = _coerceNum(raw);
    if (n == null) return payloadEmpty;
    final intPart = n.truncate();
    final formatted = n.abs() < 100
        ? n.toStringAsFixed(1)
        : _formatThousands(intPart.abs())
            + (n - intPart >= 0.05 ? '.${((n - intPart) * 10).round().clamp(0, 9)}' : '');
    final signed = n < 0 ? '-${formatted.replaceFirst('-', '')}' : formatted;
    return '$signed كيلوواط·ساعة';
  }

  /// Convert a minutes-to-event value into a calm Arabic remaining
  /// label, e.g. 47.0 → "٤٧ دقيقة". Falls back to [payloadEmpty]
  /// when the input is non-numeric.
  ///
  /// We deliberately keep Western-Arabic digits (0-9) because mixing
  /// Eastern Arabic digits with the rest of the app (every other place
  /// uses Western digits) would feel inconsistent. If the value is
  /// >= 60 we still render in minutes — the backend only emits this
  /// field for the pre-sunset window where 90 minutes is the practical
  /// ceiling, so an "hour-and-minutes" split is overkill here.
  static String formatMinutes(Object? raw) {
    final n = _coerceNum(raw);
    if (n == null) return payloadEmpty;
    final rounded = n.round();
    return '$rounded دقيقة';
  }

  /// Convert a fractional-hours value (e.g. `time_to_full_hours: 2.1`)
  /// into a calm Arabic remaining label. Sub-hour values render in
  /// minutes; whole hours render with up to one decimal.
  static String formatHours(Object? raw) {
    final n = _coerceNum(raw);
    if (n == null) return payloadEmpty;
    if (n.isNegative) return payloadEmpty;
    if (n < 1) {
      return '${(n * 60).round()} دقيقة';
    }
    final asMinutes = (n * 60).round();
    final hours = asMinutes ~/ 60;
    final minutes = asMinutes % 60;
    if (minutes == 0) return '$hours ساعة';
    return '$hours ساعة و$minutes دقيقة';
  }

  /// Whether a charge cycle is expected to top up before sunset.
  /// Polished Arabic product wording instead of a bare yes/no.
  static String formatWillFullBeforeSunset(Object? raw) {
    if (raw is bool) return raw ? 'متوقع' : 'غير متوقع';
    return payloadEmpty;
  }

  /// Free-form short Arabic summary string (e.g.
  /// `weather_summary: "غيوم خفيفة"`). Falls back to [payloadEmpty]
  /// when the value is missing or empty.
  static String formatFreeText(Object? raw) {
    if (raw == null) return payloadEmpty;
    final s = raw.toString().trim();
    return s.isEmpty ? payloadEmpty : s;
  }

  // ── Technical-panel row labels (v44 audit polish) ──────────────────
  //
  // The detail sheet's collapsed "تفاصيل تقنية" panel used to label
  // its rows with raw English keys (`id`, `event_type`, `source_type`,
  // …). Per real-user feedback, those labels still read too
  // prominently inside an Arabic-first surface. Phase 2b made them
  // visually subordinate; this audit pass replaces them with Arabic
  // labels while keeping the **values** raw (intentional — the panel
  // is for support tracing). Each label is phrased to make clear it
  // describes the underlying code, not a polished user concept:
  // "رمز…" (code), "علامة…" (flag), "الخام" (raw).
  //
  // Unknown keys fall through to the original raw key so a future
  // backend addition doesn't disappear from the panel silently.
  static const Map<String, String> _technicalRowLabels = {
    'id': 'رقم الإشعار',
    'event_type': 'رمز نوع الحدث',
    'source_type': 'رمز المصدر',
    'source_id': 'مرجع الجهاز',
    'status': 'الحالة الخام',
    'is_read': 'علامة القراءة',
  };

  /// Arabic label for a technical-panel row keyed by its backend field
  /// name. Returns the raw `key` unchanged when no mapping exists, so
  /// new fields never silently vanish from the diagnostics panel.
  static String technicalRowLabel(String key) {
    final n = key.trim().toLowerCase();
    if (n.isEmpty) return key;
    return _technicalRowLabels[n] ?? key;
  }
}

// ── private helpers (file-scope) ──────────────────────────────────────

num? _coerceNum(Object? raw) {
  if (raw is num) return raw;
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return num.tryParse(t);
  }
  return null;
}

/// "1,234" / "12" — comma thousands for integer Arabic display. Kept
/// inline because the app intentionally does not depend on the `intl`
/// package.
String _formatThousands(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  final n = s.length;
  for (var i = 0; i < n; i++) {
    if (i > 0 && (n - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return v < 0 ? '-$buf' : buf.toString();
}
