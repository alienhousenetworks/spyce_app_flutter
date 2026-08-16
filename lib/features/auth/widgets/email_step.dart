import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/onboarding_theme.dart';
import '../../../shared/widgets/onboarding_widgets.dart';
import '../../../shared/widgets/turnstile_widget.dart';
import '../auth_controller.dart';

class EmailStep extends StatefulWidget {
  const EmailStep({
    super.key,
    required this.mode,
    required this.loading,
    required this.error,
    required this.message,
    required this.initialEmail,
    required this.onBack,
    required this.onSwitchMode,
    required this.onSendOtp,
  });

  final AuthMode mode;
  final bool loading;
  final String? error;
  final String? message;
  final String initialEmail;
  final VoidCallback onBack;
  final VoidCallback onSwitchMode;
  final Future<bool> Function(String email, String? captchaToken) onSendOtp;

  @override
  State<EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends State<EmailStep> {
  late final TextEditingController _emailCtrl;
  late final FocusNode _focusNode;
  String? _captchaToken;
  int _turnstileReset = 0;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (Env.turnstileEnabled &&
        (_captchaToken == null || _captchaToken!.isEmpty)) {
      setState(() => _localError = 'Please complete the captcha verification.');
      return;
    }
    setState(() => _localError = null);
    await widget.onSendOtp(_emailCtrl.text, _captchaToken);
    if (!mounted) return;
    setState(() {
      _captchaToken = null;
      _turnstileReset++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = widget.mode == AuthMode.signUp;
    final showError = _localError ?? widget.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.loading ? null : widget.onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OnboardingGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              Text(
                'Your Story Starts Here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter Your Email',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              OnboardingTextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                hintText: 'name@example.com',
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ll send you a secure 6-digit code.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: OnboardingColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (Env.turnstileEnabled) ...[
                const SizedBox(height: 16),
                TurnstileWidget(
                  resetKey: _turnstileReset,
                  onTokenReceived: (token) {
                    setState(() {
                      _captchaToken = token;
                      _localError = null;
                    });
                  },
                  onExpired: () {
                    setState(() {
                      _captchaToken = null;
                      _localError = 'Captcha expired — please try again.';
                    });
                  },
                  onError: () {
                    setState(() => _captchaToken = null);
                  },
                ),
              ],
              if (showError != null) ...[
                const SizedBox(height: 12),
                Text(
                  showError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFF6B81), fontSize: 12),
                ),
              ],
              if (widget.message != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.tealAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              OnboardingPrimaryButton(
                label: 'Get OTP',
                loading: widget.loading,
                onPressed: _emailCtrl.text.trim().isNotEmpty ? _submit : null,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.loading ? null : widget.onSwitchMode,
                child: Text(
                  isSignUp
                      ? 'Already have an account? Sign in'
                      : 'New to SPYCE? Create an account',
                  style: const TextStyle(
                    color: OnboardingColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
