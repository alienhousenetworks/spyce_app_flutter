import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/onboarding_theme.dart';
import '../../../shared/widgets/onboarding_widgets.dart';
import '../../../shared/widgets/turnstile_widget.dart';
import '../auth_controller.dart';
import 'social_auth_buttons.dart';

class EmailStep extends StatefulWidget {
  const EmailStep({
    super.key,
    required this.mode,
    required this.method,
    required this.loading,
    required this.error,
    required this.message,
    required this.initialEmail,
    required this.onBack,
    required this.onSwitchMode,
    required this.onSwitchMethod,
    required this.onSendOtp,
    required this.onPasswordAuth,
    required this.onForgotPassword,
    required this.onGoogle,
  });

  final AuthMode mode;
  final AuthMethod method;
  final bool loading;
  final String? error;
  final String? message;
  final String initialEmail;
  final VoidCallback onBack;
  final VoidCallback onSwitchMode;
  final ValueChanged<AuthMethod> onSwitchMethod;
  final Future<bool> Function(String email, String? captchaToken) onSendOtp;
  final Future<bool> Function(String email, String password, String? captchaToken) onPasswordAuth;
  final VoidCallback onForgotPassword;
  final Future<bool> Function() onGoogle;

  @override
  State<EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends State<EmailStep> {
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final FocusNode _emailFocus;
  late final FocusNode _passFocus;
  bool _obscurePassword = true;
  String? _captchaToken;
  int _turnstileReset = 0;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _passCtrl = TextEditingController();
    _emailFocus = FocusNode();
    _passFocus = FocusNode();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
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

    if (widget.method == AuthMethod.otp) {
      await widget.onSendOtp(_emailCtrl.text, _captchaToken);
    } else {
      if (_passCtrl.text.isEmpty) {
        setState(() => _localError = 'Please enter your password.');
        return;
      }
      if (widget.mode == AuthMode.signUp && _passCtrl.text.length < 8) {
        setState(() => _localError = 'Password must be at least 8 characters.');
        return;
      }
      await widget.onPasswordAuth(
        _emailCtrl.text,
        _passCtrl.text,
        _captchaToken,
      );
    }

    if (!mounted) return;
    setState(() {
      _captchaToken = null;
      _turnstileReset++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = widget.mode == AuthMode.signUp;
    final isOtp = widget.method == AuthMethod.otp;
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
                isSignUp ? 'Create Your Account' : 'Welcome Back',
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Segmented Toggle: OTP Code vs Password
              Container(
                decoration: BoxDecoration(
                  color: OnboardingColors.inputFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: OnboardingColors.inputBorder,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.loading
                            ? null
                            : () => widget.onSwitchMethod(AuthMethod.otp),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isOtp
                                ? OnboardingColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Email OTP',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: isOtp
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isOtp
                                  ? Colors.white
                                  : OnboardingColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.loading
                            ? null
                            : () => widget.onSwitchMethod(AuthMethod.password),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !isOtp
                                ? OnboardingColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Password',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: !isOtp
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: !isOtp
                                  ? Colors.white
                                  : OnboardingColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Email Input
              OnboardingTextField(
                controller: _emailCtrl,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                hintText: 'name@example.com',
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
              ),

              // Password Input (if Password method)
              if (!isOtp) ...[
                const SizedBox(height: 14),
                OnboardingTextField(
                  controller: _passCtrl,
                  focusNode: _passFocus,
                  obscureText: _obscurePassword,
                  hintText: isSignUp
                      ? 'Create Password (min 8 chars)'
                      : 'Enter Your Password',
                  textAlign: TextAlign.center,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: OnboardingColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (!isSignUp) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.loading ? null : widget.onForgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.dmSans(
                          color: OnboardingColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],

              if (isOtp) ...[
                const SizedBox(height: 14),
                Text(
                  'We\'ll send you a secure 6-digit verification code.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: OnboardingColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],

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
                    color: Color(0xFFFF6B81),
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
                    color: Colors.tealAccent,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Button
              OnboardingPrimaryButton(
                label: isOtp
                    ? 'Get OTP'
                    : (isSignUp ? 'Sign Up' : 'Sign In'),
                loading: widget.loading,
                onPressed: _emailCtrl.text.trim().isNotEmpty ? _submit : null,
              ),

              const SizedBox(height: 16),
              const AuthDivider(),
              const SizedBox(height: 16),

              // Google Social Button
              GoogleSignInButton(
                loading: widget.loading,
                onPressed: widget.loading
                    ? null
                    : () {
                        widget.onGoogle();
                      },
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
