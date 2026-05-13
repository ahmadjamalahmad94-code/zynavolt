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

/// v69: one attachment row exposed by the v68 backend on each
/// message in a support case thread. Read-only; mobile never writes
/// this shape — upload is deferred to a later wave.
///
/// The `downloadUrl` is a relative path that the existing
/// `ApiClient` resolves against `AppConfig.apiBaseUrl`. It MUST be
/// hit with a bearer token (the backend route is owner-scoped); we
/// never expose it to an external browser launch.
class SupportAttachment {
  SupportAttachment({
    required this.id,
    required this.originalFilename,
    required this.contentType,
    required this.fileSize,
    required this.downloadUrl,
    required this.createdAt,
  });

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    int i(Object? v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return SupportAttachment(
      id: i(json['id']),
      originalFilename: (json['original_filename'] ?? '').toString(),
      contentType: (json['content_type'] ?? '').toString(),
      fileSize: i(json['file_size']),
      downloadUrl: (json['download_url'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  final int id;
  final String originalFilename;
  final String contentType;
  final int fileSize;
  final String downloadUrl;
  final String? createdAt;

  /// Best-effort display name with a sensible fallback so the UI
  /// never renders an empty chip even on a malformed row.
  String get displayName {
    final trimmed = originalFilename.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'مرفق #$id';
  }

  /// "12.5 KB" / "3.4 MB" / "0 B" — calm size formatting. Returns
  /// an empty string for `fileSize == 0` so the UI can skip the
  /// row when the server didn't capture a size (rare).
  String get humanSize {
    final size = fileSize;
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    final kb = size / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }
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
    required this.attachments,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    // v69: per-message attachments. Always a list — older backends
    // that haven't shipped v68 yet simply omit the key and we
    // surface an empty list instead of crashing.
    final rawAttachments = json['attachments'];
    final attachments = <SupportAttachment>[];
    if (rawAttachments is List) {
      for (final entry in rawAttachments) {
        if (entry is Map<String, dynamic>) {
          attachments.add(SupportAttachment.fromJson(entry));
        } else if (entry is Map) {
          attachments.add(SupportAttachment.fromJson(
            entry.cast<String, dynamic>(),
          ));
        }
      }
    }

    return SupportMessage(
      id: iOrNull(json['id']) ?? 0,
      body: (json['body'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
      senderScope: (json['sender_scope'] ?? '').toString(),
      senderUserId: iOrNull(json['sender_user_id']),
      attachments: attachments,
    );
  }

  final int id;
  final String body;
  final String? createdAt;

  /// `'admin'` or `'user'` (free-form on the backend — we surface as-is).
  final String senderScope;
  final int? senderUserId;

  /// v69: attachments uploaded with this message. Empty list when
  /// the message carries no attachments. Stable shape so the UI
  /// never needs a null-check.
  final List<SupportAttachment> attachments;
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

/// v72: one rejected file row from the v71 backend's
/// `rejected_attachments[]` envelope key. `reasonCode` is the stable
/// machine-readable code (`unsupported_extension` / `file_too_large`)
/// the mobile UI maps onto its own Arabic copy; `reasonMessage` is
/// the backend's calm fallback when no localised override applies.
class RejectedAttachment {
  RejectedAttachment({
    required this.filename,
    required this.reasonCode,
    required this.reasonMessage,
  });

  factory RejectedAttachment.fromJson(Map<String, dynamic> json) {
    return RejectedAttachment(
      filename: (json['filename'] ?? '').toString(),
      reasonCode: (json['reason_code'] ?? '').toString(),
      reasonMessage: (json['reason_message'] ?? '').toString(),
    );
  }

  final String filename;
  final String reasonCode;
  final String reasonMessage;
}

/// v72: full envelope returned by `POST /api/v1/support/cases` and
/// `POST /api/v1/support/cases/<kind>/<id>/reply` after v71. The
/// case payload itself is parsed via the existing
/// `SupportCaseDetail.fromJson`; the two additive top-level keys
/// (`attachments`, `rejected_attachments`) are split out as
/// `savedAttachments` + `rejectedAttachments` so the calling UI
/// can render a per-submission summary distinct from the
/// thread-level `messages[].attachments` history.
class SupportSubmissionResult {
  SupportSubmissionResult({
    required this.caseDetail,
    required this.savedAttachments,
    required this.rejectedAttachments,
  });

  factory SupportSubmissionResult.fromJson(Map<String, dynamic> json) {
    final saved = <SupportAttachment>[];
    final rejected = <RejectedAttachment>[];

    final rawSaved = json['attachments'];
    if (rawSaved is List) {
      for (final entry in rawSaved) {
        if (entry is Map<String, dynamic>) {
          saved.add(SupportAttachment.fromJson(entry));
        } else if (entry is Map) {
          saved.add(SupportAttachment.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }

    final rawRejected = json['rejected_attachments'];
    if (rawRejected is List) {
      for (final entry in rawRejected) {
        if (entry is Map<String, dynamic>) {
          rejected.add(RejectedAttachment.fromJson(entry));
        } else if (entry is Map) {
          rejected.add(
            RejectedAttachment.fromJson(entry.cast<String, dynamic>()),
          );
        }
      }
    }

    return SupportSubmissionResult(
      caseDetail: SupportCaseDetail.fromJson(json),
      savedAttachments: saved,
      rejectedAttachments: rejected,
    );
  }

  final SupportCaseDetail caseDetail;

  /// Attachments persisted **by this submission specifically**. Distinct
  /// from `caseDetail.messages[].attachments` which is the thread-level
  /// history including earlier uploads.
  final List<SupportAttachment> savedAttachments;

  /// Files the backend refused to persist for this submission. Always
  /// a list (empty when every file was accepted or no files were sent).
  final List<RejectedAttachment> rejectedAttachments;
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
