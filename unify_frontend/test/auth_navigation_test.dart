import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unify_frontend/main.dart';

void main() {
  testWidgets('Auth page opens from Sign in button and appbar icon', (WidgetTester tester) async {
    await tester.pumpWidget(const UnifyApp());
    await tester.pumpAndSettle();

    // Open via Sign in button
    final signInBtn = find.text('Sign in');
    expect(signInBtn, findsWidgets);
    await tester.tap(signInBtn.first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Login')),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);

    // Go back and open via appbar icon
    await tester.pageBack();
    await tester.pumpAndSettle();
    final accountIcon = find.byTooltip('Account');
    expect(accountIcon, findsOneWidget);
    await tester.tap(accountIcon);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Login')),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });
}
