import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/user_models.dart';

/// Device-local chat cache with WhatsApp-style **vanish after 48 hours**.
///
/// - Load previous messages from device storage first (no DB wait).
/// - Persist after network sync / send.
/// - Auto-purge messages older than [vanishAfter].
class ChatLocalStore {
  ChatLocalStore._();
  static final instance = ChatLocalStore._();

  /// Vanish mode ON by default — messages older than this are dropped locally.
  static const vanishAfter = Duration(hours: 48);
  static const vanishModeDefault = true;

  static const _prefix = 'chat_msgs_v1_';
  static const _vanishKey = 'chat_vanish_mode';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String _key(String conversationId) => '$_prefix$conversationId';

  Future<bool> isVanishModeOn() async {
    final p = await _prefs;
    return p.getBool(_vanishKey) ?? vanishModeDefault;
  }

  Future<void> setVanishMode(bool on) async {
    final p = await _prefs;
    await p.setBool(_vanishKey, on);
  }

  /// Instant local load (filtered by vanish window when enabled).
  Future<List<ChatMessage>> load(String conversationId, {String? myId}) async {
    final p = await _prefs;
    final raw = p.getString(_key(conversationId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      final vanish = await isVanishModeOn();
      final cutoff = DateTime.now().subtract(vanishAfter);
      final out = <ChatMessage>[];
      for (final item in list) {
        if (item is! Map) continue;
        final m = ChatMessage.fromJson(
          Map<String, dynamic>.from(item),
          myId: myId,
        );
        if (vanish && m.createdAt != null && m.createdAt!.isBefore(cutoff)) {
          continue;
        }
        out.add(m);
      }
      out.sort((a, b) {
        final aT = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bT = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aT.compareTo(bT);
      });
      // If we dropped any, rewrite clean cache
      if (vanish && out.length != list.length) {
        await save(conversationId, out);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Replace full conversation cache (applies vanish filter).
  Future<void> save(String conversationId, List<ChatMessage> messages) async {
    final vanish = await isVanishModeOn();
    final cutoff = DateTime.now().subtract(vanishAfter);
    final kept = messages.where((m) {
      if (!vanish) return true;
      if (m.createdAt == null) return true;
      return !m.createdAt!.isBefore(cutoff);
    }).toList();

    final encoded = jsonEncode(kept.map(_toMap).toList());
    final p = await _prefs;
    await p.setString(_key(conversationId), encoded);
  }

  /// Merge server list with local (prefer newer by id; keep optimistic locals).
  Future<List<ChatMessage>> mergeAndSave({
    required String conversationId,
    required List<ChatMessage> local,
    required List<ChatMessage> remote,
    String? myId,
  }) async {
    final byId = <String, ChatMessage>{};
    for (final m in local) {
      byId[m.id] = m;
    }
    for (final m in remote) {
      byId[m.id] = m;
      // Drop matching optimistic row if server returned real id via client_message_id
      if (m.clientMessageId != null && m.clientMessageId!.isNotEmpty) {
        byId.remove(m.clientMessageId);
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final aT = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bT = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aT.compareTo(bT);
      });
    await save(conversationId, merged);
    return load(conversationId, myId: myId);
  }

  Future<void> append(String conversationId, ChatMessage message) async {
    final existing = await load(conversationId);
    final without = existing.where((m) => m.id != message.id).toList();
    without.add(message);
    await save(conversationId, without);
  }

  Future<void> clearConversation(String conversationId) async {
    final p = await _prefs;
    await p.remove(_key(conversationId));
  }

  Map<String, dynamic> _toMap(ChatMessage m) => {
        'id': m.id,
        'conversation': m.conversationId,
        'conversation_id': m.conversationId,
        'sender_id': m.senderId,
        'text': m.text,
        'content': {
          'text': m.text,
          if (m.mediaUrl != null) 'url': m.mediaUrl,
        },
        'message_type': m.messageType,
        if (m.mediaUrl != null) 'media_url': m.mediaUrl,
        if (m.createdAt != null) 'created_at': m.createdAt!.toIso8601String(),
        'is_me': m.isMe,
        if (m.clientMessageId != null) 'client_message_id': m.clientMessageId,
        'is_seen': m.isSeen,
        if (m.deliveredAt != null)
          'delivered_at': m.deliveredAt!.toIso8601String(),
        'is_deleted': m.isDeleted,
      };
}
