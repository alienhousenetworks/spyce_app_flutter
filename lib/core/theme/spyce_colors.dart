import 'package:flutter/material.dart';

/// SPYCE design tokens — aligned with web globals.css
abstract final class SpyceColors {
  // Dark palette
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

  // Brand
  static const pink = Color(0xFFFF1F6B);
  static const pinkMid = Color(0xFFE8185E);
  static const pinkSoft = Color(0xFFFF6FA3);
  static const pinkPale = Color(0xFFFFB3CC);
  static const pinkDim = Color(0x1FFF1F6B);
  static const pinkGlow = Color(0x40FF1F6B);

  // Accents
  static const gold = Color(0xFFF5B800);
  static const teal = Color(0xFF00D4AA);
  static const white = Color(0xFFF5F5F0);
  static const likeGreen = Color(0xFF8BD969);
  static const likeGreenDark = Color(0xFF6AB04C);

  // Variant accents (bg_variant_id token → color)
  static const Map<String, Color> variantAccents = {
    'sunset': Color(0xFFFF6B35),
    'ocean': Color(0xFF0077B6),
    'midnight': Color(0xFF3D348B),
    'pink': Color(0xFFFF1F6B),
    'teal': Color(0xFF00D4AA),
    'violet': Color(0xFFA855F7),
    'gold': Color(0xFFF5B800),
    'coral': Color(0xFFFF6FA3),
    'ice': Color(0xFFA5F3FC),
    'emerald': Color(0xFF10B981),
    'rose': Color(0xFFFB7185),
    'slate': Color(0xFF64748B),
    'amber': Color(0xFFF59E0B),
    'cyan': Color(0xFF06B6D4),
    'magenta': Color(0xFFD946EF),
    'lime': Color(0xFF84CC16),
    'peach': Color(0xFFFDBA74),
    'lavender': Color(0xFFC084FC),
    'mint': Color(0xFF6EE7B7),
    'spyce': Color(0xFFFF2E74),
    'cool': Color(0xFF3B82F6),
    'warm': Color(0xFFF97316),
    'dark1': Color(0xFF1E1B4B),
    'dark2': Color(0xFF312E81),
  };

  static Color accentForVariant(String? variantId) {
    if (variantId == null || variantId.isEmpty) return pink;
    final token = variantId.contains('-')
        ? variantId.split('-').last
        : variantId;
    return variantAccents[token.toLowerCase()] ?? pink;
  }
}
