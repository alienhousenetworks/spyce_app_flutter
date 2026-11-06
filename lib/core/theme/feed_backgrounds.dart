/// Maps profile theme / bg_id fields to local SVG assets for feed cards.
///
/// Assets live in `assets/backgrounds/`.
///
/// ## Shipped Scout / Feed Background Catalog (8 Families · 24 SVG Variants)
///
/// | Code | Idea              | Variants & Shipped SVG Files                           |
/// |------|-------------------|--------------------------------------------------------|
/// | B01  | Flame Wave        | Warm, Cool, Spyce (3 SVGs)                             |
/// | B02  | Puzzle Splash     | Warm, Cool, Spyce (3 SVGs)                             |
/// | B03  | Froth Splash      | Warm, Cool, Spyce (3 SVGs)                             |
/// | B04  | Tri Splash        | Warm, Cool, Spyce (3 SVGs)                             |
/// | B05  | Star Splash       | Warm, Cool, Spyce (3 SVGs)                             |
/// | B06  | Uneven Splash     | Warm, Cool, Spyce (3 SVGs)                             |
/// | B07  | Premium Uneven    | Warm, Cool, Spyce (3 SVGs)                             |
/// | B08  | Web Splash        | Warm, Cool, Spyce (3 SVGs)                             |
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
    'flamecool': '$_base/FlameCool.svg',
    'flamespyce': '$_base/FlameSpyce.svg',

    // ── Puzzle family (B02) ────────────────────────────────────────
    'puzzle': '$_base/PuzzleSplashWarm.svg',
    'puzzlesplash': '$_base/PuzzleSplashWarm.svg',
    'puzzlesplashwarm': '$_base/PuzzleSplashWarm.svg',
    'puzzlesplashcool': '$_base/PuzzleSplashCool.svg',
    'puzzlesplashspyce': '$_base/PuzzleSplashSpyce.svg',

    // ── Froth family (B03) ─────────────────────────────────────────
    'froth': '$_base/FrothWarm.svg',
    'frothwarm': '$_base/FrothWarm.svg',
    'frothcool': '$_base/FrothCool.svg',
    'frothspyce': '$_base/FrothSpyce.svg',

    // ── Tri family (B04) ───────────────────────────────────────────
    'tri': '$_base/TriSplashWarm.svg',
    'trisplash': '$_base/TriSplashWarm.svg',
    'trisplashwarm': '$_base/TriSplashWarm.svg',
    'trisplashcool': '$_base/TriSplashCool.svg',
    'trisplashspyce': '$_base/TriSplashSpyce.svg',

    // ── Star family (B05) ──────────────────────────────────────────
    'star': '$_base/StarSplashWarm.svg',
    'starsplash': '$_base/StarSplashWarm.svg',
    'starsplashwarm': '$_base/StarSplashWarm.svg',
    'starsplashcool': '$_base/StarSplashCool.svg',
    'starsplashspyce': '$_base/StarSplashSpyce.svg',

    // ── Uneven family (B06) ────────────────────────────────────────
    'uneven': '$_base/UnevenWarm.svg',
    'unevenwarm': '$_base/UnevenWarm.svg',
    'unevencool': '$_base/UnevenCool.svg',
    'unevenspyce': '$_base/UnevenSpyce.svg',

    // ── Premium Uneven family (B07) ────────────────────────────────
    'premiumuneven': '$_base/PremiumUnevenWarm.svg',
    'premiumunevenwarm': '$_base/PremiumUnevenWarm.svg',
    'premiumunevencool': '$_base/PremiumUnevenCool.svg',
    'premiumunevenspyce': '$_base/PremiumUnevenSpyce.svg',

    // ── Web family (B08) ───────────────────────────────────────────
    'web': '$_base/WebWarm.svg',
    'websplash': '$_base/WebWarm.svg',
    'webwarm': '$_base/WebWarm.svg',
    'webcool': '$_base/WebCool.svg',
    'webspyce': '$_base/WebSpyce.svg',

    // ── Stable API bg_id (family → default SVG) ────────────────────
    'b01': '$_base/FlameWarm.svg',
    'b02': '$_base/PuzzleSplashWarm.svg',
    'b03': '$_base/FrothWarm.svg',
    'b04': '$_base/TriSplashWarm.svg',
    'b05': '$_base/StarSplashWarm.svg',
    'b06': '$_base/UnevenWarm.svg',
    'b07': '$_base/PremiumUnevenWarm.svg',
    'b08': '$_base/WebWarm.svg',

    // ── Shipped Variant codes (B0x-variant) ─────────────────────────
    // B01 Flame Wave
    'b01warm': '$_base/FlameWarm.svg',
    'b01cool': '$_base/FlameCool.svg',
    'b01spyce': '$_base/FlameSpyce.svg',
    // B02 Puzzle Splash
    'b02warm': '$_base/PuzzleSplashWarm.svg',
    'b02cool': '$_base/PuzzleSplashCool.svg',
    'b02spyce': '$_base/PuzzleSplashSpyce.svg',
    // B03 Froth Splash
    'b03warm': '$_base/FrothWarm.svg',
    'b03cool': '$_base/FrothCool.svg',
    'b03spyce': '$_base/FrothSpyce.svg',
    // B04 Tri Splash
    'b04warm': '$_base/TriSplashWarm.svg',
    'b04cool': '$_base/TriSplashCool.svg',
    'b04spyce': '$_base/TriSplashSpyce.svg',
    // B05 Star Splash
    'b05warm': '$_base/StarSplashWarm.svg',
    'b05cool': '$_base/StarSplashCool.svg',
    'b05spyce': '$_base/StarSplashSpyce.svg',
    // B06 Uneven Splash
    'b06warm': '$_base/UnevenWarm.svg',
    'b06cool': '$_base/UnevenCool.svg',
    'b06spyce': '$_base/UnevenSpyce.svg',
    // B07 Premium Uneven
    'b07warm': '$_base/PremiumUnevenWarm.svg',
    'b07cool': '$_base/PremiumUnevenCool.svg',
    'b07spyce': '$_base/PremiumUnevenSpyce.svg',
    // B08 Web Splash
    'b08warm': '$_base/WebWarm.svg',
    'b08cool': '$_base/WebCool.svg',
    'b08spyce': '$_base/WebSpyce.svg',

    // ── Legacy Aliases ─────────────────────────────────────────────
    'darkflame1': '$_base/FlameCool.svg',
    'darkflame2': '$_base/FlameSpyce.svg',
    'b01dark1': '$_base/FlameCool.svg',
    'b01dark2': '$_base/FlameSpyce.svg',
    'hex': '$_base/FrothWarm.svg',
    'hexsplashwarm': '$_base/FrothWarm.svg',
    'square': '$_base/UnevenWarm.svg',
    'squaresplashwarm': '$_base/UnevenWarm.svg',
    'spyder': '$_base/WebWarm.svg',
    'spyderwarm': '$_base/WebWarm.svg',
    'b12': '$_base/WebWarm.svg',
    'b12warm': '$_base/WebWarm.svg',
    'topo': '$_base/PremiumUnevenWarm.svg',
    'topolavender': '$_base/PremiumUnevenCool.svg',
    'topoorange': '$_base/PremiumUnevenWarm.svg',
    'b13': '$_base/PremiumUnevenWarm.svg',
    'b13lavender': '$_base/PremiumUnevenCool.svg',
    'b13warm': '$_base/PremiumUnevenWarm.svg',
    'b13orange': '$_base/PremiumUnevenWarm.svg',
    'b13lavenderdark': '$_base/PremiumUnevenSpyce.svg',
    'b13lavenderlight': '$_base/PremiumUnevenCool.svg',
    'b13cool': '$_base/PremiumUnevenCool.svg',
  };

  /// All shipped SVG assets (picker order: 8 families × 3 variants).
  static const List<String> allAssets = [
    // B01 Flame Wave
    '$_base/FlameWarm.svg',
    '$_base/FlameCool.svg',
    '$_base/FlameSpyce.svg',
    // B02 Puzzle Splash
    '$_base/PuzzleSplashWarm.svg',
    '$_base/PuzzleSplashCool.svg',
    '$_base/PuzzleSplashSpyce.svg',
    // B03 Froth Splash
    '$_base/FrothWarm.svg',
    '$_base/FrothCool.svg',
    '$_base/FrothSpyce.svg',
    // B04 Tri Splash
    '$_base/TriSplashWarm.svg',
    '$_base/TriSplashCool.svg',
    '$_base/TriSplashSpyce.svg',
    // B05 Star Splash
    '$_base/StarSplashWarm.svg',
    '$_base/StarSplashCool.svg',
    '$_base/StarSplashSpyce.svg',
    // B06 Uneven Splash
    '$_base/UnevenWarm.svg',
    '$_base/UnevenCool.svg',
    '$_base/UnevenSpyce.svg',
    // B07 Premium Uneven
    '$_base/PremiumUnevenWarm.svg',
    '$_base/PremiumUnevenCool.svg',
    '$_base/PremiumUnevenSpyce.svg',
    // B08 Web Splash
    '$_base/WebWarm.svg',
    '$_base/WebCool.svg',
    '$_base/WebSpyce.svg',
  ];

  /// Human-readable idea labels for pickers / debug.
  static const Map<String, String> ideaNames = {
    'B01': 'Flame Wave',
    'B02': 'Puzzle Splash',
    'B03': 'Froth Splash',
    'B04': 'Tri Splash',
    'B05': 'Star Splash',
    'B06': 'Uneven Splash',
    'B07': 'Premium Uneven',
    'B08': 'Web Splash',
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
