import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../features/auth/auth_controller.dart';

String _errorText(Object e) {
  if (e is ApiException) {
    final m = e.message;
    if (m.isEmpty || m == 'Something went wrong') {
      return 'Invalid or expired code. Please try again.';
    }
    return m;
  }
  return 'Something went wrong. Please try again.';
}

/// Delete account: warning popup -> emailed 6-digit code -> delete.
Future<void> startDeleteAccountFlow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final ctrl = ref.read(authControllerProvider.notifier);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SpyceColors.dark900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SpyceColors.pink),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: SpyceColors.pink, size: 24),
          SizedBox(width: 8),
          Text('Delete Account?'),
        ],
      ),
      content: const Text(
        'Your profile, matches, and chats will be immediately deactivated and hidden.\n\n'
            'You have a 30-day grace period to restore your account by simply logging in again with your email.\n\n'
            "We'll email you a 6-digit code to confirm.",
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
          child: const Text('Send code'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ctrl.requestDeleteOtp();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    return;
  }
  if (!context.mounted) return;

  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteCodeDialog(
      onResend: () => ctrl.requestDeleteOtp(),
      onConfirm: (code) async {
        await ctrl.deleteAccount(code);
      },
    ),
  );

  if (deleted == true) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Account scheduled for deletion. You can restore within 30 days by signing in.',
        ),
        backgroundColor: SpyceColors.pink,
      ),
    );
    router.go('/auth');
  }
}

class _DeleteCodeDialog extends StatefulWidget {
  const _DeleteCodeDialog({required this.onResend, required this.onConfirm});

  final Future<void> Function() onResend;
  final Future<void> Function(String code) onConfirm;

  @override
  State<_DeleteCodeDialog> createState() => _DeleteCodeDialogState();
}

class _DeleteCodeDialogState extends State<_DeleteCodeDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _ctrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.onConfirm(code);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(e);
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.onResend();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _info = 'A new code was sent to your email.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SpyceColors.dark900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SpyceColors.pink),
      ),
      title: const Text('Enter confirmation code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'We emailed a 6-digit code. Enter it to delete your account.',
            style: TextStyle(color: SpyceColors.dark100, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(counterText: '', hintText: '------'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: SpyceColors.error, fontSize: 12),
            ),
          ],
          if (_info != null) ...[
            const SizedBox(height: 8),
            Text(
              _info!,
              style: const TextStyle(color: SpyceColors.success, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _resend,
          child: const Text('Resend code'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: SpyceColors.pink,
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text('Delete account'),
        ),
      ],
    );
  }
}