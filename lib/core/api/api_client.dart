import 'dart:async';

import 'package:dio/dio.dart';

import '../../app/app_config.dart';
import '../storage/secure_token_storage.dart';
import 'api_exception.dart';
import 'api_response.dart';

/// Single Dio-backed HTTP client.
///
/// - Attaches `Authorization: Bearer <access_token>` from secure storage when
///   one is present and the request is not opting out via `Options.extra`.
/// - On 401 it tries to refresh the access token exactly once using the
///   stored refresh token (calling `/api/mobile/auth/refresh`), then replays
///   the original request. If refresh fails, all tokens are cleared so the
///   router redirects the user back to login.
/// - Maps every failure into an [ApiException] with a coarse [ApiErrorKind]
///   and the locale-appropriate message returned by the backend.
///
/// Callbacks for "tokens were cleared" are exposed so the [AppSession] can
/// react without this layer importing UI code.
class ApiClient {
  ApiClient({
    required SecureTokenStorage tokenStorage,
    Dio? dio,
    void Function()? onSessionExpired,
  })  : _storage = tokenStorage,
        _dio = dio ?? _buildDio(),
        _onSessionExpired = onSessionExpired {
    _dio.interceptors.add(_AuthInterceptor(
      storage: _storage,
      refresh: _refreshAccessToken,
      onSessionExpired: () => _onSessionExpired?.call(),
    ));
  }

  static const String _skipAuthKey = 'sd_skip_auth';

  final Dio _dio;
  final SecureTokenStorage _storage;
  final void Function()? _onSessionExpired;

  /// `Options.extra[skipAuth] = true` opts a request out of Bearer attach +
  /// 401-refresh — used for login/refresh themselves.
  static Options skipAuth({Options? base}) {
    final extra = Map<String, dynamic>.from(base?.extra ?? const {});
    extra[_skipAuthKey] = true;
    return (base ?? Options()).copyWith(extra: extra);
  }

  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _send(() => _dio.get<dynamic>(path,
          queryParameters: query, options: options));

  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _send(() => _dio.post<dynamic>(path,
          data: body, queryParameters: query, options: options));

  Future<ApiResponse<Map<String, dynamic>>> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _send(() => _dio.patch<dynamic>(path,
          data: body, queryParameters: query, options: options));

  Future<ApiResponse<Map<String, dynamic>>> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _send(() => _dio.delete<dynamic>(path,
          data: body, queryParameters: query, options: options));

  Future<ApiResponse<Map<String, dynamic>>> _send(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final response = await send();
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _mapDio(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'تعذّر إكمال الطلب: $e',
        kind: ApiErrorKind.unknown,
      );
    }
  }

  Future<bool> _refreshAccessToken() async {
    final refresh = await _storage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await _dio.post<dynamic>(
        '/api/mobile/auth/refresh',
        data: {'refresh_token': refresh},
        options: skipAuth(),
      );
      final envelope = ApiResponse.fromJson(response.data);
      final token = envelope.data['access_token']?.toString();
      if (token == null || token.isEmpty) return false;
      await _storage.writeAccessToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  ApiException _mapDio(DioException e) {
    // Backend returned a structured error envelope.
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['ok'] == false) {
      try {
        ApiResponse.fromJson(data);
      } on ApiException catch (ae) {
        return ApiException(
          message: ae.message,
          kind: ae.kind == ApiErrorKind.unknown
              ? _kindFromStatus(e.response?.statusCode)
              : ae.kind,
          code: ae.code,
          status: e.response?.statusCode,
          fieldErrors: ae.fieldErrors,
        );
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'انتهت مهلة الاتصال بالخادم.',
          kind: ApiErrorKind.timeout,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'تم إلغاء الطلب.',
          kind: ApiErrorKind.cancelled,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiException(
          message: 'تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت.',
          kind: ApiErrorKind.network,
        );
      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'شهادة الخادم غير موثوقة.',
          kind: ApiErrorKind.network,
        );
      case DioExceptionType.badResponse:
        return ApiException(
          message: 'استجابة غير صالحة من الخادم.',
          kind: _kindFromStatus(e.response?.statusCode),
          status: e.response?.statusCode,
        );
    }
  }

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          'X-App-Version': AppConfig.appVersion,
          'X-App-Platform': AppConfig.appPlatform,
          'X-App-Locale': AppConfig.defaultLocale,
        },
      ),
    );
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({
    required this.storage,
    required this.refresh,
    required this.onSessionExpired,
  });

  final SecureTokenStorage storage;
  final Future<bool> Function() refresh;
  final void Function() onSessionExpired;

  bool _refreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skip = options.extra[ApiClient._skipAuthKey] == true;
    if (!skip) {
      final token = await storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final skip = err.requestOptions.extra[ApiClient._skipAuthKey] == true;
    if (status != 401 || skip || _refreshing) {
      return handler.next(err);
    }
    _refreshing = true;
    final ok = await refresh();
    _refreshing = false;
    if (!ok) {
      await storage.clearAll();
      onSessionExpired();
      return handler.next(err);
    }
    // Replay the original request with the fresh token.
    try {
      final token = await storage.readAccessToken();
      final retried = await Dio(err.requestOptions.copyWithBaseOptions()).fetch(
        err.requestOptions
          ..headers['Authorization'] =
              token == null || token.isEmpty ? null : 'Bearer $token',
      );
      return handler.resolve(retried);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}

extension on RequestOptions {
  /// Build a fresh BaseOptions clone for the retry Dio instance.
  BaseOptions copyWithBaseOptions() => BaseOptions(
        method: method,
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: Map<String, dynamic>.from(headers),
        responseType: responseType,
        contentType: contentType,
        validateStatus: validateStatus,
        followRedirects: followRedirects,
        maxRedirects: maxRedirects,
        extra: Map<String, dynamic>.from(extra),
      );
}

ApiErrorKind _kindFromStatus(int? status) {
  if (status == null) return ApiErrorKind.unknown;
  if (status == 401) return ApiErrorKind.unauthorized;
  if (status == 403) return ApiErrorKind.forbidden;
  if (status == 404) return ApiErrorKind.notFound;
  if (status == 409) return ApiErrorKind.conflict;
  if (status == 422 || status == 400) return ApiErrorKind.validation;
  if (status == 429) return ApiErrorKind.rateLimited;
  if (status >= 500) return ApiErrorKind.server;
  return ApiErrorKind.unknown;
}
