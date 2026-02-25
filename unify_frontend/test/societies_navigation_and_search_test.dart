import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unify_frontend/main.dart';

void main() {
  testWidgets('Navigate to Societies page and use search dropdown', (WidgetTester tester) async {
    await tester.pumpWidget(const UnifyApp());
    await tester.pumpAndSettle();

    // Navigate to Societies
    final findBtn = find.text('Find societies');
    expect(findBtn, findsOneWidget);
    await tester.tap(findBtn);
    await tester.pumpAndSettle();

    expect(find.text('Societies'), findsOneWidget);

    // Enter a search term and expect suggestions
    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'Art');
    await tester.pumpAndSettle();

    expect(find.text('Art Society'), findsWidgets);

    // Tap the society card (not the dropdown suggestion) to open details
    final artCard = find.ancestor(
      of: find.text('Art Society'),
      matching: find.byType(Card),
    );
    expect(artCard, findsOneWidget);
    await tester.tap(artCard);
    await tester.pumpAndSettle();

    expect(find.text('Join society'), findsOneWidget);
    expect(find.textContaining('A friendly society'), findsOneWidget);
  });
}
