import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      builder: (context, child) {
        return CallOverlayHost(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
