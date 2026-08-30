import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/onboarding_theme.dart';
import '../../../core/theme/spyce_colors.dart';
import '../../../shared/widgets/onboarding_widgets.dart';
import '../../../shared/widgets/turnstile_widget.dart';

class ForgotPasswordStep extends StatefulWidget {
  const ForgotPasswordStep({
    super.key,
    required this.initialEmail,
    required this.loading,
    required this.error,
    required this.message,
    required this.onBack,
    required this.onRequestReset,
  });

  final String initialEmail;
  final bool loading;
  final String? error;
  final String? message;
  final VoidCallback onBack;
  final Future<bool> Function(String email, String? captchaToken)
  onRequestReset;

  @override
  State<ForgotPasswordStep> createState() => _ForgotPasswordStepState();
}

class _ForgotPasswordStepState extends State<ForgotPasswordStep> {
  late final TextEditingController _emailCtrl;
  String? _captchaToken;
  int _turnstileReset = 0;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
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
    await widget.onRequestReset(_emailCtrl.text, _captchaToken);
    if (!mounted) return;
    setState(() {
      _captchaToken = null;
      _turnstileReset++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showError = _localError ?? widget.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: widget.loading ? null : widget.onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset your password',
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter your email and we'll send a 6-digit recovery code.",
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    height: 1.4,
                    color: OnboardingColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const OnboardingFieldLabel('Email'),
                OnboardingTextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  hintText: 'name@example.com',
                  onChanged: (_) => setState(() {}),
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
                    style: const TextStyle(
                      color: SpyceColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (widget.message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SpyceColors.success,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: OnboardingPrimaryButton(
            label: 'Send recovery code',
            loading: widget.loading,
            onPressed: _emailCtrl.text.trim().isNotEmpty ? _submit : null,
          ),
        ),
      ],
    );
  }
}

class ResetPasswordStep extends StatefulWidget {
  const ResetPasswordStep({
    super.key,
    required this.email,
    required this.loading,
    required this.error,
    required this.message,
    required this.onBack,
    required this.onConfirmReset,
  });

  final String email;
  final bool loading;
  final String? error;
  final String? message;
  final VoidCallback onBack;
  final Future<void> Function(String otp, String newPassword) onConfirmReset;

  @override
  State<ResetPasswordStep> createState() => _ResetPasswordStepState();
}

class _ResetPasswordStepState extends State<ResetPasswordStep> {
  late final TextEditingController _otpCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _confirmPassCtrl;
  bool _obscurePass = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _otpCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _confirmPassCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final otp = _otpCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (otp.length < 4) {
      setState(() => _localError = 'Enter the 6-digit recovery code.');
      return;
    }
    if (pass.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _localError = 'Passwords do not match.');
      return;
    }
    setState(() => _localError = null);
    await widget.onConfirmReset(otp, pass);
  }

  @override
  Widget build(BuildContext context) {
    final showError = _localError ?? widget.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: widget.loading ? null : widget.onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set a new password',
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Code sent to ${widget.email}',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    height: 1.4,
                    color: OnboardingColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const OnboardingFieldLabel('Recovery code'),
                OnboardingTextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  hintText: '6-digit code',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                const OnboardingFieldLabel('New password'),
                OnboardingTextField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  hintText: 'Min 8 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                      color: OnboardingColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                const OnboardingFieldLabel('Confirm password'),
                OnboardingTextField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscurePass,
                  hintText: 'Re-enter password',
                  onChanged: (_) => setState(() {}),
                ),
                if (showError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    showError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SpyceColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (widget.message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SpyceColors.success,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: OnboardingPrimaryButton(
            label: 'Save & sign in',
            loading: widget.loading,
            onPressed:
                (_otpCtrl.text.isNotEmpty &&
                    _passCtrl.text.isNotEmpty &&
                    _confirmPassCtrl.text.isNotEmpty)
                ? _submit
                : null,
          ),
        ),
      ],
    );
  }
}
