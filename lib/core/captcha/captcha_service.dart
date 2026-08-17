import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_action.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_client.dart';

import '../config/env.dart';

/// Runtime captcha config (dart-define + optional backend /auth/captcha-config/).
class CaptchaRuntimeConfig {
  const CaptchaRuntimeConfig({
    required this.active,
    this.provider = 'recaptcha_enterprise',
    this.androidSiteKey = '',
    this.iosSiteKey = '',
    this.turnstileSiteKey = '',
    this.expectedAction = 'login',
  });

  final bool active;
  final String provider;
  final String androidSiteKey;
  final String iosSiteKey;
  final String turnstileSiteKey;
  final String expectedAction;

  String get platformSiteKey {
    if (kIsWeb) return '';
    if (Platform.isIOS) return iosSiteKey.trim();
    if (Platform.isAndroid) return androidSiteKey.trim();
    return androidSiteKey.trim().isNotEmpty
        ? androidSiteKey.trim()
        : iosSiteKey.trim();
  }

  String get platformName {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  /// Google reCAPTCHA Enterprise path (native SDK).
  bool get useRecaptcha =>
      active &&
      platformSiteKey.isNotEmpty &&
      (provider == 'recaptcha_enterprise' ||
          provider == 'recaptcha' ||
          provider == 'auto');

  /// Cloudflare Turnstile WebView path.
  bool get useTurnstile =>
      active &&
      !useRecaptcha &&
      (turnstileSiteKey.trim().isNotEmpty || Env.turnstileSiteKey.isNotEmpty);

  bool get requiresCaptcha => useRecaptcha || useTurnstile;
}

/// Executes Google reCAPTCHA Enterprise before OTP request/resend.
class CaptchaService {
  CaptchaService._();
  static final CaptchaService instance = CaptchaService._();

  CaptchaRuntimeConfig _config = CaptchaRuntimeConfig(
    active: Env.captchaVerificationActive,
    androidSiteKey: Env.recaptchaAndroidSiteKey,
    iosSiteKey: Env.recaptchaIosSiteKey,
    turnstileSiteKey: Env.turnstileSiteKey,
    expectedAction: Env.recaptchaAction,
  );

  RecaptchaClient? _client;
  String? _clientSiteKey;

  CaptchaRuntimeConfig get config => _config;

  /// Merge server config (public keys + active flag). Call once at app start / auth open.
  Future<void> refreshFromBackend({Dio? dio}) async {
    try {
      final client = dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiV1,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );
      final res = await client.get<Map<String, dynamic>>('/auth/captcha-config/');
      final data = res.data ?? {};
      // Server is source of truth for the master switch when config is reachable.
      final active = data.containsKey('captcha_verification_active')
          ? data['captcha_verification_active'] == true
          : Env.captchaVerificationActive;
      _config = CaptchaRuntimeConfig(
        active: active,
        provider: (data['provider'] as String?)?.trim().isNotEmpty == true
            ? (data['provider'] as String).trim()
            : 'recaptcha_enterprise',
        androidSiteKey: (data['android_site_key'] as String?)?.trim().isNotEmpty ==
                true
            ? (data['android_site_key'] as String).trim()
            : Env.recaptchaAndroidSiteKey,
        iosSiteKey:
            (data['ios_site_key'] as String?)?.trim().isNotEmpty == true
                ? (data['ios_site_key'] as String).trim()
                : Env.recaptchaIosSiteKey,
        turnstileSiteKey:
            (data['turnstile_site_key'] as String?)?.trim().isNotEmpty == true
                ? (data['turnstile_site_key'] as String).trim()
                : Env.turnstileSiteKey,
        expectedAction:
            (data['expected_action'] as String?)?.trim().isNotEmpty == true
                ? (data['expected_action'] as String).trim()
                : Env.recaptchaAction,
      );
    } catch (_) {
      // Keep dart-define defaults
    }
  }

  Future<RecaptchaClient?> _ensureClient() async {
    final key = _config.platformSiteKey;
    if (key.isEmpty) return null;
    if (_client != null && _clientSiteKey == key) return _client;
    _client = await Recaptcha.fetchClient(key);
    _clientSiteKey = key;
    return _client;
  }

  /// Returns a fresh token for OTP request. Null when captcha inactive.
  Future<CaptchaTokenResult> executeForAuth({String? action}) async {
    if (!_config.active) {
      return const CaptchaTokenResult(skipped: true);
    }
    if (!_config.useRecaptcha) {
      // Turnstile path is handled by UI widget tokens
      return const CaptchaTokenResult(skipped: true, useTurnstile: true);
    }

    final client = await _ensureClient();
    if (client == null) {
      return const CaptchaTokenResult(
        error: 'reCAPTCHA site key missing for this platform.',
      );
    }

    final actionName = (action ?? _config.expectedAction).trim().isEmpty
        ? 'login'
        : (action ?? _config.expectedAction).trim();
    final recaptchaAction = actionName.toLowerCase() == 'signup'
        ? RecaptchaAction.SIGNUP()
        : actionName.toLowerCase() == 'login'
            ? RecaptchaAction.LOGIN()
            : RecaptchaAction.custom(actionName);

    try {
      final token = await client.execute(recaptchaAction, timeout: 10);
      if (token.trim().isEmpty) {
        return const CaptchaTokenResult(error: 'reCAPTCHA returned an empty token.');
      }
      return CaptchaTokenResult(
        token: token.trim(),
        platform: _config.platformName,
        siteKey: _config.platformSiteKey,
        action: actionName,
      );
    } catch (e) {
      return CaptchaTokenResult(error: 'reCAPTCHA failed: $e');
    }
  }
}

class CaptchaTokenResult {
  const CaptchaTokenResult({
    this.token,
    this.platform,
    this.siteKey,
    this.action,
    this.error,
    this.skipped = false,
    this.useTurnstile = false,
  });

  final String? token;
  final String? platform;
  final String? siteKey;
  final String? action;
  final String? error;
  final bool skipped;
  final bool useTurnstile;

  bool get ok => error == null && (skipped || useTurnstile || (token != null && token!.isNotEmpty));
}
