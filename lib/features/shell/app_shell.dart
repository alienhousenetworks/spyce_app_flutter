import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/location/location_bootstrap.dart';
import '../../core/presence/presence_service.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/repositories/api_repositories.dart';
import '../auth/auth_controller.dart';
import '../call/call_controller.dart';

/// Bottom nav: Discover · Confessions · Chat · Profile
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _maybeMood();
      // Mark this device online while SPYCE is open (periodic + lifecycle)
      ref.read(presenceServiceProvider).start();
      // Enforce location permission & GPS on first open — user cannot proceed without it
      final locOk = await ref
          .read(locationBootstrapProvider)
          .ensureOnFirstOpen();
      if (!locOk && mounted) {
        _showLocationBlockingDialog();
      }
      // Keep call signaling open so incoming rings reach this device
      ref.read(callControllerProvider.notifier).startListening();
    });
  }

  void _showLocationBlockingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: SpyceColors.dark800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.location_off_rounded,
                color: SpyceColors.pink,
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Location required',
                  style: TextStyle(
                    color: SpyceColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'SPYCE uses your location to show nearby people and paper planes.\n\nTurn on Location Services and allow access to continue.',
            style: TextStyle(color: SpyceColors.textSecondary, height: 1.45),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final ok = await ref
                      .read(locationBootstrapProvider)
                      .detectAndSave(force: true);
                  if (!ok && mounted) {
                    _showLocationBlockingDialog();
                  }
                },
                child: const Text('Enable & retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Don't stop presence here if shell rebuilds; provider dispose handles it.
    super.dispose();
  }

  Future<void> _maybeMood() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final lastPromptMs = prefs.getInt('last_mood_prompt_time') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // 6 hours cooldown = 6 * 60 * 60 * 1000 = 21,600,000 ms
    if (nowMs - lastPromptMs < 21600000) return;

    final shown = ref.read(_moodPromptedProvider);
    if (shown) return;
    ref.read(_moodPromptedProvider.notifier).state = true;
    await prefs.setInt('last_mood_prompt_time', nowMs);

    if (widget.navigationShell.currentIndex == 0 && mounted) {
      context.push('/app/mood');
    }
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionExpiredProvider, (prev, next) {
      if (next == true) {
        ref.read(authControllerProvider.notifier).logout();
        context.go('/auth');
      }
    });

    final i = widget.navigationShell.currentIndex;

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: SpyceColors.dark900,
          border: Border(
            top: BorderSide(color: SpyceColors.dark600, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore,
                    label: 'Discover',
                    selected: i == 0,
                    onTap: () => _onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.nightlight_outlined,
                    activeIcon: Icons.nightlight,
                    label: 'Confess',
                    selected: i == 1,
                    onTap: () => _onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_outline,
                    activeIcon: Icons.chat_bubble,
                    label: 'Chat',
                    selected: i == 2,
                    onTap: () => _onTap(2),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profile',
                    selected: i == 3,
                    onTap: () => _onTap(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _moodPromptedProvider = StateProvider<bool>((ref) => false);

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SpyceColors.pink : SpyceColors.dark200;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? SpyceColors.pinkDim : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
