import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/onboarding_theme.dart';
import '../../shared/widgets/onboarding_widgets.dart';
import 'auth_controller.dart';
import 'widgets/email_step.dart';
import 'widgets/otp_step.dart';
import 'widgets/reset_password_step.dart';
import 'widgets/welcome_step.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  void _navigateToNext(BuildContext context, WidgetRef ref) {
    final latest = ref.read(authControllerProvider);
    if (latest.onboardingComplete == true) {
      context.go('/app/discover');
    } else {
      context.go('/onboarding');
    }
  }

  Future<bool> _completeFirebase(
    BuildContext context,
    WidgetRef ref,
    AuthController ctrl,
  ) async {
    final ok = await ctrl.signInWithGoogle();
    if (!context.mounted || !ok) return false;
    _navigateToNext(context, ref);
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthStep step = ref.watch(
      authControllerProvider.select((s) => s.step),
    );
    final loading = ref.watch(authControllerProvider.select((s) => s.loading));
    final error = ref.watch(authControllerProvider.select((s) => s.error));
    final message = ref.watch(authControllerProvider.select((s) => s.message));
    final mode = ref.watch(authControllerProvider.select((s) => s.mode));
    final method = ref.watch(authControllerProvider.select((s) => s.method));
    final email = ref.watch(authControllerProvider.select((s) => s.email));
    final ctrl = ref.read(authControllerProvider.notifier);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: OnboardingColors.bgDark,
      body: OnboardingWaveBackground(
        child: SafeArea(
          child: SizedBox.expand(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              child: switch (step) {
                AuthStep.welcome => WelcomeStep(
                  key: const ValueKey('welcome'),
                  loading: loading,
                  error: error,
                  onSignIn: ctrl.chooseSignIn,
                  onSignUp: ctrl.chooseSignUp,
                  onGoogle: () => _completeFirebase(context, ref, ctrl),
                ),
                AuthStep.email => EmailStep(
                  key: const ValueKey('email'),
                  mode: mode,
                  method: method,
                  loading: loading,
                  error: error,
                  message: message,
                  initialEmail: email,
                  onBack: ctrl.goBackToWelcome,
                  onSwitchMode: ctrl.switchMode,
                  onSwitchMethod: ctrl.setAuthMethod,
                  onSendOtp: (value, captchaToken) =>
                      ctrl.requestOtp(value, captchaToken: captchaToken),
                  onPasswordAuth: (emailVal, passVal, captchaToken) async {
                    final ok = mode == AuthMode.signUp
                        ? await ctrl.registerWithPassword(
                            emailVal,
                            passVal,
                            captchaToken: captchaToken,
                          )
                        : await ctrl.loginWithPassword(
                            emailVal,
                            passVal,
                            captchaToken: captchaToken,
                          );
                    if (!context.mounted || !ok) return false;
                    _navigateToNext(context, ref);
                    return true;
                  },
                  onForgotPassword: ctrl.goToForgotPassword,
                  onGoogle: () => _completeFirebase(context, ref, ctrl),
                ),
                AuthStep.otp => OtpStep(
                  key: const ValueKey('otp'),
                  email: email,
                  mode: mode,
                  loading: loading,
                  error: error,
                  message: message,
                  onBack: ctrl.goBackToEmail,
                  onResend: (captchaToken) =>
                      ctrl.resendOtp(captchaToken: captchaToken),
                  onVerify: (otp) async {
                    final ok = await ctrl.verifyOtp(otp);
                    if (!context.mounted || !ok) return;
                    _navigateToNext(context, ref);
                  },
                ),
                AuthStep.forgotPassword => ForgotPasswordStep(
                  key: const ValueKey('forgot_password'),
                  initialEmail: email,
                  loading: loading,
                  error: error,
                  message: message,
                  onBack: ctrl.goBackToEmail,
                  onRequestReset: (emailVal, captchaToken) =>
                      ctrl.requestPasswordReset(
                        emailVal,
                        captchaToken: captchaToken,
                      ),
                ),
                AuthStep.resetPassword => ResetPasswordStep(
                  key: const ValueKey('reset_password'),
                  email: email,
                  loading: loading,
                  error: error,
                  message: message,
                  onBack: ctrl.goToForgotPassword,
                  onConfirmReset: (otp, newPass) async {
                    final ok = await ctrl.confirmPasswordReset(otp, newPass);
                    if (!context.mounted || !ok) return;
                    _navigateToNext(context, ref);
                  },
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
