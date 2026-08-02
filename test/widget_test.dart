import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spyce/core/theme/spyce_colors.dart';
import 'package:spyce/shared/widgets/spyce_widgets.dart';

void main() {
  testWidgets('SPYCE logo renders brand mark', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: SpyceColors.dark950,
            body: Center(child: SpyceLogo(size: 40)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SpyceLogo), findsOneWidget);
    // Wordmark is primarily an Image.asset; fallback text uses "SP"/"Y"/"CE".
    final hasImage = find.byType(Image).evaluate().isNotEmpty;
    final hasBrandText = find.textContaining('SP').evaluate().isNotEmpty ||
        find.textContaining('CE').evaluate().isNotEmpty;
    expect(hasImage || hasBrandText, isTrue);
  });
}
