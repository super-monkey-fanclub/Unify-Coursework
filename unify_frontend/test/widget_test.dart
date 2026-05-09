// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unify_frontend/main.dart';

void main() {
  testWidgets('Homepage displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UnifyApp());

    // Verify that the app bar is displayed with correct title.
    expect(find.text('Unify'), findsOneWidget);

    // Verify that the About Us button is present.
    expect(find.text('About Us'), findsOneWidget);

    // Verify that the main call-to-action is present.
    expect(find.text('Find societies'), findsWidgets);

    // Verify the featured section is displayed.
    expect(find.text('Featured this week'), findsOneWidget);
  });
}
