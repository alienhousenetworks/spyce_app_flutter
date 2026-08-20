import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/api_repositories.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});

class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  bool _initialized = false;

  AuthRepository get _auth => _ref.read(authRepositoryProvider);

  /// Initialize Firebase Cloud Messaging permissions and listeners.
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request user permission (essential for iOS & Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[FCM] Push notification permission granted.');
      } else {
        debugPrint('[FCM] Push notification permission denied/declined.');
      }

      // 2. Set foreground presentation options (iOS)
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Register current token
      await syncTokenWithBackend();

      // 4. Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        _sendTokenToBackend(newToken);
      });

      // 5. Handle foreground push messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Received foreground message: ${message.notification?.title} - ${message.notification?.body}');
      });

      // 6. Handle notification click when app is backgrounded
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] App opened from notification: ${message.data}');
      });
    } catch (e) {
      debugPrint('[FCM] Push notification initialization error: $e');
    }
  }

  /// Fetch FCM Token and register with Django backend.
  Future<void> syncTokenWithBackend() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[FCM] Device Token: $token');
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Failed to get FCM token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    final deviceType = defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
    try {
      final success = await _auth.registerPushToken(token, deviceType: deviceType);
      if (success) {
        debugPrint('[FCM] Registered FCM token successfully with backend.');
      } else {
        debugPrint('[FCM] Backend rejected or failed FCM token registration.');
      }
    } catch (e) {
      debugPrint('[FCM] Error sending token to backend: $e');
    }
  }
}
