import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';
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

  String? _findName(List<CatalogOption> options, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final o in options) {
      if (o.id == id) return o.name;
    }
    return id;
  }

  void _showGenderPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OnboardingColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Match Preferred Gender',
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: genderOpts.length,
                  itemBuilder: (_, i) {
                    final opt = genderOpts[i];
                    final isSelected = preferredGenders.contains(opt.id);
                    return ListTile(
                      title: Text(
                        opt.name,
                        style: GoogleFonts.dmSans(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: OnboardingColors.sectionRed)
                          : null,
                      onTap: () {
                        onPreferredToggle(opt.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstPreferredGender = preferredGenders.isNotEmpty
        ? _findName(genderOpts, preferredGenders.first)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnboardingSectionTitle('YOUR INTENT & MATCH'),
        const SizedBox(height: 16),

        // Choose Your Dating Intent
        Center(
          child: Text(
            'Choose Your Dating Intent',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildIntentStack(),

        const SizedBox(height: 24),

        // Choose Your Match Preferences
        Center(
          child: Text(
            'Choose Your Match Preferences',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'GENDER',
                    style: GoogleFonts.syne(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  OnboardingDropdownField(
                    label: 'Select Gender',
                    value: firstPreferredGender,
                    onTap: () => _showGenderPicker(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'SEXUALITY',
                    style: GoogleFonts.syne(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  OnboardingDropdownField(
                    label: 'Select Sexuality',
                    value: 'Any',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntentStack() {
    if (intentOpts.isEmpty) {
      return const Text(
        'Intent options loading…',
        style: TextStyle(color: OnboardingColors.textMuted, fontSize: 13),
      );
    }

    return Column(
      children: intentOpts.map((opt) {
        final selected = selectedIntent == opt.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onIntentChanged(opt.id),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? OnboardingColors.inputFillFocused
                    : OnboardingColors.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? Colors.white : OnboardingColors.inputBorder,
                  width: selected ? 1.5 : 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                opt.name,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
