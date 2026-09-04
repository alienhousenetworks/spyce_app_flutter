import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/notifications/push_notification_service.dart';
import '../../core/theme/spyce_colors.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool _matchAlerts = true;
  bool _messageAlerts = true;
  bool _likeAlerts = true;
  bool _callAlerts = true;
  bool _confessionAlerts = true;
  bool _permissionGranted = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    if (kIsWeb) {
      if (mounted) setState(() => _checkingPermission = false);
      return;
    }
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (mounted) {
        setState(() {
          _permissionGranted =
              settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
          _checkingPermission = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingPermission = false);
    }
  }

  Future<void> _requestPermission() async {
    try {
      final service = ref.read(pushNotificationServiceProvider);
      await service.initialize();
      await _checkPermissionStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _permissionGranted
                  ? 'Push notifications enabled successfully!'
                  : 'Notification permission was not granted. Please check system settings.',
            ),
            backgroundColor: _permissionGranted
                ? SpyceColors.teal
                : SpyceColors.pink,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enabling notifications: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Push Permission Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _permissionGranted
                    ? [
                        SpyceColors.teal.withValues(alpha: 0.15),
                        SpyceColors.dark800,
                      ]
                    : [
                        SpyceColors.pink.withValues(alpha: 0.15),
                        SpyceColors.dark800,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _permissionGranted
                    ? SpyceColors.teal.withValues(alpha: 0.4)
                    : SpyceColors.pink.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _permissionGranted
                          ? Icons.notifications_active
                          : Icons.notifications_off_outlined,
                      color: _permissionGranted
                          ? SpyceColors.teal
                          : SpyceColors.pink,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _permissionGranted
                          ? 'Push Notifications Enabled'
                          : 'Notifications Disabled',
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _permissionGranted
                      ? 'You are receiving real-time alerts for new matches, messages, and calls.'
                      : 'Enable notifications so you never miss a new match or message.',
                  style: const TextStyle(
                    color: SpyceColors.dark200,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (!_permissionGranted) ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Enable Notifications'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpyceColors.pink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          _sectionHeader('Activity Alerts'),
          Container(
            decoration: BoxDecoration(
              color: SpyceColors.dark800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SpyceColors.dark600),
            ),
            child: Column(
              children: [
                _switchTile(
                  title: 'New Matches',
                  subtitle: 'When someone matches with your profile',
                  value: _matchAlerts,
                  onChanged: (v) => setState(() => _matchAlerts = v),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _switchTile(
                  title: 'Messages & Chat Notes',
                  subtitle: 'Direct chat messages and conversation requests',
                  value: _messageAlerts,
                  onChanged: (v) => setState(() => _messageAlerts = v),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _switchTile(
                  title: 'Incoming Calls',
                  subtitle: 'Voice and video call ringing notifications',
                  value: _callAlerts,
                  onChanged: (v) => setState(() => _callAlerts = v),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _switchTile(
                  title: 'Likes & Admirers',
                  subtitle: 'When someone shows interest in your card',
                  value: _likeAlerts,
                  onChanged: (v) => setState(() => _likeAlerts = v),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _switchTile(
                  title: 'Confessions & Social',
                  subtitle: 'Replies, mood tags, and nearby confession updates',
                  value: _confessionAlerts,
                  onChanged: (v) => setState(() => _confessionAlerts = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
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
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: SpyceColors.dark200, fontSize: 12),
      ),
      value: value,
      activeColor: SpyceColors.pink,
      onChanged: onChanged,
    );
  }
}
