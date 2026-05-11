import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/support/data/support_models.dart';

void main() {
  group('SupportCase', () {
    test('parses a complete ticket payload from /support/cases', () {
      final c = SupportCase.fromJson(const {
        'type': 'ticket',
        'id': 7,
        'tenant_id': 3,
        'owner_user_id': 11,
        'assigned_admin_user_id': 1,
        'subject': 'فقدان الاتصال بالعاكس',
        'category': 'connectivity',
        'priority': 'high',
        'status': 'open',
        'last_reply_at': '2026-05-10T08:00:00',
        'created_at': '2026-05-09T14:00:00',
        'updated_at': '2026-05-10T08:05:00',
        'related_device_id': 42,
      });

      expect(c.type, 'ticket');
      expect(c.id, 7);
      expect(c.subject, 'فقدان الاتصال بالعاكس');
      expect(c.category, 'connectivity');
      expect(c.priority, 'high');
      expect(c.status, 'open');
      expect(c.createdAt, '2026-05-09T14:00:00');
      expect(c.updatedAt, '2026-05-10T08:05:00');
      expect(c.lastReplyAt, '2026-05-10T08:00:00');
      expect(c.relatedDeviceId, 42);
    });

    test('parses a mail-thread payload (no related_device_id)', () {
      final c = SupportCase.fromJson(const {
        'type': 'message',
        'id': 12,
        'subject': 'استفسار حول الفاتورة',
        'status': 'pending',
      });

      expect(c.type, 'message');
      expect(c.id, 12);
      expect(c.subject, 'استفسار حول الفاتورة');
      expect(c.status, 'pending');
      expect(c.relatedDeviceId, isNull);
      expect(c.category, isNull);
      expect(c.priority, isNull);
    });

    test('handles minimal/empty payload defensively', () {
      final c = SupportCase.fromJson(const {});
      expect(c.id, 0);
      expect(c.type, '');
      expect(c.subject, '');
      expect(c.status, '');
      expect(c.relatedDeviceId, isNull);
    });

    test('unknown / extra fields do not break parsing', () {
      final c = SupportCase.fromJson(const {
        'id': 1,
        'subject': 'X',
        'experimental_flag': true,
        'future_metric': {'a': 'b'},
      });
      expect(c.id, 1);
      expect(c.subject, 'X');
    });
  });

  group('SupportMessage', () {
    test('parses a complete message payload', () {
      final m = SupportMessage.fromJson(const {
        'id': 99,
        'sender_user_id': 11,
        'sender_scope': 'user',
        'is_internal_note': false,
        'body': 'مرحباً، هل يمكنكم المساعدة؟',
        'created_at': '2026-05-09T14:00:00',
      });
      expect(m.id, 99);
      expect(m.body, 'مرحباً، هل يمكنكم المساعدة؟');
      expect(m.senderScope, 'user');
      expect(m.senderUserId, 11);
      expect(m.createdAt, '2026-05-09T14:00:00');
    });

    test('handles missing optional fields defensively', () {
      final m = SupportMessage.fromJson(const {'id': 5});
      expect(m.id, 5);
      expect(m.body, '');
      expect(m.senderScope, '');
      expect(m.senderUserId, isNull);
      expect(m.createdAt, isNull);
    });
  });

  group('SupportCaseDetail', () {
    test('parses summary + ordered messages', () {
      final d = SupportCaseDetail.fromJson(const {
        'type': 'ticket',
        'id': 7,
        'subject': 'Q',
        'status': 'open',
        'messages': [
          {'id': 1, 'body': 'A', 'sender_scope': 'user'},
          {'id': 2, 'body': 'B', 'sender_scope': 'admin'},
        ],
      });
      expect(d.summary.id, 7);
      expect(d.summary.subject, 'Q');
      expect(d.messages.length, 2);
      expect(d.messages.first.body, 'A');
      expect(d.messages.first.senderScope, 'user');
      expect(d.messages.last.senderScope, 'admin');
    });

    test('handles missing messages list', () {
      final d = SupportCaseDetail.fromJson(const {
        'type': 'message',
        'id': 1,
        'subject': '',
        'status': '',
      });
      expect(d.messages, isEmpty);
    });
  });

  group('SupportCasesPage', () {
    test('parses items list', () {
      final p = SupportCasesPage.fromJson(const {
        'items': [
          {'type': 'ticket', 'id': 1, 'subject': 'A', 'status': 'open'},
          {'type': 'message', 'id': 2, 'subject': 'B', 'status': 'closed'},
        ],
      });
      expect(p.items.length, 2);
      expect(p.items.first.type, 'ticket');
      expect(p.items.last.type, 'message');
    });

    test('handles empty / missing items', () {
      expect(SupportCasesPage.fromJson(const {}).items, isEmpty);
      expect(SupportCasesPage.fromJson(const {'items': []}).items, isEmpty);
    });
  });
}
