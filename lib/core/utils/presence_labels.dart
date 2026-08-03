/// Shared last-seen / online label helpers for feed + chat UI.
class PresenceLabels {
  PresenceLabels._();

  /// Prefer a real timestamp when available (more accurate than a stale string).
  /// Falls back to API label, then generic copy.
  static String display({
    bool isOnline = false,
    String? lastSeenLabel,
    DateTime? lastActiveAt,
  }) {
    if (isOnline) return 'Online';

    // Prefer recomputing from last_active so labels stay fresh on the client
    if (lastActiveAt != null) {
      return fromTimestamp(lastActiveAt);
    }

    final fromApi = lastSeenLabel?.trim();
    if (fromApi != null && fromApi.isNotEmpty) {
      if (fromApi.toLowerCase() == 'online') return 'Online';
      // Ignore broken generic fallback when we have no timestamp (still show it)
      return fromApi;
    }

    return 'Last seen a while ago';
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
    if (days <= 3) return 'Last seen a few days ago';
    if (days <= 14) return 'Last seen last week';
    return 'Last seen a while ago';
  }

  /// Parse API last_active (unix sec/ms, ISO string, or num).
  static DateTime? parseLastActive(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is num) {
      final n = raw.toDouble();
      final ms = n > 1e12 ? n.toInt() : (n * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    // Unix as string
    final asNum = double.tryParse(s);
    if (asNum != null) {
      final ms = asNum > 1e12 ? asNum.toInt() : (asNum * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    return DateTime.tryParse(s)?.toUtc();
  }
}
