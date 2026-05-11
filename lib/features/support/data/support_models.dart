// Mirror of GET /api/v1/support/cases and /api/v1/support/cases/<kind>/<id>.
//
// Backend builders: `_case_payload` and `_messages_for` in
// `app/blueprints/mobile_support_api.py`. v50 is **read-only**: no create,
// no reply, no reopen, no canned replies.

class SupportCase {
  SupportCase({
    required this.type,
    required this.id,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lastReplyAt,
    required this.relatedDeviceId,
  });

  factory SupportCase.fromJson(Map<String, dynamic> json) {
    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    return SupportCase(
      type: (json['type'] ?? '').toString(),
      id: iOrNull(json['id']) ?? 0,
      subject: (json['subject'] ?? '').toString(),
      category: json['category']?.toString(),
      priority: json['priority']?.toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      lastReplyAt: json['last_reply_at']?.toString(),
      relatedDeviceId: iOrNull(json['related_device_id']),
    );
  }

  /// `'message'` (internal mail thread) or `'ticket'` (support ticket).
  /// Used as the path-segment when requesting detail.
  final String type;
  final int id;
  final String subject;
  final String? category;
  final String? priority;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final String? lastReplyAt;

  /// Only populated when [type] is `'ticket'`.
  final int? relatedDeviceId;
}

/// One message inside a support case thread. Read-only. Mirrors
/// `_messages_for(...)` in the backend — `is_internal_note=true` rows are
/// filtered server-side for non-admin users, so we never see them.
class SupportMessage {
  SupportMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.senderScope,
    required this.senderUserId,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    return SupportMessage(
      id: iOrNull(json['id']) ?? 0,
      body: (json['body'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
      senderScope: (json['sender_scope'] ?? '').toString(),
      senderUserId: iOrNull(json['sender_user_id']),
    );
  }

  final int id;
  final String body;
  final String? createdAt;

  /// `'admin'` or `'user'` (free-form on the backend — we surface as-is).
  final String senderScope;
  final int? senderUserId;
}

class SupportCaseDetail {
  SupportCaseDetail({required this.summary, required this.messages});

  factory SupportCaseDetail.fromJson(Map<String, dynamic> json) {
    final summary = SupportCase.fromJson(json);
    final raw = json['messages'];
    final messages = <SupportMessage>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map<String, dynamic>) {
          messages.add(SupportMessage.fromJson(entry));
        } else if (entry is Map) {
          messages.add(SupportMessage.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
    return SupportCaseDetail(summary: summary, messages: messages);
  }

  final SupportCase summary;
  final List<SupportMessage> messages;
}

class SupportCasesPage {
  SupportCasesPage({required this.items});

  factory SupportCasesPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = <SupportCase>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map<String, dynamic>) {
          items.add(SupportCase.fromJson(entry));
        } else if (entry is Map) {
          items.add(SupportCase.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
    return SupportCasesPage(items: items);
  }

  final List<SupportCase> items;
}
