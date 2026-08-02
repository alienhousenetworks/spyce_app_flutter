import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/env.dart';
import '../../core/theme/spyce_colors.dart';
import '../auth/auth_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => version = '${info.version}+${info.buildNumber}');
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need an OTP to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: SpyceColors.pink)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
      if (!mounted) return;
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Account',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.person_outline,
            title: user?.email ?? 'Signed in',
            subtitle: user?.username != null ? '@${user!.username}' : null,
          ),
          _tile(
            icon: Icons.verified_user_outlined,
            title: 'Identity verification',
            subtitle: 'Coming soon in this build',
          ),
          const SizedBox(height: 20),
          Text(
            'Preferences',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () {},
          ),
          _tile(
            icon: Icons.shield_outlined,
            title: 'Safety & blocks',
            onTap: () {},
          ),
          _tile(
            icon: Icons.workspace_premium_outlined,
            title: 'Premium',
            onTap: () => context.push('/app/premium'),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: SpyceColors.pinkSoft),
            label: const Text(
              'Sign out',
              style: TextStyle(color: SpyceColors.pinkSoft),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: SpyceColors.pink.withValues(alpha: 0.4)),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }


  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: SpyceColors.dark100),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: SpyceColors.dark200))
          : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
