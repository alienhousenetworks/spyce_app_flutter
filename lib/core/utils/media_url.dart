import '../config/env.dart';

/// Normalize API media URLs so CachedNetworkImage can load them on device.
///
/// Handles relative proxy paths (`/media/profile/...`), missing hosts,
/// Docker internal hosts (minio:9000), and ensures HTTPS.
String? resolveMediaUrl(String? raw) {
  if (raw == null) return null;
  var url = raw.trim();
  if (url.isEmpty || url == 'null' || url == 'None') return null;

  // Extract root host from apiBaseUrl (e.g. 'https://api01.spycenow.com' from 'https://api01.spycenow.com/api/v1')
  final apiUri = Uri.tryParse(Env.apiBaseUrl);
  final hostRoot = apiUri != null && apiUri.hasScheme && apiUri.host.isNotEmpty
      ? '${apiUri.scheme}://${apiUri.host}${apiUri.hasPort ? ':${apiUri.port}' : ''}'
      : Env.apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '').replaceAll(RegExp(r'/+$'), '');

  // Rewrite internal Docker / localhost endpoints if returned
  if (url.contains('minio:9000') || url.contains('localhost:9000')) {
    final parsed = Uri.tryParse(url);
    if (parsed != null) {
      final query = parsed.hasQuery ? '?${parsed.query}' : '';
      return '$hostRoot${parsed.path}$query';
    }
  }

  // Already absolute http/https
  if (url.startsWith('http://') || url.startsWith('https://')) {
    // Force HTTPS on production spycenow domains to avoid cleartext HTTP blocks
    if (url.startsWith('http://') &&
        (url.contains('spycenow.com') ||
            (apiUri != null && url.contains(apiUri.host)))) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  // Root-relative path (/media/..., /api/...) -> attach to host root
  if (url.startsWith('/')) {
    return '$hostRoot$url';
  }

  // Relative storage path or media path (e.g. users/... or media/...)
  if (url.startsWith('media/')) {
    return '$hostRoot/$url';
  }

  // Raw storage key: fallback to /media/ path on host root
  if (url.startsWith('users/') ||
      url.startsWith('temp/') ||
      url.startsWith('avatars/') ||
      url.startsWith('turn_ons/')) {
    return '$hostRoot/media/$url';
  }

  return '$hostRoot/$url';
}

