import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';
import '../../shared/widgets/spyce_widgets.dart';
import 'auth_controller.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuild shell when step / loading / errors change — not every keystroke
    // (email is kept in local TextEditingControllers).
    final step = ref.watch(authControllerProvider.select((s) => s.step));
    final loading = ref.watch(authControllerProvider.select((s) => s.loading));
    final error = ref.watch(authControllerProvider.select((s) => s.error));
    final message = ref.watch(authControllerProvider.select((s) => s.message));
    final mode = ref.watch(authControllerProvider.select((s) => s.mode));
    final email = ref.watch(authControllerProvider.select((s) => s.email));
    final ctrl = ref.read(authControllerProvider.notifier);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Static background — do not recreate on keyboard open if possible
          const _AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SpyceLogo(size: 44, showTagline: true),
                      const SizedBox(height: 36),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: SpyceColors.dark900.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: SpyceColors.dark500),
                          boxShadow: [
                            BoxShadow(
                              color: SpyceColors.pink.withValues(alpha: 0.12),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: switch (step) {
                            AuthStep.welcome => _WelcomeStep(
                                key: const ValueKey('welcome'),
                                onSignIn: ctrl.chooseSignIn,
                                onSignUp: ctrl.chooseSignUp,
                              ),
                            AuthStep.email => _EmailStep(
                                // Keep one key so TextField state is preserved
                                // when only mode flips; do not remount on mode.
                                key: const ValueKey('email'),
                                mode: mode,
                                loading: loading,
                                error: error,
                                message: message,
                                initialEmail: email,
                                onBack: ctrl.goBackToWelcome,
                                onSwitchMode: ctrl.switchMode,
                                onSendOtp: (value) => ctrl.requestOtp(value),
                              ),
                            AuthStep.otp => _OtpStep(
                                key: const ValueKey('otp'),
                                email: email,
                                mode: mode,
                                loading: loading,
                                error: error,
                                message: message,
                                onBack: ctrl.goBackToEmail,
                                onResend: ctrl.resendOtp,
                                onVerify: (otp) async {
                                  final ok = await ctrl.verifyOtp(otp);
                                  if (!context.mounted || !ok) return;
                                  final latest =
                                      ref.read(authControllerProvider);
                                  if (latest.onboardingComplete == true) {
                                    context.go('/app/discover');
                                  } else {
                                    context.go('/onboarding');
                                  }
                                },
                              ),
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          PinkTag('Real profiles'),
                          PinkTag('Scroll discovery'),
                          PinkTag('India first'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SvgPicture.asset(
          'assets/backgrounds/HexSplashSpyce.svg',
          fit: BoxFit.cover,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                SpyceColors.dark950.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    super.key,
    required this.onSignIn,
    required this.onSignUp,
  });

  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome to SPYCE',
          style: GoogleFonts.syne(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: SpyceColors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Intent-first dating. No fake vibes — just real ones.',
          style: TextStyle(color: SpyceColors.dark100, height: 1.4),
        ),
        const SizedBox(height: 28),
        SpycePrimaryButton(
          label: 'Sign in',
          icon: Icons.login_rounded,
          onPressed: onSignIn,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onSignUp,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Create account'),
          style: OutlinedButton.styleFrom(
            foregroundColor: SpyceColors.white,
            side: BorderSide(color: SpyceColors.pink.withValues(alpha: 0.55)),
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Both use a one-time code sent to your email — no password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: SpyceColors.dark200,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// Local TextEditingController so typing never hits Riverpod / GoRouter.
class _EmailStep extends StatefulWidget {
  const _EmailStep({
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
  final Future<bool> Function(String email) onSendOtp;

  @override
  State<_EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends State<_EmailStep> {
  late final TextEditingController _emailCtrl;
  late final FocusNode _focusNode;

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
    await widget.onSendOtp(_emailCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = widget.mode == AuthMode.signUp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.loading ? null : widget.onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              color: SpyceColors.white,
            ),
            Expanded(
              child: Text(
                isSignUp ? 'Create account' : 'Sign in',
                style: GoogleFonts.syne(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: SpyceColors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isSignUp
              ? 'Enter your email — we\'ll send a code to get started.'
              : 'Welcome back. Enter your email for a one-time code.',
          style: const TextStyle(color: SpyceColors.dark100, height: 1.35),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailCtrl,
          focusNode: _focusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(color: SpyceColors.white),
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'you@example.com',
            prefixIcon: Icon(Icons.mail_outline, color: SpyceColors.dark200),
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.error!,
            style: const TextStyle(color: Color(0xFFFF6B81)),
          ),
        ],
        if (widget.message != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.message!,
            style: const TextStyle(color: SpyceColors.teal),
          ),
        ],
        const SizedBox(height: 20),
        SpycePrimaryButton(
          label: isSignUp ? 'Send code & sign up' : 'Send code & sign in',
          loading: widget.loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: widget.loading ? null : widget.onSwitchMode,
          child: Text(
            isSignUp
                ? 'Already have an account? Sign in'
                : 'New here? Create an account',
            style: const TextStyle(color: SpyceColors.pinkSoft),
          ),
        ),
      ],
    );
  }
}

class _OtpStep extends StatefulWidget {
  const _OtpStep({
    super.key,
    required this.email,
    required this.mode,
    required this.loading,
    required this.error,
    required this.message,
    required this.onBack,
    required this.onResend,
    required this.onVerify,
  });

  final String email;
  final AuthMode mode;
  final bool loading;
  final String? error;
  final String? message;
  final VoidCallback onBack;
  final Future<void> Function() onResend;
  final Future<void> Function(String otp) onVerify;

  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
  late final TextEditingController _otpCtrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _otpCtrl = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await widget.onVerify(_otpCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.loading ? null : widget.onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              color: SpyceColors.white,
            ),
            Expanded(
              child: Text(
                'Check your inbox',
                style: GoogleFonts.syne(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: SpyceColors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to ${widget.email}',
          style: const TextStyle(color: SpyceColors.dark100),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _otpCtrl,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          style: GoogleFonts.syne(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 10,
            color: SpyceColors.white,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            counterText: '',
            hintText: '••••••',
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.error!,
            style: const TextStyle(color: Color(0xFFFF6B81)),
          ),
        ],
        if (widget.message != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.message!,
            style: const TextStyle(color: SpyceColors.teal),
          ),
        ],
        const SizedBox(height: 20),
        SpycePrimaryButton(
          label: widget.mode == AuthMode.signUp
              ? 'Verify & create account'
              : 'Verify & sign in',
          loading: widget.loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: widget.loading ? null : widget.onResend,
          child: const Text(
            'Resend code',
            style: TextStyle(color: SpyceColors.pinkSoft),
          ),
        ),
      ],
    );
  }
}
