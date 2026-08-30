import 'package:flutter/material.dart';

import 'spyce_colors.dart';

/// Auth + onboarding aliases onto the same SPYCE palette.
/// Do not introduce a second brand here — keep names for existing widgets.
abstract final class OnboardingColors {
  static const bgDark = SpyceColors.dark950;
  static const bgWaveOrange = SpyceColors.wine;
  static const bgWaveOrangeDark = SpyceColors.wineDeep;
  static const bgWaveTeal = SpyceColors.blush;

  static const surfaceCard = Color(0xE0141414);
  static const cardBorder = Color(0x33E07E42);

  static const inputFill = SpyceColors.dark700;
  static const inputFillFocused = SpyceColors.dark600;
  static const inputBorder = Color(0x33FFFFFF);
  static const buttonDisabled = SpyceColors.dark400;
  static const Color primary = SpyceColors.pink;

  static const sectionRed = SpyceColors.pink;
  static const accentRed = SpyceColors.pink;
  static const accentRedDark = SpyceColors.pinkMid;

  static const successGreen = SpyceColors.success;

  static const textPrimary = SpyceColors.white;
  static const textSecondary = SpyceColors.textSecondary;
  static const textMuted = SpyceColors.textMuted;
  static const textPlaceholder = SpyceColors.dark200;
}
