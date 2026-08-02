import '../config/env.dart';

/// Normalize API media URLs so CachedNetworkImage can load them on device.
///
/// Handles relative proxy paths (`/media/profile/...`), missing hosts, and
/// strips accidental whitespace. Leaves full http(s) URLs unchanged.
String? resolveMediaUrl(String? raw) {
  if (raw == null) return null;
  var url = raw.trim();
  if (url.isEmpty || url == 'null' || url == 'None') return null;

  // Already absolute
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }

  final base = Env.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  // Absolute path on API host: /media/... or /api/...
  if (url.startsWith('/')) {
    return '$base$url';
  }

  // Storage key leaked as image_url (users/.../x.webp) — not loadable as-is
  if (url.startsWith('users/') ||
      url.startsWith('temp/') ||
      url.startsWith('avatars/') ||
      url.startsWith('media/')) {
    // Prefer watermark proxy only when it looks like a media path under /media/
    if (url.startsWith('media/')) {
      return '$base/$url';
    }
    // Raw storage keys need the API to mint a signed URL — cannot invent one here
    return null;
  }

  return '$base/$url';
}
