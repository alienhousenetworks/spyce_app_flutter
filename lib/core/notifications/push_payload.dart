/// Parsed FCM / CallKit extra map used for deep links.
class PushPayload {
  const PushPayload({
    required this.type,
    this.route,
    this.conversationId,
    this.callId,
    this.callerId,
    this.callerName,
    this.callType,
    this.peerUserId,
    this.peerName,
    this.raw = const {},
  });

  final String type;
  final String? route;
  final String? conversationId;
  final String? callId;
  final String? callerId;
  final String? callerName;
  final String? callType;
  final String? peerUserId;
  final String? peerName;
  final Map<String, String> raw;

  bool get isIncomingCall => type == 'INCOMING_CALL';

  bool get isVideo => (callType ?? '').toUpperCase().contains('VIDEO');

  String get title {
    final v = (raw['title'] ?? '').trim();
    if (v.isNotEmpty) return v;
    return switch (type) {
      'NEW_MATCH' => 'New Match!',
      'NEW_MESSAGE' => peerName ?? 'New message',
      'INCOMING_CALL' => 'Incoming call',
      'PROFILE_VERIFIED' => 'Profile verified',
      _ => 'SPYCE',
    };
  }

  String get body {
    final v = (raw['body'] ?? '').trim();
    if (v.isNotEmpty) return v;
    return switch (type) {
      'NEW_MATCH' => peerName == null
          ? 'You have a new match'
          : 'You matched with $peerName',
      'NEW_MESSAGE' => 'Sent you a new message',
      'INCOMING_CALL' => '${callerName ?? 'Someone'} is calling you',
      'PROFILE_VERIFIED' => 'Your face verification is complete',
      _ => 'Open SPYCE',
    };
  }

  factory PushPayload.fromMap(Map<dynamic, dynamic>? data) {
    final map = <String, String>{};
    (data ?? {}).forEach((key, value) {
      if (key == null || value == null) return;
      map[key.toString()] = value.toString();
    });
    final type = (map['type'] ?? map['event_type'] ?? '').toUpperCase();
    return PushPayload(
      type: type,
      route: map['route'],
      conversationId: map['conversation_id'],
      callId: map['call_id'],
      callerId: map['caller_id'],
      callerName: map['caller_name'] ?? map['name'] ?? map['peer_name'],
      callType: map['call_type'],
      peerUserId: map['peer_user_id'] ?? map['sender_id'] ?? map['caller_id'],
      peerName: map['peer_name'] ?? map['name'] ?? map['caller_name'],
      raw: map,
    );
  }

  String get navigationPath {
    if (route != null && route!.startsWith('/')) return route!;
    if (conversationId != null && conversationId!.isNotEmpty) {
      return '/app/chat/$conversationId';
    }
    if (type == 'NEW_MATCH' || type == 'NEW_MESSAGE') {
      return '/app/chat';
    }
    if (type == 'PROFILE_VERIFIED') return '/app/settings/verification';
    return '/app/discover';
  }
}

/// Holds a tap/CallKit intent until splash + auth finish.
class PendingPush {
  PendingPush._();
  static PushPayload? payload;
}
