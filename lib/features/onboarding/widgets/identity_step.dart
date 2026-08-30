import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';
import '../../../core/utils/onboarding.dart';
import '../../../data/models/user_models.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../../shared/widgets/onboarding_widgets.dart';

class IdentityStep extends StatelessWidget {
  const IdentityStep({
    super.key,
    required this.usernameCtrl,
    required this.dobCtrl,
    required this.genderOpts,
    required this.sexualityOpts,
    required this.languageOpts,
    required this.gender,
    required this.sexuality,
    required this.selectedLanguageIds,
    required this.genderLocked,
    required this.sexualityLocked,
    required this.onGenderChanged,
    required this.onSexualityChanged,
    required this.onLanguagesChanged,
    required this.onDobChanged,
  });

  final TextEditingController usernameCtrl;
  final TextEditingController dobCtrl;
  final List<CatalogOption> genderOpts;
  final List<CatalogOption> sexualityOpts;
  final List<CatalogOption> languageOpts;
  final String? gender;
  final String? sexuality;
  final Set<String> selectedLanguageIds;
  final bool genderLocked;
  final bool sexualityLocked;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<String> onSexualityChanged;
  final ValueChanged<Set<String>> onLanguagesChanged;
  final VoidCallback onDobChanged;

  DateTime? get _dob => parseDob(dobCtrl.text);

  int? get _age {
    final dt = _dob;
    if (dt == null) return null;
    return ageFromDob(dt);
  }

  Future<void> _pickDob(BuildContext context) async {
    final now = DateTime.now();
    final last = DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(1940, 1, 1);
    final initial = _dob ?? DateTime(now.year - 21, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
      helpText: 'When were you born?',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: OnboardingColors.accentRed,
              onPrimary: Colors.white,
              surface: OnboardingColors.bgDark,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: OnboardingColors.bgDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    dobCtrl.text = formatDobDisplay(picked);
    onDobChanged();
  }

  @override
  Widget build(BuildContext context) {
    final age = _age;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnboardingFieldLabel('Username'),
        OnboardingTextField(controller: usernameCtrl, hintText: 'e.g. alex'),
        const SizedBox(height: 6),
        const OnboardingHelperText("this is how you'll appear on your profile"),

        const SizedBox(height: 24),
        const OnboardingFieldLabel('Birthday'),
        OnboardingTextField(
          controller: dobCtrl,
          hintText: 'DD/MM/YYYY',
          keyboardType: TextInputType.number,
          inputFormatters: const [_DobSlashFormatter()],
          onChanged: (_) => onDobChanged(),
          suffixIcon: IconButton(
            onPressed: () => _pickDob(context),
            icon: Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 6),
        OnboardingHelperText(
          age == null
              ? 'Type DD/MM/YYYY or tap the calendar'
              : age < 18
                  ? 'You must be 18+ to join SPYCE'
                  : '$age years old',
        ),

        const SizedBox(height: 24),
        const OnboardingFieldLabel('Gender'),
        _ChipWrap(
          options: genderOpts,
          selectedId: gender,
          locked: genderLocked,
          onSelect: onGenderChanged,
        ),

        const SizedBox(height: 24),
        const OnboardingFieldLabel('Sexuality'),
        _ChipWrap(
          options: sexualityOpts,
          selectedId: sexuality,
          locked: sexualityLocked,
          onSelect: onSexualityChanged,
        ),

        const SizedBox(height: 24),
        const OnboardingFieldLabel('Languages you speak'),
        LanguagePicker(
          options: languageOpts,
          selectedIds: selectedLanguageIds,
          onChanged: onLanguagesChanged,
        ),
      ],
    );
  }
}

class _DobSlashFormatter extends TextInputFormatter {
  const _DobSlashFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.options,
    required this.selectedId,
    required this.locked,
    required this.onSelect,
  });

  final List<CatalogOption> options;
  final String? selectedId;
  final bool locked;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(
        'Options unavailable — reconnect and retry.',
        style: GoogleFonts.dmSans(
          color: OnboardingColors.textMuted,
          fontSize: 13,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        return OnboardingChoiceChip(
          label: o.name,
          selected: selectedId == o.id,
          locked: locked,
          onTap: () => onSelect(o.id),
        );
      }).toList(),
    );
  }
}
