import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
                    fontSize: 64,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'no fake vibes. just real ones.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: OnboardingColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Intent-first dating.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
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
              Text(
                'By continuing you agree to SPYCE’s terms. Google, email OTP, or password.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: OnboardingColors.textMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
