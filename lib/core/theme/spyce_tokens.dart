import 'package:flutter/material.dart';

import 'spyce_colors.dart';

/// Layout tokens — use these instead of one-off radii / gaps.
abstract final class SpyceSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const page = EdgeInsets.fromLTRB(16, 8, 16, 24);
  static const pageWide = EdgeInsets.fromLTRB(20, 12, 20, 32);
}

abstract final class SpyceRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 28.0;
  static const pill = 999.0;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get sheet =>
      const BorderRadius.vertical(top: Radius.circular(xl));
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

abstract final class SpyceShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get flame => [
        BoxShadow(
          color: SpyceColors.flame.withValues(alpha: 0.28),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get nav => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ];
}

abstract final class SpyceDecor {
  static BoxDecoration surface({
    Color? color,
    double radius = SpyceRadius.lg,
    bool glow = false,
  }) {
    return BoxDecoration(
      color: color ?? SpyceColors.dark800,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      boxShadow: glow ? SpyceShadows.flame : SpyceShadows.card,
    );
  }

  static BoxDecoration iconWell(Color accent) {
    return BoxDecoration(
      color: accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
    );
  }
}
