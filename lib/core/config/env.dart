/// SPYCE environment / API configuration.
class Env {
  Env._();

  static const String appName = 'SPYCE';
  static const String appVersion = '1.0.1';

  /// Production test API (same host as web client).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://testapi.spycenow.com',
  );

  static const String apiV1 = '$apiBaseUrl/api/v1';

  static const String wsBase = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://testapi.spycenow.com/ws',
  );

  /// Leave empty / YOUR_* until credentials are ready (next 2 weeks).
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Cloudflare Turnstile site key (public). Empty = captcha UI off;
  /// backend also bypasses when TURNSTILE_SECRET_KEY is unset.
  /// Pass at build: `--dart-define=TURNSTILE_SITE_KEY=0x...`
  static const String turnstileSiteKey = String.fromEnvironment(
    'TURNSTILE_SITE_KEY',
    defaultValue: '',
  );

  /// Origin used by the Turnstile WebView. Must be an allowed hostname in
  /// the Turnstile widget settings (e.g. testapi.spycenow.com or spycenow.com).
  static const String turnstileBaseUrl = String.fromEnvironment(
    'TURNSTILE_BASE_URL',
    defaultValue: 'https://testapi.spycenow.com',
  );

  /// Whether the Flutter auth screens should require a Turnstile token.
  static bool get turnstileEnabled => turnstileSiteKey.trim().isNotEmpty;

  static String chatWs(String conversationId, String ticket) =>
      '$wsBase/chat/$conversationId/?ticket=$ticket';

  static String notificationsWs(String ticket) =>
      '$wsBase/notifications/?ticket=$ticket';

  static String callWs(String ticket) => '$wsBase/call/?ticket=$ticket';

  /// Enable SSL Certificate SHA-256 Pinning in production.
  /// Controlled via `--dart-define=ENABLE_SSL_PINNING=true`
  static const bool enableSslPinning = bool.fromEnvironment(
    'ENABLE_SSL_PINNING',
    defaultValue: false,
  );

  /// SHA-256 Certificate Fingerprints (comma separated).
  /// Allows dynamic fingerprint injection so domain changes will not break client pinning.
  static const String sslFingerprintsRaw = String.fromEnvironment(
    'SSL_FINGERPRINTS',
    defaultValue: '',
  );

  static List<String> get sslFingerprints {
    if (sslFingerprintsRaw.isEmpty) return const [];
    return sslFingerprintsRaw.split(',').map((e) => e.trim().replaceAll(':', '').toLowerCase()).toList();
  }
}
