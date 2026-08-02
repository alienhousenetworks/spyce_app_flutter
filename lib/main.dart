import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/connectivity_banner.dart';
import 'core/observability/sentry_bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/theme/spyce_colors.dart';
import 'core/theme/spyce_theme.dart';
import 'features/call/call_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      supportedLocales: const [
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return ConnectivityBannerHost(
          child: CallOverlayHost(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
