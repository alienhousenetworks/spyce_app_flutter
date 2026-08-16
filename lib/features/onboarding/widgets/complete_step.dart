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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const OnboardingSectionTitle('FACE VERIFICATION'),
        const SizedBox(height: 16),

        Text(
          'Live face check',
          textAlign: TextAlign.center,
          style: GoogleFonts.syne(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'It helps SPYCE be a genuine & respectful space for everyone.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: OnboardingColors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),

        const SizedBox(height: 32),

        // Verified Green Badge Circle
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: OnboardingColors.successGreen,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 52,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Verified!',
          style: GoogleFonts.cookie(
            fontSize: 36,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Thanks for helping keep SPYCE a real & safe place.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: OnboardingColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: OnboardingHelperText('you look great, by the way'),
        ),
      ],
    );
  }
}
