import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:spyce/core/theme/feed_backgrounds.dart';

void main() {
  test('All FeedBackgrounds assets exist on disk', () {
    expect(FeedBackgrounds.allAssets.length, 24);

    for (final asset in FeedBackgrounds.allAssets) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: 'Missing SVG: $asset');
    }

    for (final entry in FeedBackgrounds.byId.entries) {
      final file = File(entry.value);
      expect(file.existsSync(), isTrue, reason: 'Missing SVG for ${entry.key}: ${entry.value}');
    }
  });

  test('FeedBackgrounds resolves correctly for known IDs and fallback', () {
    expect(
      FeedBackgrounds.resolve(bgId: 'B01', bgVariantId: 'B01-warm'),
      'assets/backgrounds/FlameWarm.svg',
    );
    expect(
      FeedBackgrounds.resolve(bgId: 'B03', bgVariantId: 'B03-cool'),
      'assets/backgrounds/FrothCool.svg',
    );
    expect(
      FeedBackgrounds.resolve(bgId: 'B07', bgVariantId: 'B07-spyce'),
      'assets/backgrounds/PremiumUnevenSpyce.svg',
    );
    expect(
      FeedBackgrounds.resolve(bgId: 'unknown', bgVariantId: 'unknown'),
      isNotNull,
    );
  });
}
