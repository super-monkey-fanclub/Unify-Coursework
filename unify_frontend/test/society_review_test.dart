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

    expect(find.text('Members'), findsWidgets);
    expect(find.text('82'), findsWidgets);
    expect(find.text('Average rating'), findsOneWidget);
    expect(find.text('4.6'), findsWidgets);
  });

  testWidgets('Joined user sees leave action and review controls', (
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

    expect(find.text('Leave society'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Sort'), findsWidgets);
    expect(find.text('Min'), findsWidgets);
  });
}
