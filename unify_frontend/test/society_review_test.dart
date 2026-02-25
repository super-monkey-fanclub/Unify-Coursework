import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unify_frontend/main.dart';

void main() {
  testWidgets('Submit a review on a society details page', (WidgetTester tester) async {
    await tester.pumpWidget(const UnifyApp());
    await tester.pumpAndSettle();

    // Navigate to Societies and open a society
    await tester.tap(find.text('Find societies'));
    await tester.pumpAndSettle();
    final artCard = find.ancestor(
      of: find.text('Art Society'),
      matching: find.byType(Card),
    );
    expect(artCard, findsOneWidget);
    await tester.tap(artCard);
    await tester.pumpAndSettle();

    // Fill review name and comment
    final nameField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Name (optional)');
    final commentField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Your review');
    expect(nameField, findsOneWidget);
    expect(commentField, findsOneWidget);

    await tester.enterText(nameField, 'Tester');
    await tester.enterText(commentField, 'This is a test review.');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Submit review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(find.text('This is a test review.'), findsOneWidget);
  });
}
