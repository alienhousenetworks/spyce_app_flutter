/// SPYCE environment / API configuration.
class Env {
  Env._();

  static const String appName = 'SPYCE';
  static const String appVersion = '1.0.0';

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

  static String chatWs(String conversationId, String ticket) =>
      '$wsBase/chat/$conversationId/?ticket=$ticket';

  static String notificationsWs(String ticket) =>
      '$wsBase/notifications/?ticket=$ticket';

  static String callWs(String ticket) => '$wsBase/call/?ticket=$ticket';
}
