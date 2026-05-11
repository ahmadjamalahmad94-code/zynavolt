// Mirror of GET /api/mobile/notifications data envelope.
//
// Field names taken verbatim from the backend payload builder
// (`_mobile_notification_event_payload` in `app/blueprints/mobile_api.py`).
// Optional fields default to safe values so a partial payload never throws.

class AppNotification {
  AppNotification({
    required this.id,
    required this.eventType,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.message,
    required this.url,
    required this.status,
    required this.isRead,
    required this.createdAt,
    required this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] ?? 0) as int,
        eventType: (json['event_type'] ?? '').toString(),
        sourceType: (json['source_type'] ?? '').toString(),
        sourceId: json['source_id'] is int ? json['source_id'] as int : null,
        title: (json['title'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        isRead: json['is_read'] == true,
        createdAt: json['created_at']?.toString(),
        readAt: json['read_at']?.toString(),
      );

  final int id;
  final String eventType;
  final String sourceType;
  final int? sourceId;
  final String title;
  final String message;
  final String url;
  final String status;
  final bool isRead;
  final String? createdAt;
  final String? readAt;

  /// Returns a copy with selected fields overridden — used after `mark-read`
  /// so the new server payload becomes the displayed item without rebuilding
  /// the whole list from scratch.
  AppNotification copyWith({
    bool? isRead,
    String? status,
    String? readAt,
  }) =>
      AppNotification(
        id: id,
        eventType: eventType,
        sourceType: sourceType,
        sourceId: sourceId,
        title: title,
        message: message,
        url: url,
        status: status ?? this.status,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
      );
}

class NotificationPageMeta {
  NotificationPageMeta({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.pages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory NotificationPageMeta.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return NotificationPageMeta(
      page: (j['page'] is int) ? j['page'] as int : 1,
      pageSize: (j['page_size'] is int) ? j['page_size'] as int : 0,
      total: (j['total'] is int) ? j['total'] as int : 0,
      pages: (j['pages'] is int) ? j['pages'] as int : 0,
      hasNext: j['has_next'] == true,
      hasPrev: j['has_prev'] == true,
    );
  }

  final int page;
  final int pageSize;
  final int total;
  final int pages;
  final bool hasNext;
  final bool hasPrev;
}

/// Wraps a `data` payload + `meta` payload into one value type so the
/// repository can return everything the UI needs from a single call.
class NotificationsPage {
  NotificationsPage({
    required this.items,
    required this.unreadCount,
    required this.meta,
  });

  factory NotificationsPage.fromEnvelope({
    required Map<String, dynamic> data,
    required Map<String, dynamic> meta,
  }) {
    final rawItems = (data['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
    final unread = data['unread_count'];
    return NotificationsPage(
      items: items,
      unreadCount: unread is int ? unread : 0,
      meta: NotificationPageMeta.fromJson(meta),
    );
  }

  final List<AppNotification> items;
  final int unreadCount;
  final NotificationPageMeta meta;
}

/// POST /api/mobile/notifications/{id}/read response payload.
class MarkReadResult {
  MarkReadResult({
    required this.changed,
    required this.unreadCount,
    required this.notification,
  });

  factory MarkReadResult.fromJson(Map<String, dynamic> json) {
    final notif = (json['notification'] as Map?)?.cast<String, dynamic>();
    return MarkReadResult(
      changed: (json['changed'] is int) ? json['changed'] as int : 0,
      unreadCount:
          (json['unread_count'] is int) ? json['unread_count'] as int : 0,
      notification: notif == null ? null : AppNotification.fromJson(notif),
    );
  }

  final int changed;
  final int unreadCount;
  final AppNotification? notification;
}

/// POST /api/mobile/notifications/read-all response payload.
class ReadAllResult {
  ReadAllResult({required this.changed, required this.unreadCount});

  factory ReadAllResult.fromJson(Map<String, dynamic> json) => ReadAllResult(
        changed: (json['changed'] is int) ? json['changed'] as int : 0,
        unreadCount:
            (json['unread_count'] is int) ? json['unread_count'] as int : 0,
      );

  final int changed;
  final int unreadCount;
}
