import 'api_exception.dart';

/// Mirror of the backend's standard JSON envelope:
///
///   { "ok": true,  "data": {...}, "meta": {...}, "errors": [] }
///   { "ok": false, "message": "...", "code": "...", "errors": [...] }
///
/// Both shapes are produced by `app/services/api_responses.py` on the server.
class ApiResponse<T> {
  ApiResponse({
    required this.ok,
    required this.data,
    required this.meta,
    this.message,
  });

  final bool ok;
  final T data;
  final Map<String, dynamic> meta;
  final String? message;

  static ApiResponse<Map<String, dynamic>> fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw ApiException(
        message: 'استجابة غير متوقعة من الخادم.',
        kind: ApiErrorKind.decode,
      );
    }
    final ok = raw['ok'] == true;
    if (!ok) {
      // Error envelope — surface as ApiException so callers don't have to
      // check `ok` themselves.
      final errs = raw['errors'];
      final fieldErrors = (errs is List)
          ? errs
              .whereType<Map<String, dynamic>>()
              .map(ApiFieldError.fromJson)
              .toList()
          : null;
      throw ApiException(
        message: (raw['message'] ?? 'حدث خطأ غير معروف.').toString(),
        kind: _kindFromCode(raw['code']?.toString()),
        code: raw['code']?.toString(),
        fieldErrors: fieldErrors,
      );
    }
    final data = raw['data'];
    final meta = raw['meta'];
    return ApiResponse<Map<String, dynamic>>(
      ok: true,
      data: data is Map<String, dynamic> ? data : <String, dynamic>{},
      meta: meta is Map<String, dynamic> ? meta : <String, dynamic>{},
      message: raw['message']?.toString(),
    );
  }

  /// Page metadata helper — backend pagination shape is stable
  /// (page, page_size, total, pages, has_next, has_prev).
  PageMeta? get page {
    if (meta.isEmpty || meta['page'] == null) return null;
    return PageMeta(
      page: (meta['page'] ?? 1) as int,
      pageSize: (meta['page_size'] ?? 0) as int,
      total: (meta['total'] ?? 0) as int,
      pages: (meta['pages'] ?? 0) as int,
      hasNext: (meta['has_next'] ?? false) as bool,
      hasPrev: (meta['has_prev'] ?? false) as bool,
    );
  }
}

class PageMeta {
  PageMeta({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.pages,
    required this.hasNext,
    required this.hasPrev,
  });

  final int page;
  final int pageSize;
  final int total;
  final int pages;
  final bool hasNext;
  final bool hasPrev;
}

ApiErrorKind _kindFromCode(String? code) {
  switch (code) {
    case 'auth_required':
    case 'invalid_token':
    case 'invalid_credentials':
    case 'invalid_refresh_token':
      return ApiErrorKind.unauthorized;
    case 'admin_required':
    case 'forbidden':
      return ApiErrorKind.forbidden;
    case 'device_not_found':
    case 'support_case_not_found':
    case 'load_not_found':
    case 'not_found':
      return ApiErrorKind.notFound;
    case 'username_taken':
    case 'email_taken':
    case 'support_case_closed':
    case 'conflict':
      return ApiErrorKind.conflict;
    case 'quota_exceeded':
    case 'rate_limited':
      return ApiErrorKind.rateLimited;
    case 'invalid_json':
    case 'unsupported_field':
    case 'invalid_settings':
    case 'invalid_number':
    case 'invalid_boolean':
    case 'invalid_date_range':
    case 'missing_field':
    case 'missing_credentials':
    case 'missing_support_fields':
    case 'missing_reply_body':
    case 'missing_push_token':
    case 'missing_registration_fields':
    case 'weak_password':
    case 'username_too_short':
    case 'password_too_short':
    case 'password_mismatch':
    case 'invalid_timezone':
    case 'invalid_device_id':
    case 'device_required':
      return ApiErrorKind.validation;
    default:
      return ApiErrorKind.unknown;
  }
}
