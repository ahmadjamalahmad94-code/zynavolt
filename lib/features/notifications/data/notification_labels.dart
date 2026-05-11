// Arabic labels for notification `event_type` / `source_type` slugs.
//
// The backend assigns short identifiers in `notify_user(...)` /
// `_mobile_notification_event_payload`. Known event types in the
// production backend today (from `app/blueprints/helpers.py` +
// `app/services/support_ops.py`):
//
//   system, phase_change, battery_priority, actual_surplus,
//   actual_surplus_shift, status_change, support
//
// Unknown future slugs fall back to the raw slug so the chip still
// renders something — adding a new mapping is a one-line change.

class NotificationLabels {
  const NotificationLabels._();

  static const Map<String, String> _eventTypes = {
    'system': 'النظام',
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

  static const Map<String, String> _sourceTypes = {
    'device': 'جهاز',
    'inverter': 'عاكس',
    'system': 'النظام',
    'support': 'الدعم',
    'support_case': 'طلب دعم',
    'subscription': 'اشتراك',
  };

  /// Translate an `event_type` slug. Falls back to the slug for unknown
  /// keys so the chip always renders something.
  static String eventTypeLabel(String slug) {
    final n = slug.trim().toLowerCase();
    return _eventTypes[n] ?? slug;
  }

  /// Translate a `source_type` slug. Used when `event_type` is empty.
  static String sourceTypeLabel(String slug) {
    final n = slug.trim().toLowerCase();
    return _sourceTypes[n] ?? slug;
  }

  /// Resolve the chip label for a notification — prefers `event_type`,
  /// falls back to `source_type`, then to the empty string when neither
  /// is set (caller suppresses the chip in that case).
  static String chipLabel({
    required String eventType,
    required String sourceType,
  }) {
    if (eventType.isNotEmpty) return eventTypeLabel(eventType);
    if (sourceType.isNotEmpty) return sourceTypeLabel(sourceType);
    return '';
  }
}
