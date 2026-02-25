import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unify_frontend/main.dart';

void main() {
  testWidgets('Auth page opens from Join button and appbar icon', (WidgetTester tester) async {
    await tester.pumpWidget(const UnifyApp());
    await tester.pumpAndSettle();

    // Open via Join button
    final joinBtn = find.text('Join a society today');
    expect(joinBtn, findsOneWidget);
    await tester.tap(joinBtn);
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
