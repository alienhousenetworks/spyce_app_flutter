import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'push_payload.dart';
import 'push_router.dart';

const androidDefaultChannelId = 'spyce_default';
const androidCallChannelId = 'spyce_incoming_calls';

/// Android tray notifications. FCM does not display a system notification while
/// the app is in the foreground; this helper does. Also used as a fallback from
/// the FCM background isolate.
class LocalPush {
  LocalPush._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> ensureInitialized() async {
    if (_ready || kIsWeb) return;
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_spyce');
    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        androidCallChannelId,
        'Incoming calls',
        description: 'Full-screen incoming SPYCE calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        androidDefaultChannelId,
        'SPYCE',
        description: 'Matches, messages, and account alerts',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await ensureInitialized();
    var granted = false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      granted = await android?.requestNotificationsPermission() ?? false;
    } catch (_) {}
    try {
      final status = await Permission.notification.request();
      granted = granted || status.isGranted || status.isLimited;
    } catch (_) {}
    return granted;
  }

  static Future<void> show({
    required PushPayload payload,
    String? title,
    String? body,
  }) async {
    if (kIsWeb) return;
    if (payload.isIncomingCall) return;
    await ensureInitialized();

    final resolvedTitle = (title ?? payload.title).trim();
    final resolvedBody = (body ?? payload.body).trim();
    if (resolvedTitle.isEmpty && resolvedBody.isEmpty) return;

    const android = AndroidNotificationDetails(
      androidDefaultChannelId,
      'SPYCE',
      channelDescription: 'Matches, messages, and account alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_spyce',
      color: Color(0xFFE07E42),
      playSound: true,
      enableVibration: true,
    );

    await _plugin.show(
      _idFor(payload),
      resolvedTitle.isEmpty ? 'SPYCE' : resolvedTitle,
      resolvedBody,
      const NotificationDetails(android: android),
      payload: jsonEncode(payload.raw),
    );
  }

  static int _idFor(PushPayload payload) {
    final key = payload.conversationId ??
        payload.callId ??
        (payload.type.isEmpty
            ? DateTime.now().millisecondsSinceEpoch.toString()
            : payload.type);
    return key.hashCode & 0x7fffffff;
  }

  static void _onTap(NotificationResponse resp) {
    final raw = resp.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      final map = decoded is Map ? decoded : <String, dynamic>{};
      final payload = PushPayload.fromMap(map);
      PendingPush.payload = payload;
      PushBridge.dispatch?.call(payload);
    } catch (e) {
      debugPrint('[FCM] local notification tap parse failed: $e');
    }
  }
}
