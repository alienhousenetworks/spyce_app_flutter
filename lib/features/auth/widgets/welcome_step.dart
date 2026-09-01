import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/legal/legal_urls.dart';
import '../../../core/theme/onboarding_theme.dart';
import '../../../core/theme/spyce_colors.dart';
import '../../../shared/widgets/onboarding_widgets.dart';
import 'social_auth_buttons.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
    super.key,
    required this.onSignIn,
    required this.onSignUp,
    required this.onGoogle,
    this.loading = false,
    this.error,
  });

  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final VoidCallback onGoogle;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
            child: Column(
              children: [
                Text(
                  'Spyce',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cookie(
                    fontSize: 72,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: SpyceColors.flame.withValues(alpha: 0.45),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'no fake vibes. just real ones.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: OnboardingColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Intent-first dating.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.syne(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Meet people who want the same thing you do.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    height: 1.4,
                    color: OnboardingColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingPrimaryButton(
                label: 'Create an account',
                onPressed: loading ? null : onSignUp,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: loading ? null : onSignIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: OnboardingColors.inputBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Sign in',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const AuthDivider(label: 'or'),
              const SizedBox(height: 16),
              GoogleSignInButton(
                loading: loading,
                onPressed: loading ? null : onGoogle,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SpyceColors.error,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.dmSans(
                    color: OnboardingColors.textMuted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                  children: [
                    const TextSpan(
                      text: 'By continuing you agree to SPYCE’s ',
                    ),
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        color: SpyceColors.pinkSoft,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = openTermsOfService,
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: SpyceColors.pinkSoft,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = openPrivacyPolicy,
                    ),
                    const TextSpan(
                      text: '. Google, email OTP, or password. 18+ only.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
