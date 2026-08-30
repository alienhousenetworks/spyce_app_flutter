import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/api_repositories.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/confessions/confessions_page.dart';
import '../../features/discover/discover_page.dart';
import '../../features/mood/mood_page.dart';
import '../../features/notifications/notification_settings_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/premium/subscription_paywall.dart';
import '../../features/profile/peer_profile_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_page.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Tabs: Discover · Confessions · Chat · Profile
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthNavRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authNavProvider);
      final loc = state.matchedLocation;

      if (!auth.bootstrapped && loc != '/') return '/';

      if (auth.bootstrapped && !auth.isLoggedIn) {
        if (loc == '/auth' || loc == '/') return null;
        return '/auth';
      }

      if (auth.bootstrapped && auth.isLoggedIn && !auth.onboardingComplete) {
        if (loc.startsWith('/onboarding') || loc == '/') return null;
        return '/onboarding';
      }

      if (auth.bootstrapped && auth.isLoggedIn && auth.onboardingComplete) {
        // Stay on splash (`/`) until SplashPage finishes preloading data.
        if (loc == '/auth' || loc == '/onboarding') {
          return '/app/discover';
        }
        if (loc.startsWith('/app/matches')) return '/app/chat';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const SplashPage()),
      GoRoute(path: '/auth', builder: (c, s) => const AuthPage()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // 0 Discover
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/discover',
                builder: (c, s) => const DiscoverPage(),
              ),
            ],
          ),
          // 1 Confessions
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/confessions',
                builder: (c, s) => const ConfessionsPage(),
              ),
            ],
          ),
          // 2 Chat
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/chat',
                builder: (c, s) => const ConversationsPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) {
                      final extra = state.extra;
                      String? title;
                      String? peerUserId;
                      String? peerImage;
                      var isOnline = false;
                      String? lastSeen;
                      if (extra is Map) {
                        title = extra['title']?.toString();
                        peerUserId = extra['peerUserId']?.toString();
                        peerImage = extra['peerImage']?.toString();
                        isOnline = extra['isOnline'] == true;
                        lastSeen = extra['lastSeen']?.toString();
                      } else if (extra is String) {
                        title = extra;
                      }
                      return ChatThreadPage(
                        conversationId: state.pathParameters['id']!,
                        title: title,
                        peerUserId: peerUserId,
                        peerImage: peerImage,
                        isOnline: isOnline,
                        lastSeen: lastSeen,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // 3 Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/profile',
                builder: (c, s) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/app/settings',
        parentNavigatorKey: _rootKey,
        builder: (c, s) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'notifications',
            parentNavigatorKey: _rootKey,
            builder: (c, s) => const NotificationSettingsPage(),
          ),
        ],
      ),
      // Peer profile from chat avatar / match / incoming likes
      GoRoute(
        path: '/app/user/:userId',
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final extra = state.extra;
          String? name;
          String? image;
          var allowLikeBack = false;
          if (extra is Map) {
            name = extra['title']?.toString() ?? extra['name']?.toString();
            image =
                extra['image']?.toString() ?? extra['peerImage']?.toString();
            allowLikeBack =
                extra['allowLikeBack'] == true ||
                extra['from_incoming_like'] == true;
          }
          return PeerProfilePage(
            userId: state.pathParameters['userId']!,
            initialName: name,
            initialImage: image,
            allowLikeBack: allowLikeBack,
          );
        },
      ),
      GoRoute(
        path: '/app/mood',
        parentNavigatorKey: _rootKey,
        builder: (c, s) => const MoodPage(),
      ),
      GoRoute(
        path: '/app/premium',
        parentNavigatorKey: _rootKey,
        builder: (context, s) {
          return Consumer(
            builder: (context, ref, child) {
              return SubscriptionPaywall(
                allowClose: true,
                onPurchase: () async {
                  await ref
                      .read(subscriptionRepositoryProvider)
                      .purchase(const Uuid().v4());
                  if (context.mounted) context.pop();
                },
              );
            },
          );
        },
      ),
    ],
  );
});

class _AuthNavRefresh extends ChangeNotifier {
  _AuthNavRefresh(this.ref) {
    _sub = ref.listen<AuthNavSnapshot>(authNavProvider, (previous, next) {
      if (previous != next) notifyListeners();
    });
  }

  final Ref ref;
  late final ProviderSubscription<AuthNavSnapshot> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
