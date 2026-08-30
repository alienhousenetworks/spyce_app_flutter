import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';
import '../../../shared/widgets/onboarding_widgets.dart';

class CompleteStep extends StatelessWidget {
  const CompleteStep({
    super.key,
    required this.submitting,
    required this.onSubmit,
  });

  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OnboardingColors.successGreen,
              boxShadow: [
                BoxShadow(
                  color: OnboardingColors.successGreen.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Verified',
            textAlign: TextAlign.center,
            style: GoogleFonts.syne(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Thanks for helping keep SPYCE a real & safe place.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: OnboardingColors.textSecondary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const OnboardingHelperText('you look great, by the way'),
        ],
      ),
    );
  }
}
