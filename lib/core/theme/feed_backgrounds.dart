/// Maps profile theme / bg_id fields to local SVG assets for feed cards.
///
/// Assets live in `assets/backgrounds/` (copied from SpyceBgs/SVGs).
///
/// ## Background idea catalog (API codes B01–B12)
///
/// | Code | Idea              | SVG family                          |
/// |------|-------------------|-------------------------------------|
/// | B01  | Flame Wave        | FlameSpyce / Cool / Warm / Dark*    |
/// | B02  | Puzzle Splash     | PuzzleSplash*                       |
/// | B03  | Hexagon Splash    | HexSplash*                          |
/// | B04  | Tri Splash        | TriSplash*                          |
/// | B05  | Star Splash       | StarSplash*                         |
/// | B06  | Square Splash     | SquareSplash*                       |
/// | B07  | Advance Flame     | FlameWarm / DarkFlame (curated)     |
/// | B08  | Flame Splash      | Flame* (extended)                   |
/// | B09  | Bi Splash         | falls back to Tri / Hex             |
/// | B10  | Simple Flame Grid | Flame*                              |
/// | B11  | Octagon Splash    | Hex / Square fallback               |
/// | B12  | Spyder Splash     | SpyderSpyce / Cool / Warm           |
///
/// Palette variants use suffixes: `-spyce`, `-cool`, `-warm` (and named colors).
abstract final class FeedBackgrounds {
  static const _base = 'assets/backgrounds';

  /// Canonical splash / pattern SVGs shipped with the app.
  static const Map<String, String> byId = {
    // ── Flame family ─────────────────────────────────────────────
    'flame': '$_base/FlameSpyce.svg',
    'flamespyce': '$_base/FlameSpyce.svg',
    'flamecool': '$_base/FlameCool.svg',
    'flamewarm': '$_base/FlameWarm.svg',
    'darkflame1': '$_base/DarkFlame1.svg',
    'darkflame2': '$_base/DarkFlame2.svg',
    // ── Splash families ──────────────────────────────────────────
    'hex': '$_base/HexSplashSpyce.svg',
    'hexsplashspyce': '$_base/HexSplashSpyce.svg',
    'hexsplashcool': '$_base/HexSplashCool.svg',
    'hexsplashwarm': '$_base/HexSplashWarm.svg',
    'puzzle': '$_base/PuzzleSplashSpyce.svg',
    'puzzlesplashspyce': '$_base/PuzzleSplashSpyce.svg',
    'puzzlesplashcool': '$_base/PuzzleSplashCool.svg',
    'puzzlesplashwarm': '$_base/PuzzleSplashWarm.svg',
    'square': '$_base/SquareSplashSpyce.svg',
    'squaresplashspyce': '$_base/SquareSplashSpyce.svg',
    'squaresplashcool': '$_base/SquareSplashCool.svg',
    'squaresplashwarm': '$_base/SquareSplashWarm.svg',
    'star': '$_base/StarSplashSpyce.svg',
    'starsplashspyce': '$_base/StarSplashSpyce.svg',
    'starsplashcool': '$_base/StarSplashCool.svg',
    'starsplashwarm': '$_base/StarSplashWarm.svg',
    'tri': '$_base/TriSplashSpyce.svg',
    'trisplashspyce': '$_base/TriSplashSpyce.svg',
    'trisplashcool': '$_base/TriSplashCool.svg',
    'trisplashwarm': '$_base/TriSplashWarm.svg',
    // ── Spyder family (B12) ──────────────────────────────────────
    'spyder': '$_base/SpyderSpyce.svg',
    'spyderspyce': '$_base/SpyderSpyce.svg',
    'spydercool': '$_base/SpyderCool.svg',
    'spyderwarm': '$_base/SpyderWarm.svg',

    // ── Stable API bg_id (family → default SVG) ──────────────────
    'b01': '$_base/FlameSpyce.svg',
    'b02': '$_base/PuzzleSplashSpyce.svg',
    'b03': '$_base/HexSplashSpyce.svg',
    'b04': '$_base/TriSplashSpyce.svg',
    'b05': '$_base/StarSplashSpyce.svg',
    'b06': '$_base/SquareSplashSpyce.svg',
    'b07': '$_base/FlameWarm.svg',
    'b08': '$_base/FlameSpyce.svg',
    'b09': '$_base/TriSplashCool.svg',
    'b10': '$_base/FlameCool.svg',
    'b11': '$_base/HexSplashWarm.svg',
    'b12': '$_base/SpyderSpyce.svg',

    // ── Variant codes (B0x-palette) ──────────────────────────────
    // B01 Flame Wave
    'b01spyce': '$_base/FlameSpyce.svg',
    'b01cool': '$_base/FlameCool.svg',
    'b01warm': '$_base/FlameWarm.svg',
    'b01dark1': '$_base/DarkFlame1.svg',
    'b01dark2': '$_base/DarkFlame2.svg',
    'b01sunset': '$_base/FlameWarm.svg',
    'b01ocean': '$_base/FlameCool.svg',
    'b01midnight': '$_base/DarkFlame1.svg',
    'b01coral': '$_base/FlameWarm.svg',
    // B02 Puzzle
    'b02spyce': '$_base/PuzzleSplashSpyce.svg',
    'b02cool': '$_base/PuzzleSplashCool.svg',
    'b02warm': '$_base/PuzzleSplashWarm.svg',
    'b02pink': '$_base/PuzzleSplashWarm.svg',
    'b02teal': '$_base/PuzzleSplashCool.svg',
    'b02violet': '$_base/PuzzleSplashSpyce.svg',
    // B03 Hex
    'b03spyce': '$_base/HexSplashSpyce.svg',
    'b03cool': '$_base/HexSplashCool.svg',
    'b03warm': '$_base/HexSplashWarm.svg',
    'b03gold': '$_base/HexSplashWarm.svg',
    'b03coral': '$_base/HexSplashWarm.svg',
    'b03ice': '$_base/HexSplashCool.svg',
    // B04 Tri
    'b04spyce': '$_base/TriSplashSpyce.svg',
    'b04cool': '$_base/TriSplashCool.svg',
    'b04warm': '$_base/TriSplashWarm.svg',
    'b04emerald': '$_base/TriSplashSpyce.svg',
    'b04rose': '$_base/TriSplashWarm.svg',
    // B05 Star
    'b05spyce': '$_base/StarSplashSpyce.svg',
    'b05cool': '$_base/StarSplashCool.svg',
    'b05warm': '$_base/StarSplashWarm.svg',
    'b05slate': '$_base/StarSplashCool.svg',
    'b05amber': '$_base/StarSplashWarm.svg',
    // B06 Square
    'b06spyce': '$_base/SquareSplashSpyce.svg',
    'b06cool': '$_base/SquareSplashCool.svg',
    'b06warm': '$_base/SquareSplashWarm.svg',
    'b06cyan': '$_base/SquareSplashCool.svg',
    'b06magenta': '$_base/SquareSplashSpyce.svg',
    'b06lime': '$_base/SquareSplashSpyce.svg',
    // B07 Advance Flame
    'b07warm': '$_base/FlameWarm.svg',
    'b07spyce': '$_base/FlameSpyce.svg',
    'b07cool': '$_base/FlameCool.svg',
    'b07peach': '$_base/FlameWarm.svg',
    'b07lavender': '$_base/FlameCool.svg',
    'b07mint': '$_base/FlameSpyce.svg',
    // B08–B11 extended
    'b08spyce': '$_base/FlameSpyce.svg',
    'b08cool': '$_base/FlameCool.svg',
    'b08warm': '$_base/FlameWarm.svg',
    'b09emerald': '$_base/TriSplashSpyce.svg',
    'b09rose': '$_base/TriSplashWarm.svg',
    'b10spyce': '$_base/FlameSpyce.svg',
    'b10cool': '$_base/FlameCool.svg',
    'b10warm': '$_base/FlameWarm.svg',
    'b11peach': '$_base/HexSplashWarm.svg',
    'b11lavender': '$_base/HexSplashCool.svg',
    'b11mint': '$_base/HexSplashSpyce.svg',
    // B12 Spyder Splash (3 SVGs only)
    'b12spyce': '$_base/SpyderSpyce.svg',
    'b12cool': '$_base/SpyderCool.svg',
    'b12warm': '$_base/SpyderWarm.svg',
  };

  /// All shipped SVG assets (picker order).
  static const List<String> allAssets = [
    '$_base/DarkFlame1.svg',
    '$_base/DarkFlame2.svg',
    '$_base/FlameCool.svg',
    '$_base/FlameSpyce.svg',
    '$_base/FlameWarm.svg',
    '$_base/HexSplashCool.svg',
    '$_base/HexSplashSpyce.svg',
    '$_base/HexSplashWarm.svg',
    '$_base/PuzzleSplashCool.svg',
    '$_base/PuzzleSplashSpyce.svg',
    '$_base/PuzzleSplashWarm.svg',
    '$_base/SquareSplashCool.svg',
    '$_base/SquareSplashSpyce.svg',
    '$_base/SquareSplashWarm.svg',
    '$_base/StarSplashCool.svg',
    '$_base/StarSplashSpyce.svg',
    '$_base/StarSplashWarm.svg',
    '$_base/TriSplashCool.svg',
    '$_base/TriSplashSpyce.svg',
    '$_base/TriSplashWarm.svg',
    '$_base/SpyderCool.svg',
    '$_base/SpyderSpyce.svg',
    '$_base/SpyderWarm.svg',
  ];

  /// Human-readable idea labels for pickers / debug.
  static const Map<String, String> ideaNames = {
    'B01': 'Flame Wave',
    'B02': 'Puzzle Splash',
    'B03': 'Hexagon Splash',
    'B04': 'Tri Splash',
    'B05': 'Star Splash',
    'B06': 'Square Splash',
    'B07': 'Advance Flame',
    'B08': 'Flame Splash',
    'B09': 'Bi Splash',
    'B10': 'Simple Flame Grid',
    'B11': 'Octagon Splash',
    'B12': 'Spyder Splash',
  };

  /// Resolve SVG path for a feed profile theme.
  static String resolve({
    String? bgId,
    String? bgVariantId,
    String? layoutId,
    int? seed,
  }) {
    final keys = <String>[
      if (bgVariantId != null) bgVariantId,
      if (bgId != null) bgId,
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
