import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

typedef OnSessionExpired = void Function();

enum _RefreshOutcome { success, invalid, network }

/// Dio client with JWT attach, single-flight refresh, and retries on
/// transient Android connection aborts (errno 103).
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    OnSessionExpired? onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _onSessionExpired = onSessionExpired {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiV1,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-App-Version': Env.appVersion,
        },
      ),
    );

    if (!kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 20);
          // Short idle timeout so Android does not reuse a half-dead socket
          // (errno 103 Software caused connection abort).
          client.idleTimeout = const Duration(seconds: 8);
          if (Env.enableSslPinning && Env.sslFingerprints.isNotEmpty) {
            client.badCertificateCallback =
                (X509Certificate cert, String host, int port) {
              final certDer = cert.der;
              final sha256Fingerprint =
                  sha256.convert(certDer).toString().toLowerCase();
              return Env.sslFingerprints.contains(sha256Fingerprint);
            };
          }
          return client;
        },
      );
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_isAnonymousPath(options.path)) {
            final token = await _validAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (_isTransient(error) &&
              (error.requestOptions.extra['netRetries'] as int? ?? 0) < 3) {
            final opts = error.requestOptions;
            final n = (opts.extra['netRetries'] as int? ?? 0) + 1;
            opts.extra['netRetries'] = n;
            await Future<void>.delayed(Duration(milliseconds: 350 * n));
            try {
              return handler.resolve(await _dio.fetch(opts));
            } catch (e) {
              if (e is DioException) {
                error = e;
              } else {
                return handler.next(error);
              }
            }
          }

          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true &&
              !_isAnonymousPath(error.requestOptions.path)) {
            final outcome = await _refreshAccessToken();
            if (outcome == _RefreshOutcome.success) {
              final opts = error.requestOptions;
              opts.extra['retried'] = true;
              final token = await _tokenStorage.getAccessToken();
              if (token != null) {
                opts.headers['Authorization'] = 'Bearer $token';
              }
              try {
                return handler.resolve(await _dio.fetch(opts));
              } catch (e) {
                if (e is DioException) return handler.next(e);
                return handler.next(error);
              }
            }
            // Only kick the user out when the refresh token is actually invalid.
            // Connection aborts / timeouts must not log them out.
            if (outcome == _RefreshOutcome.invalid) {
              _onSessionExpired?.call();
            }
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          error: true,
          logPrint: (o) => debugPrint(o.toString()),
        ),
      );
    }
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final OnSessionExpired? _onSessionExpired;
  Future<_RefreshOutcome>? _refreshInFlight;
  String? _cachedToken;
  int? _cachedExpSeconds;

  Dio get raw => _dio;

  Future<String?> _validAccessToken() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      _cachedToken = null;
      _cachedExpSeconds = null;
      return null;
    }

    if (_cachedToken != token) {
      _cachedToken = token;
      _cachedExpSeconds = null;
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = _decodeJwtPayload(parts[1]);
          final exp = payload['exp'];
          if (exp is int) {
            _cachedExpSeconds = exp;
          }
        }
      } catch (_) {
        /* use token as-is */
      }
    }

    if (_cachedExpSeconds != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (_cachedExpSeconds! - now < 90) {
        final outcome = await _refreshAccessToken();
        if (outcome == _RefreshOutcome.success) {
          return _tokenStorage.getAccessToken();
        }
        // Network blip: keep the current token so we do not drop the session.
        if (outcome == _RefreshOutcome.network) return token;
        if (_cachedExpSeconds! <= now) return null;
      }
    }

    return token;
  }

  Map<String, dynamic> _decodeJwtPayload(String segment) {
    var s = segment.replaceAll('-', '+').replaceAll('_', '/');
    switch (s.length % 4) {
      case 2:
        s += '==';
      case 3:
        s += '=';
    }
    final json = utf8.decode(base64.decode(s));
    return jsonDecode(json) as Map<String, dynamic>;
  }

  static bool _isAnonymousPath(String path) {
    final p = path.toLowerCase();
    return p.contains('/auth/register') ||
        p.contains('/auth/otp') ||
        p.contains('/auth/captcha') ||
        p.contains('/token/refresh') ||
        p.contains('/token/') ||
        p.contains('/health');
  }

  static bool _isTransient(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return true;
    }
    final err = e.error;
    if (err is SocketException) {
      final os = err.osError;
      final code = os?.errorCode ?? 0;
      // 103 ECONNABORTED, 104 ECONNRESET, 110 ETIMEDOUT, 111 ECONNREFUSED
      if ({103, 104, 110, 111, 7, 32}.contains(code)) return true;
      final msg = (os?.message ?? err.message).toLowerCase();
      if (msg.contains('connection abort') ||
          msg.contains('connection reset') ||
          msg.contains('broken pipe') ||
          msg.contains('timed out')) {
        return true;
      }
    }
    return false;
  }

  Future<bool> refreshAccessToken() async {
    return (await _refreshAccessToken()) == _RefreshOutcome.success;
  }

  Future<_RefreshOutcome> _refreshAccessToken() {
    if (_refreshInFlight != null) return _refreshInFlight!;
    _refreshInFlight = () async {
      try {
        final refresh = await _tokenStorage.getRefreshToken();
        if (refresh == null || refresh.isEmpty) return _RefreshOutcome.invalid;

        Object? lastError;
        for (var attempt = 0; attempt < 3; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          }
          try {
            final res = await _dio.post(
              '/token/refresh/',
              data: {'refresh': refresh},
              options: Options(
                extra: {'retried': true, 'netRetries': 3},
              ),
            );
            if (res.statusCode == 200 && res.data is Map) {
              final data = res.data as Map;
              final access = data['access'] as String?;
              final newRefresh = data['refresh'] as String? ?? refresh;
              if (access != null) {
                await _tokenStorage.saveTokens(
                  access: access,
                  refresh: newRefresh,
                );
                _cachedToken = access;
                _cachedExpSeconds = null;
                return _RefreshOutcome.success;
              }
            }
            return _RefreshOutcome.invalid;
          } on DioException catch (e) {
            lastError = e;
            if (e.response?.statusCode == 401) {
              return _RefreshOutcome.invalid;
            }
            if (_isTransient(e)) continue;
            return _RefreshOutcome.network;
          } catch (e) {
            lastError = e;
            continue;
          }
        }
        debugPrint('[ApiClient] refresh failed after retries: $lastError');
        return _RefreshOutcome.network;
      } finally {
        _refreshInFlight = null;
      }
    }();
    return _refreshInFlight!;
  }

  /// Open TLS to the API so the first user action (OTP) is not the first socket.
  Future<void> warmup() async {
    try {
      await _dio.get(
        '/health/',
        options: Options(
          extra: {'netRetries': 0},
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
    } catch (_) {
      try {
        await _dio.get(
          '/health/',
          options: Options(extra: {'netRetries': 0}),
        );
      } catch (e) {
        debugPrint('[ApiClient] warmup failed: $e');
      }
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return parser != null ? parser(res.data) : res.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final res = await _dio.post(path, data: data, queryParameters: query);
      return parser != null ? parser(res.data) : res.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final res = await _dio.patch(path, data: data);
      return parser != null ? parser(res.data) : res.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final res = await _dio.put(path, data: data);
      return parser != null ? parser(res.data) : res.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> delete(String path, {Object? data}) async {
    try {
      await _dio.delete(path, data: data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> postMultipart<T>(
    String path, {
    required FormData formData,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final res = await _dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return parser != null ? parser(res.data) : res.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Public GET without auth headers (catalogs).
  Future<dynamic> getPublic(String path) async {
    try {
      final res = await Dio(
        BaseOptions(
          baseUrl: Env.apiV1,
          headers: {
            'Accept': 'application/json',
            'X-App-Version': Env.appVersion,
          },
        ),
      ).get(path);
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    Map<String, dynamic>? map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is Map) {
      map = data.map((k, v) => MapEntry(k.toString(), v));
    }

    String message = 'Something went wrong';
    String? code;
    if (map != null) {
      code = map['code']?.toString();
      message = map['detail']?.toString() ??
          map['message']?.toString() ??
          map['error']?.toString() ??
          _flattenFieldErrors(map) ??
          message;
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      final host = e.requestOptions.uri.host;
      message = 'Connection timed out connecting to $host. Check your network or server status.';
    } else if (e.type == DioExceptionType.connectionError) {
      final host = e.requestOptions.uri.host;
      message = 'Could not connect to $host: ${e.error ?? e.message}';
    }

    debugPrint('🔴 [ApiClient] Error on ${e.requestOptions.method} ${e.requestOptions.uri} '
        '(status: $status): $message | rawError: ${e.error}');

    return ApiException(
      message: message,
      statusCode: status,
      data: map,
      code: code,
    );
  }

  String? _flattenFieldErrors(Map<String, dynamic> map) {
    final parts = <String>[];
    for (final entry in map.entries) {
      if (entry.key == 'code') continue;
      final v = entry.value;
      if (v is List) {
        parts.addAll(v.map((e) => e.toString()));
      } else if (v is String && entry.key != 'status') {
        parts.add(v);
      }
    }
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }
}
