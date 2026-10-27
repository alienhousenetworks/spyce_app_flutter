/// Maps profile theme / bg_id fields to local SVG assets for feed cards.
///
/// Assets live in `assets/backgrounds/`.
///
/// ## Shipped Scout / Feed Background Catalog (8 Families · 11 SVG Variants)
///
/// | Code | Idea              | Variants & Shipped SVG Files                           |
/// |------|-------------------|--------------------------------------------------------|
/// | B01  | Flame Wave        | Warm, DarkFlame1, DarkFlame2 (3 SVGs)                  |
/// | B02  | Puzzle Splash     | Warm (1 SVG)                                           |
/// | B03  | Hexagon Splash    | Warm (1 SVG)                                           |
/// | B04  | Tri Splash        | Warm (1 SVG)                                           |
/// | B05  | Star Splash       | Warm (1 SVG)                                           |
/// | B06  | Square Splash     | Warm (1 SVG)                                           |
/// | B12  | Spyder Splash     | Warm (1 SVG)                                           |
/// | B13  | Topo Splash       | TopoSplashLavender, TopoSplashOrange (2 SVGs)          |
///
/// Note: `assets/backgrounds/` also includes 2 dedicated onboarding backgrounds:
/// - `OnboardingWelcomeBg.svg` (Welcome / Auth screen)
/// - `OnboardingFlowBg.svg` (Onboarding questionnaire flow)
/// These are used strictly in auth/onboarding, not in Scout / Feed cards.
abstract final class FeedBackgrounds {
  static const _base = 'assets/backgrounds';

  /// Canonical splash / pattern SVGs shipped with the app for Scout / Feed.
  static const Map<String, String> byId = {
    // ── Flame family (B01) ─────────────────────────────────────────
    'flame': '$_base/FlameWarm.svg',
    'flamewarm': '$_base/FlameWarm.svg',
    'darkflame1': '$_base/DarkFlame1.svg',
    'darkflame2': '$_base/DarkFlame2.svg',
    // ── Splash families (B02–B06) ──────────────────────────────────
    'puzzle': '$_base/PuzzleSplashWarm.svg',
    'puzzlesplashwarm': '$_base/PuzzleSplashWarm.svg',
    'hex': '$_base/HexSplashWarm.svg',
    'hexsplashwarm': '$_base/HexSplashWarm.svg',
    'tri': '$_base/TriSplashWarm.svg',
    'trisplashwarm': '$_base/TriSplashWarm.svg',
    'star': '$_base/StarSplashWarm.svg',
    'starsplashwarm': '$_base/StarSplashWarm.svg',
    'square': '$_base/SquareSplashWarm.svg',
    'squaresplashwarm': '$_base/SquareSplashWarm.svg',
    // ── Spyder family (B12) ────────────────────────────────────────
    'spyder': '$_base/SpyderWarm.svg',
    'spyderwarm': '$_base/SpyderWarm.svg',
    // ── Topo family (B13) ──────────────────────────────────────────
    'topo': '$_base/TopoSplashLavender.svg',
    'topolavender': '$_base/TopoSplashLavender.svg',
    'topoorange': '$_base/TopoSplashOrange.svg',

    // ── Stable API bg_id (family → default SVG) ────────────────────
    'b01': '$_base/FlameWarm.svg',
    'b02': '$_base/PuzzleSplashWarm.svg',
    'b03': '$_base/HexSplashWarm.svg',
    'b04': '$_base/TriSplashWarm.svg',
    'b05': '$_base/StarSplashWarm.svg',
    'b06': '$_base/SquareSplashWarm.svg',
    'b12': '$_base/SpyderWarm.svg',
    'b13': '$_base/TopoSplashLavender.svg',

    // ── Shipped Variant codes (B0x-variant) ─────────────────────────
    // B01 Flame Wave
    'b01warm': '$_base/FlameWarm.svg',
    'b01dark1': '$_base/DarkFlame1.svg',
    'b01dark2': '$_base/DarkFlame2.svg',
    // B02 Puzzle
    'b02warm': '$_base/PuzzleSplashWarm.svg',
    // B03 Hex
    'b03warm': '$_base/HexSplashWarm.svg',
    // B04 Tri
    'b04warm': '$_base/TriSplashWarm.svg',
    // B05 Star
    'b05warm': '$_base/StarSplashWarm.svg',
    // B06 Square
    'b06warm': '$_base/SquareSplashWarm.svg',
    // B12 Spyder Splash
    'b12warm': '$_base/SpyderWarm.svg',
    // B13 Topo Splash
    'b13lavender': '$_base/TopoSplashLavender.svg',
    'b13warm': '$_base/TopoSplashOrange.svg',
    'b13orange': '$_base/TopoSplashOrange.svg',
    // Legacy aliases for B13
    'b13lavenderdark': '$_base/TopoSplashLavender.svg',
    'b13lavenderlight': '$_base/TopoSplashLavender.svg',
    'b13cool': '$_base/TopoSplashOrange.svg',
  };

  /// All shipped SVG assets (picker order).
  static const List<String> allAssets = [
    '$_base/DarkFlame1.svg',
    '$_base/DarkFlame2.svg',
    '$_base/FlameWarm.svg',
    '$_base/HexSplashWarm.svg',
    '$_base/PuzzleSplashWarm.svg',
    '$_base/SpyderWarm.svg',
    '$_base/SquareSplashWarm.svg',
    '$_base/StarSplashWarm.svg',
    '$_base/TopoSplashLavender.svg',
    '$_base/TopoSplashOrange.svg',
    '$_base/TriSplashWarm.svg',
  ];

  /// Human-readable idea labels for pickers / debug.
  static const Map<String, String> ideaNames = {
    'B01': 'Flame Wave',
    'B02': 'Puzzle Splash',
    'B03': 'Hexagon Splash',
    'B04': 'Tri Splash',
    'B05': 'Star Splash',
    'B06': 'Square Splash',
    'B12': 'Spyder Splash',
    'B13': 'Topo Splash',
  };

  /// Resolve SVG path for a feed profile theme.
  static String resolve({
    String? bgId,
    String? bgVariantId,
    String? layoutId,
    int? seed,
  }) {
    final keys = <String>[
      ?bgVariantId,
      ?bgId,
      if (bgVariantId != null && bgVariantId.contains('-'))
        bgVariantId.split('-').first,
    ];

    for (final raw in keys) {
      final key = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (byId.containsKey(key)) return byId[key]!;
      // Prefix match e.g. B01coral → b01, B08v125 → b08
      for (final entry in byId.entries) {
        if (key.startsWith(entry.key) || entry.key.startsWith(key)) {
          return entry.value;
        }
      }
    }

    // Deterministic fallback rotation so feed feels varied offline / missing theme
    final list = allAssets;
    final index = (seed ?? 0).abs() % list.length;
    return list[index];
  }
}
