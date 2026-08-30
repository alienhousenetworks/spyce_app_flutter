import 'package:flutter/material.dart';

/// SPYCE design tokens.
///
/// Brand is the flame from the loading animation — burnt ember orange —
/// on charcoal surfaces. Teal = success/online, gold = premium.
/// Screens must not invent extra hex values.
abstract final class SpyceColors {
  // Dark surfaces
  static const dark950 = Color(0xFF080808);
  static const dark900 = Color(0xFF0D0D0D);
  static const dark800 = Color(0xFF141414);
  static const dark700 = Color(0xFF1C1C1C);
  static const dark600 = Color(0xFF242424);
  static const dark500 = Color(0xFF2E2E2E);
  static const dark400 = Color(0xFF3A3A3A);
  static const dark300 = Color(0xFF525252);
  static const dark200 = Color(0xFF7A7A7A);
  static const dark100 = Color(0xFFA0A0A0);

  /// Sampled from `assets/animations/flame` (bright fill #E07E42).
  static const flame = Color(0xFFE07E42);
  static const flameMid = Color(0xFFD26A39);
  static const flameSoft = Color(0xFFF0A066);
  static const flamePale = Color(0xFFF6C9A8);
  static const flameDim = Color(0x1FE07E42);
  static const flameGlow = Color(0x40E07E42);

  /// Back-compat aliases — same flame. Do not reintroduce magenta.
  static const pink = flame;
  static const pinkMid = flameMid;
  static const pinkSoft = flameSoft;
  static const pinkPale = flamePale;
  static const pinkDim = flameDim;
  static const pinkGlow = flameGlow;

  /// Ember-tinted darks for auth/onboarding atmosphere.
  static const blush = Color(0xFF1A100A);
  static const wine = Color(0xFF6B2E12);
  static const wineDeep = Color(0xFF3A1808);

  // Accents
  static const gold = Color(0xFFF5B800);
  static const teal = Color(0xFF00D4AA);
  static const white = Color(0xFFF5F5F0);
  static const likeGreen = Color(0xFF8BD969);
  static const likeGreenDark = Color(0xFF6AB04C);

  // Semantic
  static const error = Color(0xFFFF6B81);
  static const errorDim = Color(0xFF3A1218);
  static const errorDeep = Color(0xFF7F1D1D);
  static const success = teal;
  static const warning = gold;
  static const online = teal;
  static const onlineSoft = Color(0xFF6EE7B7);

  // Text on dark
  static const textSecondary = Color(0xB3F5F5F0);
  static const textMuted = Color(0x80F5F5F0);

  // Overlays
  static const overlay = Color(0xB3000000);
  static const scrim = Color(0x73000000);

  /// Paper/cream used on feed analog cards & stickers (on-photo UI only).
  static const paper = Color(0xFFF8F1E3);
  static const paperInk = Color(0xFFF5E6C8);
  static const paperChip = Color(0xFFE8F0C8);
  static const paperChipText = Color(0xFF3D4A1C);
  static const paperWarm = Color(0xFFF3E8D0);
  static const paperWarmText = Color(0xFF4A3D1C);

  // Variant accents (bg_variant_id token → color)
  static const Map<String, Color> variantAccents = {
    'sunset': Color(0xFFFF6B35),
    'ocean': Color(0xFF0077B6),
    'midnight': Color(0xFF3D348B),
    'pink': flame,
    'teal': teal,
    'violet': Color(0xFFA855F7),
    'gold': gold,
    'coral': flameSoft,
    'ice': Color(0xFFA5F3FC),
    'emerald': Color(0xFF10B981),
    'rose': flame,
    'slate': Color(0xFF64748B),
    'amber': Color(0xFFF59E0B),
    'cyan': Color(0xFF06B6D4),
    'magenta': Color(0xFFD946EF),
    'lime': Color(0xFF84CC16),
    'peach': Color(0xFFFDBA74),
    'lavender': Color(0xFFC084FC),
    'mint': Color(0xFF6EE7B7),
    'spyce': flame,
    'cool': Color(0xFF3B82F6),
    'warm': flame,
    'dark1': Color(0xFF1E1B4B),
    'dark2': Color(0xFF312E81),
  };

  static Color accentForVariant(String? variantId) {
    if (variantId == null || variantId.isEmpty) return flame;
    final token = variantId.contains('-')
        ? variantId.split('-').last
        : variantId;
    return variantAccents[token.toLowerCase()] ?? flame;
  }
}
