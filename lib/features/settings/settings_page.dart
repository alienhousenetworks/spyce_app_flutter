import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
      if (mounted) {
        setState(() => version = '${info.version}+${info.buildNumber}');
      }
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign back in to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: SpyceColors.pink),
            ),
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

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpyceColors.dark900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: SpyceColors.pink),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: SpyceColors.pink, size: 24),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'Your profile, matches, and chats will be immediately deactivated and hidden.\n\n'
          'You have a 30-day grace period to restore your account by simply logging in again with your email. After 30 days, your data will be permanently wiped.',
          style: TextStyle(color: SpyceColors.dark100, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SpyceColors.pink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(authControllerProvider.notifier).deleteAccount();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account scheduled for deletion. You can restore within 30 days by signing in.'),
            backgroundColor: SpyceColors.pink,
          ),
        );
        context.go('/auth');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
        context.go('/auth');
      }
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
          _section('Account', [
            _tile(
              icon: Icons.person_outline,
              title: user?.email ?? 'Signed in',
              subtitle: user?.username != null ? '@${user!.username}' : null,
            ),
            _divider(),
            _tile(
              icon: Icons.verified_user_outlined,
              title: 'Identity verification',
              subtitle: 'Coming soon in this build',
            ),
          ]),
          const SizedBox(height: 20),
          _section('Preferences', [
            _tile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () => context.push('/app/settings/notifications'),
            ),
            _divider(),
            _tile(
              icon: Icons.shield_outlined,
              title: 'Safety & blocks',
              onTap: () {},
            ),
            _divider(),
            _tile(
              icon: Icons.workspace_premium_outlined,
              title: 'Premium',
              onTap: () => context.push('/app/premium'),
            ),
          ]),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white70),
            label: const Text(
              'Sign out',
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: SpyceColors.dark600),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _deleteAccount,
            icon: const Icon(Icons.delete_forever, color: SpyceColors.pink),
            label: const Text(
              'Delete Account',
              style: TextStyle(color: SpyceColors.pink, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: SpyceColors.pink.withValues(alpha: 0.5)),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          if (version.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'SPYCE $version',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SpyceColors.dark300,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.syne(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.1,
              color: SpyceColors.dark100,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: SpyceColors.dark800,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SpyceColors.dark600),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 52, endIndent: 12);
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(icon, color: SpyceColors.pinkSoft),
      title: Text(title, style: const TextStyle(color: SpyceColors.white)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: SpyceColors.dark200))
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: SpyceColors.dark300)
          : null,
      onTap: onTap,
    );
  }
}
