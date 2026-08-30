import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/bootstrap/app_preload.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/spyce_loaders.dart';
import '../auth/auth_controller.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  String _caption = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    await Future.wait([
      SpyceFlameLoader.precache(context),
      ref.read(authControllerProvider.notifier).bootstrap(),
    ]);
    if (!mounted) return;

    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn) {
      context.go('/auth');
      return;
    }
    if (auth.onboardingComplete != true) {
      context.go('/onboarding');
      return;
    }

    setState(() => _caption = 'Finding your people…');
    try {
      await Future.any([
        _preloadLoggedIn(),
        Future.delayed(const Duration(seconds: 12)),
      ]);
    } catch (_) {}
    if (!mounted) return;
    context.go('/app/discover');
  }

  Future<void> _preloadLoggedIn() async {
    FeedResponse? feed;
    UserProfile? profile;
    try {
      profile = await ref.read(profileRepositoryProvider).getMyProfile();
    } catch (_) {}
    try {
      feed = await ref
          .read(feedRepositoryProvider)
          .getFeed(
            cursor: 0,
            refresh: true,
            filters: const {
              'min_age': 18,
              'max_age': 100,
              'distance': 0,
              'location_mode': 'distance',
            },
          );
    } catch (_) {}
    if (!mounted) return;
    ref.read(appPreloadProvider.notifier).state = AppPreloadData(
      feed: feed,
      profile: profile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpyceColors.dark950,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SpyceFlameLoader(height: 200),
                  const SizedBox(height: 20),
                  Text(
                    'Spyce',
                    style: GoogleFonts.cookie(
                      fontSize: 48,
                      color: SpyceColors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _caption,
                      key: ValueKey(_caption),
                      style: GoogleFonts.dmSans(
                        color: SpyceColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Text(
                'no fake vibes. just real ones.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: SpyceColors.textMuted,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
