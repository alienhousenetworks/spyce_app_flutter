/// Shared last-seen / online label helpers for feed + chat UI.
class PresenceLabels {
  PresenceLabels._();

  /// Prefer backend label when present; otherwise derive from flags / timestamps.
  static String display({
    bool isOnline = false,
    String? lastSeenLabel,
    DateTime? lastActiveAt,
  }) {
    if (isOnline) return 'Online';

    final fromApi = lastSeenLabel?.trim();
    if (fromApi != null && fromApi.isNotEmpty) {
      // Backend may return "Online" as last_seen when currently online
      if (fromApi.toLowerCase() == 'online') return 'Online';
      return fromApi;
    }

    if (lastActiveAt != null) {
      return fromTimestamp(lastActiveAt);
    }
    return 'Last seen a few days ago';
  }

  /// Client-side buckets matching backend `format_last_seen_label`.
  static String fromTimestamp(DateTime lastActive) {
    final now = DateTime.now().toUtc();
    final at = lastActive.toUtc();
    final seconds = now.difference(at).inSeconds;
    final s = seconds < 0 ? 0 : seconds;
    final hours = s / 3600.0;
    final days = s / 86400.0;

    if (hours <= 3) return 'Last seen recently';
    if (hours <= 10) return 'Last seen a few hours ago';
    if (hours <= 24) return 'Last seen today';
    if (days <= 3) return 'Last seen a few days';
    return 'Last seen a few days ago';
  }
}
