/// Centralised error model. Every layer above the API client converts raw
/// network/decode failures into one of these so screens render uniformly.
class ApiException implements Exception {
  ApiException({
    required this.message,
    required this.kind,
    this.code,
    this.status,
    this.fieldErrors,
  });

  /// Human-readable message in the active locale. Safe to display directly.
  final String message;

  /// Coarse category — drives which empty/error widget the UI shows.
  final ApiErrorKind kind;

  /// Backend-supplied machine code (e.g. `auth_required`, `quota_exceeded`).
  /// Null for client-side failures (network, decode).
  final String? code;

  /// HTTP status. Null for client-side failures.
  final int? status;

  /// Optional per-field errors when the backend reports validation failures.
  final List<ApiFieldError>? fieldErrors;

  bool get isAuth => kind == ApiErrorKind.unauthorized;
  bool get isNetwork => kind == ApiErrorKind.network;
  bool get isServer => kind == ApiErrorKind.server;
  bool get isValidation => kind == ApiErrorKind.validation;

  @override
  String toString() =>
      'ApiException(kind: $kind, status: $status, code: $code, message: $message)';
}

class ApiFieldError {
  ApiFieldError({required this.field, required this.message});

  factory ApiFieldError.fromJson(Map<String, dynamic> json) => ApiFieldError(
        field: (json['field'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
      );

  final String field;
  final String message;
}

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  rateLimited,
  server,
  decode,
  cancelled,
  unknown,
}
