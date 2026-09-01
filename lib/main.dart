import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'core/amplify/amplify_bootstrap.dart';
import 'core/auth/firebase_auth_service.dart';
import 'core/network/connectivity_banner.dart';
import 'core/notifications/local_push.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/push_router.dart';
import 'core/observability/sentry_bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/theme/spyce_colors.dart';
import 'core/theme/spyce_theme.dart';
import 'features/call/call_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  try {
    await WebRTC.initialize(
      options: {
        if (defaultTargetPlatform == TargetPlatform.android)
          'androidAudioConfiguration': AndroidAudioConfiguration.communication
              .toMap(),
      },
    );
  } catch (e) {
    debugPrint('[CALL] WebRTC.initialize failed: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SpyceColors.dark900,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initSentryFlutter();

  try {
    await FirebaseAuthService.ensureInitialized();
  } catch (e) {
    debugPrint('[AUTH] Firebase init failed: $e');
  }

  try {
    await LocalPush.ensureInitialized();
  } catch (e) {
    debugPrint('[FCM] Local notification init failed: $e');
  }

  // Optional early Amplify init when COGNITO_* are passed via --dart-define.
  // Face liveness also configures Amplify from GET /verification/status/.
  await AmplifyBootstrap.tryConfigureAtStartup();

  runApp(const ProviderScope(child: SpyceApp()));
}

class SpyceApp extends ConsumerWidget {
  const SpyceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SPYCE',
      debugShowCheckedModeBanner: false,
      theme: SpyceTheme.dark,
      routerConfig: router,
      // Production i18n baseline (English first; add arb locales next)
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return PushDeepLinkListener(
          child: ConnectivityBannerHost(
            child: CallOverlayHost(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
