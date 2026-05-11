import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/notifications/data/notification_models.dart';

void main() {
  group('AppNotification', () {
    test('parses a complete payload from /api/mobile/notifications', () {
      final n = AppNotification.fromJson(const {
        'id': 88,
        'event_type': 'support',
        'source_type': 'ticket',
        'source_id': 12,
        'title': 'تذكرة دعم جديدة',
        'message': 'تم فتح تذكرة دعم جديدة باسم "عطل في البطارية".',
        'url': '/portal/support',
        'status': 'new',
        'is_read': false,
        'appeared_in_bell': true,
        'delivered_to_user': true,
        'created_at': '2026-05-11T10:00:00.123456',
        'read_at': null,
      });

      expect(n.id, 88);
      expect(n.eventType, 'support');
      expect(n.sourceType, 'ticket');
      expect(n.sourceId, 12);
      expect(n.title, 'تذكرة دعم جديدة');
      expect(n.message.contains('البطارية'), isTrue);
      expect(n.url, '/portal/support');
      expect(n.status, 'new');
      expect(n.isRead, isFalse);
      expect(n.createdAt, '2026-05-11T10:00:00.123456');
      expect(n.readAt, isNull);
    });

    test('handles a minimal payload with optional fields missing', () {
      final n = AppNotification.fromJson(const {
        'id': 1,
        'is_read': true,
      });

      expect(n.id, 1);
      expect(n.eventType, '');
      expect(n.sourceType, '');
      expect(n.sourceId, isNull);
      expect(n.title, '');
      expect(n.message, '');
      expect(n.url, '');
      expect(n.status, '');
      expect(n.isRead, isTrue);
      expect(n.createdAt, isNull);
      expect(n.readAt, isNull);
    });

    test('copyWith only overrides supplied fields', () {
      final n = AppNotification.fromJson(const {
        'id': 5,
        'title': 'A',
        'message': 'B',
        'is_read': false,
        'status': 'new',
        'created_at': '2026-05-11T10:00:00',
      });
      final updated =
          n.copyWith(isRead: true, status: 'read', readAt: '2026-05-11T11:00:00');

      expect(updated.id, 5);
      expect(updated.title, 'A');
      expect(updated.message, 'B');
      expect(updated.isRead, isTrue);
      expect(updated.status, 'read');
      expect(updated.readAt, '2026-05-11T11:00:00');
      expect(updated.createdAt, '2026-05-11T10:00:00');
    });
  });

  group('NotificationsPage', () {
    test('parses items + unread_count + page meta', () {
      final page = NotificationsPage.fromEnvelope(
        data: const {
          'items': [
            {'id': 1, 'title': 'one', 'is_read': false},
            {'id': 2, 'title': 'two', 'is_read': true},
          ],
          'unread_count': 1,
          'order': 'newest_first',
        },
        meta: const {
          'page': 1,
          'page_size': 20,
          'total': 42,
          'pages': 3,
          'has_next': true,
          'has_prev': false,
        },
      );

      expect(page.items, hasLength(2));
      expect(page.items.first.id, 1);
      expect(page.items.first.title, 'one');
      expect(page.unreadCount, 1);
      expect(page.meta.page, 1);
      expect(page.meta.pageSize, 20);
      expect(page.meta.total, 42);
      expect(page.meta.pages, 3);
      expect(page.meta.hasNext, isTrue);
      expect(page.meta.hasPrev, isFalse);
    });

    test('handles an empty feed safely', () {
      final page = NotificationsPage.fromEnvelope(
        data: const {'items': [], 'unread_count': 0, 'order': 'newest_first'},
        meta: const {
          'page': 1,
          'page_size': 20,
          'total': 0,
          'pages': 0,
          'has_next': false,
          'has_prev': false,
        },
      );

      expect(page.items, isEmpty);
      expect(page.unreadCount, 0);
      expect(page.meta.hasNext, isFalse);
    });

    test('handles a missing items list defensively', () {
      final page = NotificationsPage.fromEnvelope(
        data: const {},
        meta: const {},
      );

      expect(page.items, isEmpty);
      expect(page.unreadCount, 0);
      expect(page.meta.page, 1);
      expect(page.meta.hasNext, isFalse);
    });
  });

  group('Action result models', () {
    test('MarkReadResult parses changed + unread_count + nested notification',
        () {
      final result = MarkReadResult.fromJson(const {
        'changed': 1,
        'unread_count': 4,
        'notification': {
          'id': 7,
          'title': 'X',
          'is_read': true,
          'status': 'read',
          'read_at': '2026-05-11T11:00:00',
        },
      });

      expect(result.changed, 1);
      expect(result.unreadCount, 4);
      expect(result.notification, isNotNull);
      expect(result.notification!.id, 7);
      expect(result.notification!.isRead, isTrue);
      expect(result.notification!.status, 'read');
    });

    test('MarkReadResult tolerates missing notification body', () {
      final result = MarkReadResult.fromJson(const {
        'changed': 0,
        'unread_count': 3,
      });
      expect(result.changed, 0);
      expect(result.unreadCount, 3);
      expect(result.notification, isNull);
    });

    test('ReadAllResult parses changed + unread_count', () {
      final result = ReadAllResult.fromJson(const {
        'changed': 12,
        'unread_count': 0,
      });
      expect(result.changed, 12);
      expect(result.unreadCount, 0);
    });
  });
}
