class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.data,
    this.code,
  });

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isRateLimited => statusCode == 429;
  bool get isSubscriptionRequired =>
      code == 'subscription_required' ||
      (message.toLowerCase().contains('subscription'));

  /// Full server response for debugging / testing (status + body).
  String get fullDetail {
    final buf = StringBuffer(message);
    if (statusCode != null) buf.write(' [HTTP $statusCode]');
    if (code != null && code!.isNotEmpty) buf.write(' code=$code');
    if (data != null && data!.isNotEmpty) {
      try {
        buf.write('\n${data.toString()}');
      } catch (_) {}
    }
    return buf.toString();
  }

  /// Best user-facing error for snackbars (includes status when present).
  String get userMessage {
    if (statusCode != null) return '$message (HTTP $statusCode)';
    return message;
  }

  /// Format any caught error for UI (ApiException → full detail).
  static String describe(Object error) {
    if (error is ApiException) return error.fullDetail;
    return error.toString();
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
