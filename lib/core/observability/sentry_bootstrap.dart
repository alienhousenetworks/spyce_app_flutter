import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Sentry bootstrap — no-op until [Env.sentryDsn] is set (placeholders OK for 2 weeks).
Future<void> initSentryFlutter() async {
  final dsn = Env.sentryDsn.trim();
  if (dsn.isEmpty || dsn.startsWith('YOUR_') || dsn == 'placeholder') {
    if (kDebugMode) {
      debugPrint('Sentry DSN not set — crash reporting disabled');
    }
    return;
  }
  // When ready: add sentry_flutter and call SentryFlutter.init here.
  // Kept optional so builds work without the package until credentials exist.
  if (kDebugMode) {
    debugPrint('Sentry DSN present — wire sentry_flutter package to activate');
  }
}
