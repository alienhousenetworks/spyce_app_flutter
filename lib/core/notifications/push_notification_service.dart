import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/api_repositories.dart';
import '../config/firebase_options.dart';
import 'incoming_call_kit.dart';
import 'local_push.dart';
import 'push_payload.dart';
import 'push_router.dart';

/// Must be a top-level function. Wakes a killed Android process for calls
/// and shows a tray notification when FCM is data-only.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (_) {}
  final payload = PushPayload.fromMap({
    ...message.data,
    if (message.notification?.title != null) 'title': message.notification!.title,
    if (message.notification?.body != null) 'body': message.notification!.body,
  });
  if (payload.isIncomingCall) {
    await IncomingCallKit.instance.showIncoming(payload);
    return;
  }
  PendingPush.payload = payload;
  // Data-only FCM (no notification block) never hits the system tray.
  if (message.notification == null) {
    await LocalPush.show(
      payload: payload,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }
}

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
      await LocalPush.ensureInitialized();
      final androidGranted = await LocalPush.requestPermission();

      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final fcmOk = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (fcmOk || androidGranted) {
        debugPrint('[FCM] Push notification permission granted (android=$androidGranted fcm=$fcmOk).');
      } else {
        debugPrint('[FCM] Push notification permission denied/declined.');
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await syncTokenWithBackend();

      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        _sendTokenToBackend(newToken);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        await _onOpened(initial);
      }

      final accepted = await IncomingCallKit.instance.activeAcceptedCall();
      if (accepted != null) {
        PendingPush.payload = accepted;
        await PushBridge.dispatch?.call(accepted, acceptCall: true);
      }
    } catch (e) {
      debugPrint('[FCM] Push notification initialization error: $e');
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final payload = PushPayload.fromMap({
      ...message.data,
      if (message.notification?.title != null) 'title': message.notification!.title,
      if (message.notification?.body != null) 'body': message.notification!.body,
    });
    debugPrint('[FCM] foreground type=${payload.type}');
    if (payload.isIncomingCall) {
      final resumed =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!resumed) {
        await IncomingCallKit.instance.showIncoming(payload);
      }
      await PushBridge.dispatch?.call(payload);
      return;
    }
    // Android does not auto-display FCM while the app is open.
    await LocalPush.show(
      payload: payload,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  Future<void> _onOpened(RemoteMessage message) async {
    final payload = PushPayload.fromMap(message.data);
    debugPrint('[FCM] opened type=${payload.type} route=${payload.navigationPath}');
    PendingPush.payload = payload;
    await PushBridge.dispatch?.call(payload);
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
