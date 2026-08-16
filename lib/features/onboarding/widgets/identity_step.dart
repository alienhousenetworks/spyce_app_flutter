import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';
import '../../../data/models/user_models.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../../shared/widgets/onboarding_widgets.dart';

class IdentityStep extends StatefulWidget {
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

  @override
  State<IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends State<IdentityStep> {
  late final TextEditingController _dayCtrl;
  late final TextEditingController _monthCtrl;
  late final TextEditingController _yearCtrl;

  @override
  void initState() {
    super.initState();
    final parts = widget.dobCtrl.text.split('-');
    if (parts.length == 3) {
      _yearCtrl = TextEditingController(text: parts[0]);
      _monthCtrl = TextEditingController(text: parts[1]);
      _dayCtrl = TextEditingController(text: parts[2]);
    } else {
      _yearCtrl = TextEditingController();
      _monthCtrl = TextEditingController();
      _dayCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _syncDob() {
    final y = _yearCtrl.text.trim().padLeft(4, '0');
    final m = _monthCtrl.text.trim().padLeft(2, '0');
    final d = _dayCtrl.text.trim().padLeft(2, '0');
    if (_yearCtrl.text.length == 4 && _monthCtrl.text.isNotEmpty && _dayCtrl.text.isNotEmpty) {
      widget.dobCtrl.text = '$y-$m-$d';
    } else {
      widget.dobCtrl.text = '';
    }
    setState(() {});
  }

  int? get _calculatedAge {
    final raw = widget.dobCtrl.text.trim();
    if (raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    final now = DateTime.now();
    var age = now.year - dt.year;
    if (now.month < dt.month || (now.month == dt.month && now.day < dt.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  String? _findName(List<CatalogOption> options, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final o in options) {
      if (o.id == id) return o.name;
    }
    return id;
  }

  void _showOptionPicker(
    String title,
    List<CatalogOption> options,
    String? currentId,
    ValueChanged<String> onSelect,
  ) {
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
                title,
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
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final opt = options[i];
                    final isSelected = currentId == opt.id;
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
                        onSelect(opt.id);
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
    final age = _calculatedAge;
    final selectedGenderName = _findName(widget.genderOpts, widget.gender);
    final selectedSexualityName = _findName(widget.sexualityOpts, widget.sexuality);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnboardingSectionTitle('YOUR IDENTITY'),
        const SizedBox(height: 16),

        // Create A Username
        Center(
          child: Text(
            'Create A Username',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OnboardingTextField(
          controller: widget.usernameCtrl,
          hintText: 'e.g. Alex',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Center(
          child: OnboardingHelperText('this is how you\'ll appear on your profile'),
        ),

        const SizedBox(height: 20),

        // When were you born?
        Center(
          child: Text(
            'When were you born?',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'DAY',
                    style: GoogleFonts.syne(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  OnboardingTextField(
                    controller: _dayCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    hintText: '1',
                    onChanged: (_) => _syncDob(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'MONTH',
                    style: GoogleFonts.syne(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  OnboardingTextField(
                    controller: _monthCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    hintText: '1',
                    onChanged: (_) => _syncDob(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'YEAR',
                    style: GoogleFonts.syne(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  OnboardingTextField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    hintText: '2004',
                    onChanged: (_) => _syncDob(),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (age != null) ...[
          const SizedBox(height: 4),
          Center(
            child: OnboardingHelperText('$age years old'),
          ),
        ],

        const SizedBox(height: 20),

        // GENDER & SEXUALITY Dropdowns
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
                    value: selectedGenderName,
                    onTap: () {
                      if (!widget.genderLocked) {
                        _showOptionPicker(
                          'Select Gender',
                          widget.genderOpts,
                          widget.gender,
                          widget.onGenderChanged,
                        );
                      }
                    },
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
                    value: selectedSexualityName,
                    onTap: () {
                      if (!widget.sexualityLocked) {
                        _showOptionPicker(
                          'Select Sexuality',
                          widget.sexualityOpts,
                          widget.sexuality,
                          widget.onSexualityChanged,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Languages that you speak
        Center(
          child: Text(
            'Languages that you speak',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LanguagePicker(
          options: widget.languageOpts,
          selectedIds: widget.selectedLanguageIds,
          onChanged: widget.onLanguagesChanged,
        ),
      ],
    );
  }
}
