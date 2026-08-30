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

/// Dio client with JWT attach, single-flight refresh, and one retry on 401.
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
          client.connectionTimeout = const Duration(seconds: 30);
          client.idleTimeout = const Duration(seconds: 30);
          if (Env.enableSslPinning && Env.sslFingerprints.isNotEmpty) {
            client.badCertificateCallback = (X509Certificate cert, String host, int port) {
              final certDer = cert.der;
              final sha256Fingerprint = sha256.convert(certDer).toString().toLowerCase();
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
          final token = await _validAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true) {
            final ok = await refreshAccessToken();
            if (ok) {
              final opts = error.requestOptions;
              opts.extra['retried'] = true;
              final token = await _tokenStorage.getAccessToken();
              if (token != null) {
                opts.headers['Authorization'] = 'Bearer $token';
              }
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                if (e is DioException) return handler.next(e);
                return handler.next(error);
              }
            }
            _onSessionExpired?.call();
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
  Future<bool>? _refreshInFlight;
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
      if (_cachedExpSeconds! - now < 60) {
        final refreshed = await refreshAccessToken();
        if (refreshed) return _tokenStorage.getAccessToken();
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

  Future<bool> refreshAccessToken() {
    if (_refreshInFlight != null) return _refreshInFlight!;
    _refreshInFlight = () async {
      try {
        final refresh = await _tokenStorage.getRefreshToken();
        if (refresh == null) return false;
        final res = await Dio(
          BaseOptions(baseUrl: Env.apiV1),
        ).post('/token/refresh/', data: {'refresh': refresh});
        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data as Map;
          final access = data['access'] as String?;
          final newRefresh = data['refresh'] as String? ?? refresh;
          if (access != null) {
            await _tokenStorage.saveTokens(
              access: access,
              refresh: newRefresh,
            );
            return true;
          }
        }
        return false;
      } catch (_) {
        return false;
      } finally {
        _refreshInFlight = null;
      }
    }();
    return _refreshInFlight!;
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
