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
}
