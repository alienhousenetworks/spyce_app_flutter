import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/spyce_colors.dart';
import '../../data/repositories/api_repositories.dart';
import '../auth/auth_controller.dart';
import '../../shared/widgets/delete_account_flow.dart';


class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String version = '';
  bool? identityVerified;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => version = '${info.version}+${info.buildNumber}');
      }
    });
    _loadVerification();
  }

  Future<void> _loadVerification() async {
    try {
      final cfg = await ref.read(verificationRepositoryProvider).getConfig();
      if (!mounted) return;
      setState(() => identityVerified = cfg.verified);
    } catch (_) {}
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

  Future<void> _showChangePasswordDialog() async {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String? localError;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpyceColors.dark700,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change Password',
                style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SpyceColors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your current password and choose a new one.',
                style: GoogleFonts.dmSans(
                  color: SpyceColors.dark200,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              if (localError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: SpyceColors.pinkDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    localError!,
                    style: const TextStyle(color: SpyceColors.pink, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: oldPassCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Current password',
                  labelStyle: const TextStyle(color: SpyceColors.dark200),
                  filled: true,
                  fillColor: SpyceColors.dark800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New password (min 8 chars)',
                  labelStyle: const TextStyle(color: SpyceColors.dark200),
                  filled: true,
                  fillColor: SpyceColors.dark800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  labelStyle: const TextStyle(color: SpyceColors.dark200),
                  filled: true,
                  fillColor: SpyceColors.dark800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final oldPass = oldPassCtrl.text.trim();
                        final newPass = newPassCtrl.text.trim();
                        final confirmPass = confirmPassCtrl.text.trim();
                        if (newPass.length < 8) {
                          setModalState(() => localError = 'New password must be at least 8 characters.');
                          return;
                        }
                        if (newPass != confirmPass) {
                          setModalState(() => localError = 'New passwords do not match.');
                          return;
                        }
                        setModalState(() {
                          isSubmitting = true;
                          localError = null;
                        });
                        final res = await ref.read(authControllerProvider.notifier).changePassword(
                              newPass,
                              oldPassword: oldPass.isNotEmpty ? oldPass : null,
                            );
                        if (!ctx.mounted) return;
                        if (res.ok) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: SpyceColors.teal,
                            ),
                          );
                        } else {
                          setModalState(() {
                            isSubmitting = false;
                            localError = res.message;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpyceColors.pink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
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
              subtitle: identityVerified == true
                  ? 'Verified'
                  : identityVerified == false
                      ? 'Required for Discover'
                      : 'Check status',
              onTap: () => context.push('/app/settings/verification'),
            ),
            _divider(),
            _tile(
              icon: Icons.lock_outline,
              title: 'Change password',
              subtitle: 'Update your account password',
              onTap: _showChangePasswordDialog,
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
              subtitle: 'Blocked people, report & unblock',
              onTap: () => context.push('/app/settings/safety'),
            ),
            _divider(),
            _tile(
              icon: Icons.workspace_premium_outlined,
              title: 'Premium',
              onTap: () => context.push('/app/premium'),
            ),
          ]),
          const SizedBox(height: 20),
          _section('Legal', [
            _tile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => context.push('/app/settings/legal/privacy'),
            ),
            _divider(),
            _tile(
              icon: Icons.gavel_outlined,
              title: 'Terms of Service',
              onTap: () => context.push('/app/settings/legal/terms'),
            ),
            _divider(),
            _tile(
              icon: Icons.menu_book_outlined,
              title: 'Community Guidelines',
              onTap: () => context.push('/app/settings/legal/community'),
            ),
            _divider(),
            _tile(
              icon: Icons.fact_check_outlined,
              title: 'Privacy consent (DPDP)',
              subtitle: 'Matchmaking, location, sensitive data',
              onTap: () => context.push('/app/settings/consent'),
            ),
          ]),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            label: Text(
              'Sign out',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => startDeleteAccountFlow(context, ref),
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: SpyceColors.flameDim,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: SpyceColors.flameSoft, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          color: SpyceColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: SpyceColors.dark200, fontSize: 12),
            )
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: SpyceColors.dark300)
          : null,
      onTap: onTap,
    );
  }
}
