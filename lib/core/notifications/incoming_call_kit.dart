import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/call/call_controller.dart';
import 'push_payload.dart';
import 'push_router.dart';

/// Native incoming-call UI (iOS CallKit + Android ConnectionService /
/// full-screen intent) so a killed or backgrounded app can still ring.
class IncomingCallKit {
  IncomingCallKit._();
  static final IncomingCallKit instance = IncomingCallKit._();

  WidgetRef? _ref;
  bool _listening = false;

  void bind(WidgetRef ref) {
    _ref = ref;
    _listen();
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      final extra = event.body is Map
          ? Map<dynamic, dynamic>.from(event.body as Map)
          : <dynamic, dynamic>{};
      final nested = extra['extra'] is Map
          ? Map<dynamic, dynamic>.from(extra['extra'] as Map)
          : extra;
      final payload = PushPayload.fromMap(nested);
      final ref = _ref;
      switch (event.event) {
        case Event.actionCallAccept:
          if (ref != null) {
            unawaited(handlePushPayload(ref, payload, acceptCall: true));
          } else {
            PendingPush.payload = payload;
          }
        case Event.actionCallDecline:
        case Event.actionCallTimeout:
        case Event.actionCallEnded:
          if (ref != null) {
            unawaited(
              ref.read(callControllerProvider.notifier).hangup(
                    reason: 'rejected',
                    silent: true,
                  ),
            );
          }
          unawaited(FlutterCallkitIncoming.endAllCalls());
        case Event.actionCallIncoming:
        case Event.actionCallStart:
        case Event.actionCallCallback:
        case Event.actionCallToggleHold:
        case Event.actionCallToggleMute:
        case Event.actionCallToggleDmtf:
        case Event.actionCallToggleGroup:
        case Event.actionCallToggleAudioSession:
        case Event.actionDidUpdateDevicePushTokenVoip:
        case Event.actionCallCustom:
        case Event.actionCallConnected:
          break;
      }
    });
  }

  Future<void> showIncoming(PushPayload payload) async {
    final callId = payload.callId;
    if (callId == null || callId.isEmpty) return;
    final uuid = _asUuid(callId);
    final params = CallKitParams(
      id: uuid,
      nameCaller: payload.callerName ?? 'Incoming call',
      appName: 'SPYCE',
      type: payload.isVideo ? 1 : 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      duration: 90000,
      extra: {
        'type': 'INCOMING_CALL',
        'call_id': callId,
        'caller_id': payload.callerId ?? '',
        'caller_name': payload.callerName ?? '',
        'call_type': payload.callType ?? 'VOICE',
      },
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        incomingCallNotificationChannelName: 'Incoming calls',
        missedCallNotificationChannelName: 'Missed calls',
        isShowFullLockedScreen: true,
        isImportant: true,
        isShowCallID: false,
      ),
      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: true,
        audioSessionMode: 'voiceChat',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> end(String? callId) async {
    if (callId == null || callId.isEmpty) {
      await FlutterCallkitIncoming.endAllCalls();
      return;
    }
    await FlutterCallkitIncoming.endCall(_asUuid(callId));
  }

  /// Resume a call the OS already accepted while Flutter was launching.
  Future<PushPayload?> activeAcceptedCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is! List || calls.isEmpty) return null;
      final first = calls.first;
      if (first is! Map) return null;
      final extra = first['extra'] is Map
          ? Map<dynamic, dynamic>.from(first['extra'] as Map)
          : first;
      return PushPayload.fromMap(extra);
    } catch (e) {
      debugPrint('[CALLKIT] activeCalls failed: $e');
      return null;
    }
  }

  String _asUuid(String callId) {
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidRe.hasMatch(callId)) return callId;
    return const Uuid().v5(
      '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
      'spyce-call-$callId',
    );
  }
}
