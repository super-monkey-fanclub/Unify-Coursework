import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unify_frontend/socieites.dart';

void main() {
  testWidgets('Society details shows member count and average rating', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SocietyDetailsPage(
          name: 'Art Society',
          description: 'Creative community.',
          imageUrl:
              'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=800&auto=format&fit=crop',
          icon: Icons.palette,
          initialMemberCount: 82,
          initialAverageRating: 4.6,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Members'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Average rating'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
  });

  testWidgets('Joined user can leave society with feedback message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SocietyDetailsPage(
          name: 'Art Society',
          description: 'Creative community.',
          imageUrl:
              'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=800&auto=format&fit=crop',
          icon: Icons.palette,
          userEmail: 'student@port.ac.uk',
          initialJoined: true,
          initialMemberCount: 82,
          initialAverageRating: 4.6,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Leave society'));
    await tester.tap(find.text('Leave society'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Join society'), findsOneWidget);
  });
}
