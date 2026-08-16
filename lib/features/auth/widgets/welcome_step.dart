import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';
import '../../../shared/widgets/onboarding_widgets.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
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
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        // Spyce Script Wordmark Branding
        Text(
          'Spyce',
          textAlign: TextAlign.center,
          style: GoogleFonts.cookie(
            fontSize: 48,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 48),

        // Translucent Glass Card
        OnboardingGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              Text(
                'An Intent-first dating app',
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'New to us?',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: OnboardingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              OnboardingPrimaryButton(
                label: 'Create an account',
                onPressed: onSignUp,
              ),
              const SizedBox(height: 20),
              Text(
                'Already a User ?',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: OnboardingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              OnboardingPrimaryButton(
                label: 'Sign in',
                onPressed: onSignIn,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Footer Text
        Text(
          'Instant Login and Sign Up with Email & OTP.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: OnboardingColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
