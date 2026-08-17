import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';

/// Available Writing Styles for Confessions
enum ConfessionStyleType {
  standard,
  numbered,
  poetry,
  letter,
  darkSecret,
  midnight,
}

extension ConfessionStyleTypeExt on ConfessionStyleType {
  String get code {
    switch (this) {
      case ConfessionStyleType.standard:
        return 'STANDARD';
      case ConfessionStyleType.numbered:
        return 'NUMBERED';
      case ConfessionStyleType.poetry:
        return 'POETRY';
      case ConfessionStyleType.letter:
        return 'LETTER';
      case ConfessionStyleType.darkSecret:
        return 'DARK_SECRET';
      case ConfessionStyleType.midnight:
        return 'MIDNIGHT';
    }
  }

  String get label {
    switch (this) {
      case ConfessionStyleType.standard:
        return 'Confession';
      case ConfessionStyleType.numbered:
        return 'Numbered';
      case ConfessionStyleType.poetry:
        return 'Poetry';
      case ConfessionStyleType.letter:
        return 'Letter';
      case ConfessionStyleType.darkSecret:
        return 'Dark Secret';
      case ConfessionStyleType.midnight:
        return '3 AM';
    }
  }

  IconData get icon {
    switch (this) {
      case ConfessionStyleType.standard:
        return Icons.auto_awesome;
      case ConfessionStyleType.numbered:
        return Icons.format_list_numbered_rounded;
      case ConfessionStyleType.poetry:
        return Icons.menu_book_rounded;
      case ConfessionStyleType.letter:
        return Icons.mark_email_unread_outlined;
      case ConfessionStyleType.darkSecret:
        return Icons.lock_outline_rounded;
      case ConfessionStyleType.midnight:
        return Icons.nightlight_round;
    }
  }

  String get defaultPrompt {
    switch (this) {
      case ConfessionStyleType.standard:
        return 'Spill something real that you can\'t say out loud…';
      case ConfessionStyleType.numbered:
        return '1. Things I pretend not to care about:\n2. But actually keep me up at night…';
      case ConfessionStyleType.poetry:
        return 'In the quiet hours of night,\nWhere secrets hide from sight,\nI wonder if you feel this too…';
      case ConfessionStyleType.letter:
        return 'Dear Stranger in the coffee shop,\n\nI never got the courage to say…';
      case ConfessionStyleType.darkSecret:
        return 'I have carried this guilt for so long that nobody knows…';
      case ConfessionStyleType.midnight:
        return 'It is 3:15 AM and my mind is replaying every word you said…';
    }
  }

  static ConfessionStyleType fromCode(String? code) {
    final c = (code ?? '').toUpperCase();
    if (c == 'NUMBERED') return ConfessionStyleType.numbered;
    if (c == 'POETRY') return ConfessionStyleType.poetry;
    if (c == 'LETTER') return ConfessionStyleType.letter;
    if (c == 'DARK_SECRET') return ConfessionStyleType.darkSecret;
    if (c == 'MIDNIGHT') return ConfessionStyleType.midnight;
    return ConfessionStyleType.standard;
  }
}

/// Creative Ornamental Divider Presets
class ConfessionDividerPreset {
  const ConfessionDividerPreset({
    required this.id,
    required this.name,
    required this.pattern,
    required this.icon,
    required this.symbol,
  });

  final String id;
  final String name;
  final String pattern;
  final IconData icon;
  final String symbol;

  static const List<ConfessionDividerPreset> all = [
    ConfessionDividerPreset(
      id: 'starlight',
      name: 'Starlight',
      pattern: '\n─── ✦ ───\n',
      icon: Icons.star_border_rounded,
      symbol: '✦',
    ),
    ConfessionDividerPreset(
      id: 'floral',
      name: 'Vintage Floral',
      pattern: '\n┈┈┈┈ ❦ ┈┈┈┈\n',
      icon: Icons.filter_vintage_outlined,
      symbol: '❦',
    ),
    ConfessionDividerPreset(
      id: 'gem',
      name: 'Obsidian Gem',
      pattern: '\n────── ❖ ──────\n',
      icon: Icons.diamond_outlined,
      symbol: '❖',
    ),
    ConfessionDividerPreset(
      id: 'moon',
      name: 'Midnight Moon',
      pattern: '\n⋯⋯ ☾ ⋯⋯\n',
      icon: Icons.nightlight_outlined,
      symbol: '☾',
    ),
    ConfessionDividerPreset(
      id: 'pulse',
      name: 'Electric Pulse',
      pattern: '\n═════ ⚡ ═════\n',
      icon: Icons.bolt_rounded,
      symbol: '⚡',
    ),
    ConfessionDividerPreset(
      id: 'rule',
      name: 'Sleek Rule',
      pattern: '\n━━━━━━━━━━━━\n',
      icon: Icons.horizontal_rule_rounded,
      symbol: '━',
    ),
  ];
}

/// Dark Aesthetic Themes for Confession Cards
class ConfessionThemeConfig {
  const ConfessionThemeConfig({
    required this.id,
    required this.name,
    required this.gradient,
    required this.borderColor,
    required this.accentColor,
    required this.glowColor,
    required this.textColor,
    required this.metaColor,
    required this.badgeColor,
    required this.icon,
  });

  final String id;
  final String name;
  final LinearGradient gradient;
  final Color borderColor;
  final Color accentColor;
  final Color glowColor;
  final Color textColor;
  final Color metaColor;
  final Color badgeColor;
  final IconData icon;

  static final ConfessionThemeConfig obsidian = ConfessionThemeConfig(
    id: 'OBSIDIAN',
    name: 'Obsidian Noir',
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF131316), Color(0xFF09090B)],
    ),
    borderColor: const Color(0xFF282830),
    accentColor: SpyceColors.pinkSoft,
    glowColor: SpyceColors.pink.withValues(alpha: 0.15),
    textColor: const Color(0xFFF1F1F3),
    metaColor: const Color(0xFF8E8E93),
    badgeColor: const Color(0xFF1C1C22),
    icon: Icons.dark_mode_outlined,
  );

  static final ConfessionThemeConfig crimson = ConfessionThemeConfig(
    id: 'CRIMSON',
    name: 'Crimson Velvet',
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1C080E), Color(0xFF0D0306)],
    ),
    borderColor: const Color(0xFF4A1422),
    accentColor: const Color(0xFFFF3366),
    glowColor: const Color(0xFFFF3366).withValues(alpha: 0.2),
    textColor: const Color(0xFFFFF0F2),
    metaColor: const Color(0xFFA67C85),
    badgeColor: const Color(0xFF2E0C16),
    icon: Icons.favorite_border_rounded,
  );

  static final ConfessionThemeConfig midnight = ConfessionThemeConfig(
    id: 'MIDNIGHT_ABYSS',
    name: 'Midnight Abyss',
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A1124), Color(0xFF040710)],
    ),
    borderColor: const Color(0xFF1A2B52),
    accentColor: const Color(0xFF5B92E5),
    glowColor: const Color(0xFF5B92E5).withValues(alpha: 0.2),
    textColor: const Color(0xFFEAF2FF),
    metaColor: const Color(0xFF7A8EAF),
    badgeColor: const Color(0xFF101B36),
    icon: Icons.nights_stay_outlined,
  );

  static final ConfessionThemeConfig cyber = ConfessionThemeConfig(
    id: 'CYBER_NEON',
    name: 'Cyber Neon',
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF091717), Color(0xFF020909)],
    ),
    borderColor: const Color(0xFF0E3D38),
    accentColor: const Color(0xFF00F5D4),
    glowColor: const Color(0xFF00F5D4).withValues(alpha: 0.2),
    textColor: const Color(0xFFE8FFF9),
    metaColor: const Color(0xFF6B9C95),
    badgeColor: const Color(0xFF0B2421),
    icon: Icons.bolt_outlined,
  );

  static final ConfessionThemeConfig charcoal = ConfessionThemeConfig(
    id: 'SMOKY_PARCHMENT',
    name: 'Smoky Charcoal',
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF181512), Color(0xFF0B0A08)],
    ),
    borderColor: const Color(0xFF383027),
    accentColor: const Color(0xFFE0A96D),
    glowColor: const Color(0xFFE0A96D).withValues(alpha: 0.18),
    textColor: const Color(0xFFF7EFE6),
    metaColor: const Color(0xFFA39688),
    badgeColor: const Color(0xFF26201A),
    icon: Icons.history_edu_outlined,
  );

  static final ConfessionThemeConfig amethyst = ConfessionThemeConfig(
    id: 'AMETHYST',
    name: 'Amethyst Haze',
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B0C24), Color(0xFF0A040F)],
    ),
    borderColor: const Color(0xFF451952),
    accentColor: const Color(0xFFB5179E),
    glowColor: const Color(0xFFB5179E).withValues(alpha: 0.2),
    textColor: const Color(0xFFFBEFFF),
    metaColor: const Color(0xFF9E7C9D),
    badgeColor: const Color(0xFF2D123B),
    icon: Icons.lens_blur_rounded,
  );

  static final ConfessionThemeConfig voidBlack = ConfessionThemeConfig(
    id: 'VOID',
    name: 'Void Black',
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF050505), Color(0xFF000000)],
    ),
    borderColor: const Color(0xFF202020),
    accentColor: Colors.white,
    glowColor: Colors.white.withValues(alpha: 0.08),
    textColor: const Color(0xFFFAFAFA),
    metaColor: const Color(0xFF707070),
    badgeColor: const Color(0xFF141414),
    icon: Icons.circle_outlined,
  );

  static List<ConfessionThemeConfig> get allThemes => [
        obsidian,
        crimson,
        midnight,
        cyber,
        charcoal,
        amethyst,
        voidBlack,
      ];

  static ConfessionThemeConfig fromId(String? id) {
    final key = (id ?? '').toUpperCase();
    for (final t in allThemes) {
      if (t.id == key) return t;
    }
    return obsidian;
  }
}
