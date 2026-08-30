import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';
import '../../../core/theme/spyce_colors.dart';
import '../../../data/models/user_models.dart';
import '../../../shared/widgets/onboarding_widgets.dart';

class IntentMatchStep extends StatelessWidget {
  const IntentMatchStep({
    super.key,
    required this.intentOpts,
    required this.genderOpts,
    required this.selectedIntent,
    required this.preferredGenders,
    required this.onIntentChanged,
    required this.onPreferredToggle,
  });

  final List<CatalogOption> intentOpts;
  final List<CatalogOption> genderOpts;
  final String? selectedIntent;
  final Set<String> preferredGenders;
  final ValueChanged<String> onIntentChanged;
  final ValueChanged<String> onPreferredToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnboardingFieldLabel('Dating intent'),
        if (intentOpts.isEmpty)
          Text(
            'Intent options loading…',
            style: GoogleFonts.dmSans(
              color: OnboardingColors.textMuted,
              fontSize: 13,
            ),
          )
        else
          Column(
            children: intentOpts.map((opt) {
              final selected = selectedIntent == opt.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => onIntentChanged(opt.id),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? SpyceColors.pink.withValues(alpha: 0.18)
                          : OnboardingColors.inputFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? SpyceColors.pink
                            : OnboardingColors.inputBorder,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt.name,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: selected
                              ? SpyceColors.pink
                              : Colors.white.withValues(alpha: 0.45),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 20),
        const OnboardingFieldLabel('Who do you want to meet?'),
        const OnboardingHelperText('Select one or more'),
        const SizedBox(height: 10),
        if (genderOpts.isEmpty)
          Text(
            'Preferences unavailable — reconnect and retry.',
            style: GoogleFonts.dmSans(
              color: OnboardingColors.textMuted,
              fontSize: 13,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genderOpts.map((o) {
              return OnboardingChoiceChip(
                label: o.name,
                selected: preferredGenders.contains(o.id),
                onTap: () => onPreferredToggle(o.id),
              );
            }).toList(),
          ),
      ],
    );
  }
}
