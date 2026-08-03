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
