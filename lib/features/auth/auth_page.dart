import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/onboarding_widgets.dart';
import 'auth_controller.dart';
import 'widgets/email_step.dart';
import 'widgets/otp_step.dart';
import 'widgets/welcome_step.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(authControllerProvider.select((s) => s.step));
    final loading = ref.watch(authControllerProvider.select((s) => s.loading));
    final error = ref.watch(authControllerProvider.select((s) => s.error));
    final message = ref.watch(authControllerProvider.select((s) => s.message));
    final mode = ref.watch(authControllerProvider.select((s) => s.mode));
    final email = ref.watch(authControllerProvider.select((s) => s.email));
    final ctrl = ref.read(authControllerProvider.notifier);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: OnboardingWaveBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: switch (step) {
                    AuthStep.welcome => WelcomeStep(
                        key: const ValueKey('welcome'),
                        onSignIn: ctrl.chooseSignIn,
                        onSignUp: ctrl.chooseSignUp,
                      ),
                    AuthStep.email => EmailStep(
                        key: const ValueKey('email'),
                        mode: mode,
                        loading: loading,
                        error: error,
                        message: message,
                        initialEmail: email,
                        onBack: ctrl.goBackToWelcome,
                        onSwitchMode: ctrl.switchMode,
                        onSendOtp: (value, captchaToken) => ctrl.requestOtp(
                          value,
                          captchaToken: captchaToken,
                        ),
                      ),
                    AuthStep.otp => OtpStep(
                        key: const ValueKey('otp'),
                        email: email,
                        mode: mode,
                        loading: loading,
                        error: error,
                        message: message,
                        onBack: ctrl.goBackToEmail,
                        onResend: (captchaToken) => ctrl.resendOtp(
                          captchaToken: captchaToken,
                        ),
                        onVerify: (otp) async {
                          final ok = await ctrl.verifyOtp(otp);
                          if (!context.mounted || !ok) return;
                          final latest = ref.read(authControllerProvider);
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
            ),
          ),
        ),
      ),
    );
  }
}
