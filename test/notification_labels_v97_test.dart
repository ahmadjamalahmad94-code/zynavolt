import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/notifications/data/notification_labels.dart';

/// v97 localizer mapping tests.
///
/// These guards lock in the contract that the mobile UI never renders
/// a raw English slug from the backend. Every value emitted by the
/// localizer must either be the explicit Arabic mapping or the
/// friendly fallback string — never the slug itself.
void main() {
  group('eventTypeLabel — v43 backend whitelist', () {
    const cases = {
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
      'support_case_updated': 'تحديث طلب الدعم',
      'support_reply': 'رد الدعم',
      'support_message': 'رسالة دعم',
      'account_update': 'تحديث الحساب',
      'system_notice': 'تنبيه النظام',
      'sync_status': 'حالة المزامنة',
    };

    cases.forEach((slug, arabic) {
      test('$slug → $arabic', () {
        expect(NotificationLabels.eventTypeLabel(slug), arabic);
      });
    });
  });

  group('eventTypeLabel — case + whitespace tolerance', () {
    test('matches case-insensitively', () {
      expect(
        NotificationLabels.eventTypeLabel('LOAD_ALERT'),
        'اقتراح الأحمال',
      );
      expect(
        NotificationLabels.eventTypeLabel('Battery_Warning'),
        'تحذير البطارية',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        NotificationLabels.eventTypeLabel('  daily_report  '),
        'التقرير اليومي',
      );
    });
  });

  group('eventTypeLabel — unknown / empty', () {
    test('empty slug falls back to friendly Arabic', () {
      expect(NotificationLabels.eventTypeLabel(''),
          NotificationLabels.unknownEventLabel);
      expect(NotificationLabels.eventTypeLabel('   '),
          NotificationLabels.unknownEventLabel);
    });

    test('unknown slug NEVER leaks raw English to the UI', () {
      final label = NotificationLabels.eventTypeLabel('mystery_event_xyz');
      expect(label, NotificationLabels.unknownEventLabel);
      expect(label.contains('mystery_event_xyz'), isFalse);
      expect(label.contains('_'), isFalse);
    });
  });

  group('sourceTypeLabel — full table', () {
    const cases = {
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

    cases.forEach((slug, arabic) {
      test('$slug → $arabic', () {
        expect(NotificationLabels.sourceTypeLabel(slug), arabic);
      });
    });

    test('unknown source falls back to friendly Arabic, not raw slug', () {
      final label = NotificationLabels.sourceTypeLabel('mystery_source');
      expect(label, NotificationLabels.unknownSourceLabel);
      expect(label.contains('mystery_source'), isFalse);
    });

    test('empty source falls back to friendly Arabic', () {
      expect(NotificationLabels.sourceTypeLabel(''),
          NotificationLabels.unknownSourceLabel);
    });
  });

  group('statusLabel — full table', () {
    const cases = {
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

    cases.forEach((slug, arabic) {
      test('$slug → $arabic', () {
        expect(NotificationLabels.statusLabel(slug), arabic);
      });
    });

    test('unknown status falls back to "حالة غير محددة"', () {
      expect(NotificationLabels.statusLabel('mystery_status'),
          NotificationLabels.unknownStatusLabel);
    });

    test('empty status falls back to friendly Arabic', () {
      expect(NotificationLabels.statusLabel(''),
          NotificationLabels.unknownStatusLabel);
    });
  });

  group('boolLabel + flag helpers', () {
    test('boolLabel yes/no', () {
      expect(NotificationLabels.boolLabel(true), 'نعم');
      expect(NotificationLabels.boolLabel(false), 'لا');
    });

    test('deliveredFlagLabel', () {
      expect(NotificationLabels.deliveredFlagLabel(true), 'تم التسليم');
      expect(NotificationLabels.deliveredFlagLabel(false), 'لم يُسلَّم');
    });

    test('appearedInBellFlagLabel', () {
      expect(
        NotificationLabels.appearedInBellFlagLabel(true),
        'ظهر في مركز الإشعارات',
      );
      expect(
        NotificationLabels.appearedInBellFlagLabel(false),
        'لم يظهر في مركز الإشعارات',
      );
    });
  });

  group('chipLabel — prefers event_type, falls back to source_type', () {
    test('known event_type wins over source_type', () {
      expect(
        NotificationLabels.chipLabel(
          eventType: 'load_alert',
          sourceType: 'energy',
        ),
        'اقتراح الأحمال',
      );
    });

    test('empty event_type → source_type Arabic', () {
      expect(
        NotificationLabels.chipLabel(eventType: '', sourceType: 'energy'),
        'متابعة الطاقة',
      );
    });

    test('both empty → empty string (caller suppresses chip)', () {
      expect(
        NotificationLabels.chipLabel(eventType: '', sourceType: ''),
        '',
      );
      expect(
        NotificationLabels.chipLabel(eventType: '   ', sourceType: '   '),
        '',
      );
    });

    test('unknown event_type never leaks raw slug', () {
      final label = NotificationLabels.chipLabel(
        eventType: 'made_up_kind',
        sourceType: '',
      );
      expect(label, NotificationLabels.unknownEventLabel);
    });
  });

  // ── v44 phase 2 — Arabic payload formatters ──────────────────────
  group('formatSocPercent', () {
    test('renders integer percent for valid numbers', () {
      expect(NotificationLabels.formatSocPercent(78), '78%');
      expect(NotificationLabels.formatSocPercent(78.5), '79%'); // rounded
      expect(NotificationLabels.formatSocPercent(0), '0%');
      expect(NotificationLabels.formatSocPercent(100), '100%');
    });
    test('accepts numeric strings (defensive parse)', () {
      expect(NotificationLabels.formatSocPercent('80'), '80%');
    });
    test('falls back to "غير متوفر" for nulls / garbage', () {
      expect(NotificationLabels.formatSocPercent(null),
          NotificationLabels.payloadEmpty);
      expect(NotificationLabels.formatSocPercent('not-a-number'),
          NotificationLabels.payloadEmpty);
    });
  });

  group('formatWatts', () {
    test('comma-thousands integer + Arabic unit', () {
      expect(NotificationLabels.formatWatts(1230), '1,230 واط');
      expect(NotificationLabels.formatWatts(0), '0 واط');
      expect(NotificationLabels.formatWatts(1230.7), '1,231 واط');
    });
    test('null / garbage → غير متوفر', () {
      expect(NotificationLabels.formatWatts(null),
          NotificationLabels.payloadEmpty);
      expect(NotificationLabels.formatWatts(const Object()),
          NotificationLabels.payloadEmpty);
    });
  });

  group('formatKwh', () {
    test('keeps one decimal for values < 100', () {
      expect(NotificationLabels.formatKwh(12.5), '12.5 كيلوواط·ساعة');
      expect(NotificationLabels.formatKwh(0.0), '0.0 كيلوواط·ساعة');
    });
    test('larger values render with comma thousands', () {
      final out = NotificationLabels.formatKwh(9876.5);
      expect(out.startsWith('9,876'), isTrue);
      expect(out.endsWith('كيلوواط·ساعة'), isTrue);
    });
    test('null → غير متوفر', () {
      expect(NotificationLabels.formatKwh(null),
          NotificationLabels.payloadEmpty);
    });
  });

  group('formatMinutes', () {
    test('rounds and appends Arabic unit', () {
      expect(NotificationLabels.formatMinutes(47), '47 دقيقة');
      expect(NotificationLabels.formatMinutes(47.4), '47 دقيقة');
      expect(NotificationLabels.formatMinutes(0), '0 دقيقة');
    });
    test('null → غير متوفر', () {
      expect(NotificationLabels.formatMinutes(null),
          NotificationLabels.payloadEmpty);
    });
  });

  group('formatHours', () {
    test('sub-hour values fall back to minutes', () {
      expect(NotificationLabels.formatHours(0.5), '30 دقيقة');
    });
    test('whole-hour values render in hours only', () {
      expect(NotificationLabels.formatHours(2.0), '2 ساعة');
    });
    test('mixed hour/minute values', () {
      expect(NotificationLabels.formatHours(2.1), '2 ساعة و6 دقيقة');
    });
    test('null + negative + garbage → غير متوفر', () {
      expect(NotificationLabels.formatHours(null),
          NotificationLabels.payloadEmpty);
      expect(NotificationLabels.formatHours(-1.0),
          NotificationLabels.payloadEmpty);
      expect(NotificationLabels.formatHours('mystery'),
          NotificationLabels.payloadEmpty);
    });
  });

  group('formatWillFullBeforeSunset', () {
    test('booleans → "متوقع" / "غير متوقع"', () {
      expect(NotificationLabels.formatWillFullBeforeSunset(true), 'متوقع');
      expect(
          NotificationLabels.formatWillFullBeforeSunset(false), 'غير متوقع');
    });
    test('non-bool inputs render as غير متوفر, never as raw value', () {
      expect(NotificationLabels.formatWillFullBeforeSunset(null),
          NotificationLabels.payloadEmpty);
      expect(NotificationLabels.formatWillFullBeforeSunset('true'),
          NotificationLabels.payloadEmpty);
      expect(NotificationLabels.formatWillFullBeforeSunset(1),
          NotificationLabels.payloadEmpty);
    });
  });

  group('formatFreeText', () {
    test('trims and returns Arabic strings unchanged', () {
      expect(NotificationLabels.formatFreeText('  غيوم خفيفة 30%  '),
          'غيوم خفيفة 30%');
    });
    test('empty / null / whitespace → غير متوفر', () {
      expect(NotificationLabels.formatFreeText(''),
          NotificationLabels.payloadEmpty);
      expect(NotificationLabels.formatFreeText(null),
          NotificationLabels.payloadEmpty);
      expect(NotificationLabels.formatFreeText('   '),
          NotificationLabels.payloadEmpty);
    });
  });

  // ── v44 audit polish — Arabic technical-panel labels ──────────────
  group('technicalRowLabel', () {
    const cases = {
      'id': 'رقم الإشعار',
      'event_type': 'رمز نوع الحدث',
      'source_type': 'رمز المصدر',
      'source_id': 'مرجع الجهاز',
      'status': 'الحالة الخام',
      'is_read': 'علامة القراءة',
    };
    cases.forEach((key, arabic) {
      test('$key → $arabic', () {
        expect(NotificationLabels.technicalRowLabel(key), arabic);
      });
    });

    test('case-insensitive + whitespace tolerant', () {
      expect(NotificationLabels.technicalRowLabel('EVENT_TYPE'),
          'رمز نوع الحدث');
      expect(NotificationLabels.technicalRowLabel('  source_id  '),
          'مرجع الجهاز');
    });

    test('unknown key falls through to the raw key (no silent loss)', () {
      // The technical panel is for support tracing — if a future
      // backend addition surfaces a new key, falling back to the raw
      // key keeps it visible until a polished Arabic label is added.
      expect(
        NotificationLabels.technicalRowLabel('future_field'),
        'future_field',
      );
    });

    test('empty key returns empty string unchanged', () {
      expect(NotificationLabels.technicalRowLabel(''), '');
    });
  });
}
