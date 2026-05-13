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
      // v69: stable empty list when the v68 backend hasn't yet
      // shipped attachments or the message has none.
      expect(m.attachments, isEmpty);
    });

    // v69: ── attachment payload tests ────────────────────────────

    test('parses v68 attachments[] embedded in the message', () {
      final m = SupportMessage.fromJson(const {
        'id': 10,
        'body': 'بدأ المشكلة قبل ساعتين.',
        'sender_scope': 'user',
        'attachments': [
          {
            'id': 55,
            'original_filename': 'screenshot.png',
            'content_type': 'image/png',
            'file_size': 204800,
            'download_url':
                '/api/v1/support/cases/ticket/10/attachments/55',
            'created_at': '2026-05-12T10:00:00',
          },
          {
            'id': 56,
            'original_filename': 'logs.zip',
            'content_type': 'application/zip',
            'file_size': 4500000,
            'download_url':
                '/api/v1/support/cases/ticket/10/attachments/56',
          },
        ],
      });
      expect(m.attachments.length, 2);
      final first = m.attachments.first;
      expect(first.id, 55);
      expect(first.originalFilename, 'screenshot.png');
      expect(first.contentType, 'image/png');
      expect(first.fileSize, 204800);
      expect(first.downloadUrl,
          '/api/v1/support/cases/ticket/10/attachments/55');
      expect(first.createdAt, '2026-05-12T10:00:00');
      expect(first.displayName, 'screenshot.png');
      expect(first.humanSize, '200.0 KB');

      final second = m.attachments.last;
      expect(second.id, 56);
      expect(second.humanSize, '4.3 MB');
      // Missing `created_at` falls back to null.
      expect(second.createdAt, isNull);
    });

    test('attachments missing/null/garbage entries are dropped', () {
      final m = SupportMessage.fromJson(const {
        'id': 10,
        'attachments': [
          {
            'id': 1,
            'original_filename': 'guide.pdf',
            'content_type': 'application/pdf',
            'file_size': 1024,
            'download_url': '/api/v1/support/cases/ticket/10/attachments/1',
          },
          null,
          'not a map',
        ],
      });
      expect(m.attachments.length, 1);
      expect(m.attachments.first.originalFilename, 'guide.pdf');
    });

    test('SupportAttachment.displayName falls back to "مرفق #ID"', () {
      final att = SupportAttachment.fromJson(const {
        'id': 7,
        'original_filename': '',
        'content_type': '',
        'file_size': 0,
        'download_url': '/api/v1/support/cases/message/3/attachments/7',
      });
      expect(att.displayName, 'مرفق #7');
      // file_size==0 → humanSize returns empty so the UI can skip the row.
      expect(att.humanSize, '');
    });

    test('SupportAttachment.humanSize formats B / KB / MB cleanly', () {
      SupportAttachment build(int size) => SupportAttachment.fromJson({
            'id': 1,
            'original_filename': 'x',
            'content_type': '',
            'file_size': size,
            'download_url': '/x',
          });
      expect(build(0).humanSize, '');
      expect(build(512).humanSize, '512 B');
      expect(build(1024).humanSize, '1.0 KB');
      expect(build(1500).humanSize, '1.5 KB');
      expect(build(1024 * 1024).humanSize, '1.0 MB');
      expect(build(10 * 1024 * 1024).humanSize, '10.0 MB');
    });

    test('SupportAttachment defensively handles stringified numbers', () {
      final att = SupportAttachment.fromJson(const {
        'id': '7',
        'original_filename': 'note.txt',
        'content_type': 'text/plain',
        'file_size': '1024',
        'download_url': '/api/v1/support/cases/ticket/3/attachments/7',
      });
      expect(att.id, 7);
      expect(att.fileSize, 1024);
      expect(att.humanSize, '1.0 KB');
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

  // v72: ── upload result models ──────────────────────────────────

  group('RejectedAttachment', () {
    test('parses the full v71 rejection row', () {
      final r = RejectedAttachment.fromJson(const {
        'filename': 'virus.exe',
        'reason_code': 'unsupported_extension',
        'reason_message': 'نوع الملف غير مدعوم.',
      });
      expect(r.filename, 'virus.exe');
      expect(r.reasonCode, 'unsupported_extension');
      expect(r.reasonMessage, 'نوع الملف غير مدعوم.');
    });

    test('handles missing keys defensively', () {
      final r = RejectedAttachment.fromJson(const {});
      expect(r.filename, '');
      expect(r.reasonCode, '');
      expect(r.reasonMessage, '');
    });
  });

  group('SupportSubmissionResult', () {
    test('parses case payload + saved + rejected lists', () {
      final r = SupportSubmissionResult.fromJson(const {
        'type': 'ticket',
        'id': 10,
        'subject': 'with attachments',
        'status': 'open',
        'messages': [
          {
            'id': 99,
            'body': 'تم إرفاق الملف.',
            'sender_scope': 'user',
            'attachments': [
              {
                'id': 55,
                'original_filename': 'guide.pdf',
                'content_type': 'application/pdf',
                'file_size': 100000,
                'download_url':
                    '/api/v1/support/cases/ticket/10/attachments/55',
              },
            ],
          },
        ],
        'attachments': [
          {
            'id': 55,
            'original_filename': 'guide.pdf',
            'content_type': 'application/pdf',
            'file_size': 100000,
            'download_url':
                '/api/v1/support/cases/ticket/10/attachments/55',
            'created_at': '2026-05-12T10:00:00',
          },
        ],
        'rejected_attachments': [
          {
            'filename': 'virus.exe',
            'reason_code': 'unsupported_extension',
            'reason_message': 'نوع الملف غير مدعوم.',
          },
        ],
      });

      // Case detail parses via the existing path.
      expect(r.caseDetail.summary.id, 10);
      expect(r.caseDetail.summary.type, 'ticket');
      expect(r.caseDetail.messages.length, 1);
      expect(r.caseDetail.messages.first.attachments.length, 1);

      // Per-submission saved list.
      expect(r.savedAttachments.length, 1);
      expect(r.savedAttachments.first.originalFilename, 'guide.pdf');

      // Per-submission rejected list.
      expect(r.rejectedAttachments.length, 1);
      expect(r.rejectedAttachments.first.reasonCode, 'unsupported_extension');
    });

    test('empty attachments + rejected_attachments keys default to []', () {
      final r = SupportSubmissionResult.fromJson(const {
        'type': 'message',
        'id': 1,
        'subject': 'plain',
        'status': 'open',
        'messages': [],
      });
      expect(r.savedAttachments, isEmpty);
      expect(r.rejectedAttachments, isEmpty);
    });

    test('non-map entries in either list are dropped', () {
      final r = SupportSubmissionResult.fromJson(const {
        'type': 'ticket',
        'id': 7,
        'subject': '',
        'status': 'open',
        'messages': [],
        'attachments': [
          null,
          'garbage',
          {
            'id': 1,
            'original_filename': 'ok.pdf',
            'content_type': 'application/pdf',
            'file_size': 10,
            'download_url': '/api/v1/support/cases/ticket/7/attachments/1',
          },
        ],
        'rejected_attachments': [
          42,
          {
            'filename': 'bad.exe',
            'reason_code': 'unsupported_extension',
            'reason_message': '',
          },
        ],
      });
      expect(r.savedAttachments.length, 1);
      expect(r.savedAttachments.first.originalFilename, 'ok.pdf');
      expect(r.rejectedAttachments.length, 1);
      expect(r.rejectedAttachments.first.filename, 'bad.exe');
    });
  });
}
