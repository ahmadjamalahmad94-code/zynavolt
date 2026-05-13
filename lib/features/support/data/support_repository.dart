import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/multipart_file_spec.dart';
import '../../../core/state/api_providers.dart';
import 'support_models.dart';

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  /// GET /api/v1/support/cases — list of the user's support cases (mail
  /// threads + tickets). v50 ships read-only, no filters.
  Future<SupportCasesPage> list() async {
    final response = await _api.get('/api/v1/support/cases');
    return SupportCasesPage.fromJson(response.data);
  }

  /// `GET /api/v1/support/cases/:kind/:id` — single case with messages.
  /// `kind` must be `'message'` or `'ticket'` — taken from the case
  /// summary's `type` field, never user-typed.
  Future<SupportCaseDetail> fetch(String kind, int id) async {
    final response = await _api.get('/api/v1/support/cases/$kind/$id');
    return SupportCaseDetail.fromJson(response.data);
  }

  /// v88 + v72: `POST /api/v1/support/cases/:kind/:id/reply` — add a
  /// user-side reply. Backend rejects closed/resolved cases for
  /// non-admin users with `support_case_closed` (409).
  ///
  /// When `attachments` is empty (the default), the request uses the
  /// existing JSON path — backwards compatible with the v88 contract.
  /// When `attachments` is non-empty, the request goes out as
  /// `multipart/form-data` consumed by the v71 backend.
  Future<SupportSubmissionResult> reply({
    required String kind,
    required int id,
    required String body,
    List<MultipartFileSpec> attachments = const [],
  }) async {
    final response = attachments.isEmpty
        ? await _api.post(
            '/api/v1/support/cases/$kind/$id/reply',
            body: {'body': body},
          )
        : await _api.postMultipart(
            '/api/v1/support/cases/$kind/$id/reply',
            fields: {'body': body},
            files: attachments,
          );
    return SupportSubmissionResult.fromJson(response.data);
  }

  /// v88 + v72: `POST /api/v1/support/cases` — open a new support case.
  /// `kind` is `'message'` (default) or `'ticket'`. Subject + body are
  /// required (backend rejects empty values with `missing_support_fields`).
  ///
  /// Same dual-path behaviour as `reply`: empty `attachments` keeps the
  /// existing JSON contract; non-empty switches to multipart against
  /// the v71 backend.
  Future<SupportSubmissionResult> createCase({
    required String subject,
    required String body,
    String kind = 'message',
    String priority = 'normal',
    List<MultipartFileSpec> attachments = const [],
  }) async {
    final response = attachments.isEmpty
        ? await _api.post(
            '/api/v1/support/cases',
            body: {
              'type': kind,
              'subject': subject,
              'body': body,
              'priority': priority,
            },
          )
        : await _api.postMultipart(
            '/api/v1/support/cases',
            fields: {
              'type': kind,
              'subject': subject,
              'body': body,
              'priority': priority,
            },
            files: attachments,
          );
    return SupportSubmissionResult.fromJson(response.data);
  }

  /// v69: download the bytes for one support attachment via the
  /// v68 backend route. `downloadPath` is the relative
  /// `/api/v1/support/cases/<kind>/<case_id>/attachments/<id>` URL
  /// emitted by the backend on each attachment row — never user-
  /// constructed, never hardcoded.
  ///
  /// On 410 the backend signals that the row exists but the
  /// underlying file is missing (Render ephemeral-storage case).
  /// We forward the `ApiException` so the calling UI can map the
  /// `code='attachment_storage_missing'` onto calm Arabic copy.
  Future<Uint8List> downloadAttachment(String downloadPath) {
    return _api.getBytes(downloadPath);
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(apiClientProvider));
});

final supportCasesProvider = FutureProvider<SupportCasesPage>((ref) {
  return ref.watch(supportRepositoryProvider).list();
});

/// Per (kind, id) detail family. Keyed on a record so multiple opens of
/// the same case reuse the same in-flight fetch.
final supportCaseDetailProvider =
    FutureProvider.family<SupportCaseDetail, ({String kind, int id})>(
  (ref, key) =>
      ref.watch(supportRepositoryProvider).fetch(key.kind, key.id),
);
