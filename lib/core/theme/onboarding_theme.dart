import 'package:flutter/material.dart';

abstract final class OnboardingColors {
  // Page background & wave accents (Matching Figma Alien House palette)
  static const bgDark = Color(0xFF09141E);
  static const bgWaveOrange = Color(0xFFC84B1A);
  static const bgWaveOrangeDark = Color(0xFFA63910);
  static const bgWaveTeal = Color(0xFF0F2B3C);

  // Glass card & surface tokens
  static const surfaceCard = Color(0xDC0D1E2B);
  static const cardBorder = Color(0x33FFFFFF);

  // Inputs, buttons & controls (Dark teal/slate fill)
  static const inputFill = Color(0xFF2B5866);
  static const inputFillFocused = Color(0xFF346B7C);
  static const inputBorder = Color(0x40FFFFFF);
  static const buttonDisabled = Color(0xFF475569);

  // Brand Red/Coral Accents (Section titles & Face verification CTA)
  static const sectionRed = Color(0xFFEF4444);
  static const accentRed = Color(0xFFE52E2E);
  static const accentRedDark = Color(0xFFDC2626);

  // Success Green (Verified badge)
  static const successGreen = Color(0xFF22C55E);

  // Typography
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xB3FFFFFF);
  static const textMuted = Color(0x80FFFFFF);
  static const textPlaceholder = Color(0x99FFFFFF);
}
