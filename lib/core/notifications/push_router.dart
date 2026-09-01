import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/call/call_controller.dart';
import '../router/app_router.dart';
import 'incoming_call_kit.dart';
import 'push_payload.dart';

/// Riverpod 2 [WidgetRef] and provider [Ref] are different types.
/// FCM / CallKit isolates call this bridge; the UI listener binds it.
class PushBridge {
  static Future<void> Function(PushPayload payload, {bool acceptCall})? dispatch;
}

Future<void> handlePushPayload(
  WidgetRef ref,
  PushPayload payload, {
  bool acceptCall = false,
}) async {
  PendingPush.payload = payload;
  final auth = ref.read(authControllerProvider);
  if (!auth.bootstrapped || !auth.isLoggedIn || auth.onboardingComplete != true) {
    return;
  }
  await _dispatch(ref, payload, acceptCall: acceptCall);
}

Future<void> consumePendingPush(WidgetRef ref) async {
  final pending = PendingPush.payload;
  if (pending == null) return;
  final auth = ref.read(authControllerProvider);
  if (!auth.bootstrapped || !auth.isLoggedIn || auth.onboardingComplete != true) {
    return;
  }
  PendingPush.payload = null;
  await _dispatch(ref, pending);
}

Future<void> _dispatch(
  WidgetRef ref,
  PushPayload payload, {
  bool acceptCall = false,
}) async {
  final ctx = appRootNavigatorKey.currentContext;
  if (payload.isIncomingCall && payload.callId != null) {
    final kind = payload.isVideo ? CallKind.video : CallKind.voice;
    final ctrl = ref.read(callControllerProvider.notifier);
    if (acceptCall) {
      await ctrl.acceptIncomingFromPush(
        callId: payload.callId!,
        peerId: payload.callerId,
        peerName: payload.callerName,
        kind: kind,
      );
    } else {
      await ctrl.presentIncomingFromPush(
        callId: payload.callId!,
        peerId: payload.callerId,
        peerName: payload.callerName,
        kind: kind,
      );
    }
    return;
  }
  if (ctx == null || !ctx.mounted) return;
  final path = payload.navigationPath;
  GoRouter.of(ctx).go(
    path,
    extra: {
      'title': payload.peerName,
      'peerUserId': payload.peerUserId,
    },
  );
}

/// After splash lands on Discover, honor a notification that opened the app.
class PushDeepLinkListener extends ConsumerStatefulWidget {
  const PushDeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushDeepLinkListener> createState() =>
      _PushDeepLinkListenerState();
}

class _PushDeepLinkListenerState extends ConsumerState<PushDeepLinkListener> {
  @override
  void initState() {
    super.initState();
    PushBridge.dispatch = (payload, {acceptCall = false}) =>
        handlePushPayload(ref, payload, acceptCall: acceptCall);
    IncomingCallKit.instance.bind(ref);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      consumePendingPush(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNavProvider, (prev, next) {
      if (next.bootstrapped && next.isLoggedIn && next.onboardingComplete) {
        consumePendingPush(ref);
      }
    });
    return widget.child;
  }
}
