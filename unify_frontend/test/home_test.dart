import 'package:flutter_test/flutter_test.dart';
import 'package:unify_frontend/main.dart';

void main() {
  testWidgets('Home page shows main elements', (WidgetTester tester) async {
    await tester.pumpWidget(const UnifyApp());
    await tester.pumpAndSettle();

    expect(find.text('Unify'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Find societies'), findsOneWidget);
    expect(find.text('Featured this week'), findsOneWidget);
    expect(find.text('Explore popular student groups on campus'), findsOneWidget);
  });
}
