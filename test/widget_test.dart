import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spyce/core/theme/spyce_colors.dart';
import 'package:spyce/shared/widgets/spyce_widgets.dart';
import 'package:flutter/material.dart';

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
    expect(find.byType(SpyceLogo), findsOneWidget);
    expect(find.textContaining('sp'), findsWidgets);
  });
}
