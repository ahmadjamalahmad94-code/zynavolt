import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/notifications/data/notification_models.dart';
import 'package:solardeye_mobile/features/notifications/data/notification_scope.dart';

/// v96 classifier short-circuit tests.
///
/// Backend v43 stamps every mirrored energy/load/solar/weather
/// notification with `source_type = "energy"`. The mobile classifier
/// must trust that structured signal first — no Arabic/English keyword
/// matching, no ambiguity. The keyword fallback is preserved for
/// notifications that don't carry the structured signal.
void main() {
  AppNotification make({
    String eventType = '',
    String sourceType = '',
    String title = '',
    String message = '',
  }) =>
      AppNotification(
        id: 1,
        eventType: eventType,
        sourceType: sourceType,
        sourceId: null,
        title: title,
        message: message,
        url: '',
        status: 'new',
        isRead: false,
        createdAt: '2026-05-11T10:00:00',
        readAt: null,
      );

  group('source_type=energy short-circuit', () {
    test('routes to Energy tab even when title/message have no keywords',
        () {
      // Pretend the backend mirrored a generic status update with a
      // title/message that contains zero energy keywords.
      final n = make(
        sourceType: 'energy',
        eventType: '',
        title: 'تنبيه',
        message: 'حدث جديد.',
      );
      expect(classifyNotification(n), NotificationScope.energy);
    });

    test('case-insensitive + trims whitespace on source_type', () {
      expect(
        classifyNotification(make(sourceType: '  ENERGY  ')),
        NotificationScope.energy,
      );
      expect(
        classifyNotification(make(sourceType: 'Energy')),
        NotificationScope.energy,
      );
    });
  });

  group('v43 event_type whitelist short-circuit', () {
    const v43Whitelist = [
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
    ];

    for (final ev in v43Whitelist) {
      test('event_type=$ev → Energy tab even with empty source_type', () {
        // No source_type, no keyword-rich title/message — the classifier
        // must still route by the structured event_type alone.
        final n = make(
          eventType: ev,
          sourceType: '',
          title: '',
          message: '',
        );
        expect(classifyNotification(n), NotificationScope.energy);
      });
    }
  });

  group('keyword fallback (preserved)', () {
    test('Arabic battery keyword still routes to Energy tab', () {
      final n = make(title: 'انخفضت البطارية إلى 15%.');
      expect(classifyNotification(n), NotificationScope.energy);
    });

    test('support source_type still routes to App tab', () {
      final n = make(
        sourceType: 'support',
        eventType: 'support_case',
        title: 'تذكرة دعم جديدة',
      );
      expect(classifyNotification(n), NotificationScope.app);
    });

    test('account source_type still routes to App tab', () {
      final n = make(
        sourceType: 'account',
        eventType: 'subscription',
        title: 'تجديد الاشتراك',
      );
      expect(classifyNotification(n), NotificationScope.app);
    });
  });

  group('safe default', () {
    test('completely empty notification defaults to App tab', () {
      final n = make();
      expect(classifyNotification(n), NotificationScope.app);
    });

    test('unknown source_type without energy keywords defaults to App', () {
      final n = make(
        sourceType: 'mystery',
        eventType: 'unknown_event',
        title: 'Hello',
      );
      expect(classifyNotification(n), NotificationScope.app);
    });
  });

  group('source_type=energy beats App keywords', () {
    test('source_type=energy with the word "support" in title still Energy',
        () {
      // The structured signal is the source of truth. A coincidental
      // App-keyword match in the body must NOT pull the row off Energy.
      final n = make(
        sourceType: 'energy',
        eventType: 'load_alert',
        title: 'تنبيه أحمال — راجع الدعم لاحقاً',
        message: 'الحمل الليلي مرتفع.',
      );
      expect(classifyNotification(n), NotificationScope.energy);
    });
  });
}
