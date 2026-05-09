import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unify_frontend/main.dart';

void main() {
  testWidgets('Search results page filters society names locally', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SearchResultsPage(
          query: 'Art',
          items: ['Art Society', 'Gaming Society', 'Photography Club'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search: "Art"'), findsOneWidget);
    expect(find.text('Art Society'), findsOneWidget);
    expect(find.text('Gaming Society'), findsNothing);
  });
}
