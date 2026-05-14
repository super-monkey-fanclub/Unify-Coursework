import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unify_frontend/about_us.dart';
import 'package:unify_frontend/account_settings.dart';
import 'package:unify_frontend/main.dart';
import 'package:unify_frontend/profile.dart';
import 'package:unify_frontend/socieites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home page shows the main navigation actions', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const UnifyApp());
    await tester.pumpAndSettle();

    expect(find.text('Unify'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Find societies'), findsWidgets);
    expect(find.text('Featured this week'), findsOneWidget);
    expect(find.text('Explore popular student groups on campus'), findsOneWidget);
  });

  testWidgets('About page shows mission and feature sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutUsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Our Mission'), findsOneWidget);
    expect(find.text('What We Offer'), findsOneWidget);
    expect(find.text('Browse and search all student societies in one place'), findsOneWidget);
    expect(find.textContaining('University of Portsmouth'), findsWidgets);
  });

  testWidgets('Auth page switches between login and sign-up views', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Password'), findsWidgets);

    await tester.tap(find.text('Not a member? Sign up now'));
    await tester.pumpAndSettle();

    expect(find.text('Sign Up'), findsWidgets);
    expect(find.text('Preferred name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Join the mailing list for updates'), findsOneWidget);
  });

  testWidgets('Auth page validation blocks empty login submission', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Account settings page shows current data and mailing list toggle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsPage(
          currentUser: {
            'email': 'student@port.ac.uk',
            'opt_in_email': true,
            'auth_token': 'token-123',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account settings'), findsOneWidget);
    expect(find.text('student@port.ac.uk'), findsWidgets);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('New password (optional)'), findsOneWidget);
    expect(find.text('Subscribe to mailing list'), findsOneWidget);
    expect(find.text('Save settings'), findsOneWidget);
  });

  testWidgets('Society details page shows stats, join toggle, and review controls', (
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

    expect(find.text('Art Society'), findsWidgets);
    expect(find.text('Members'), findsWidgets);
    expect(find.text('82'), findsWidgets);
    expect(find.text('Average rating'), findsOneWidget);
    expect(find.text('4.6'), findsWidgets);
    expect(find.text('Leave society'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Sort'), findsWidgets);
    expect(find.text('Min'), findsWidgets);
  });

  testWidgets('Search results page filters by query text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SearchResultsPage(
          query: 'Art',
          items: ['Art Society', 'Gaming Society', 'Anime Society'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search: "Art"'), findsOneWidget);
    expect(find.text('Art Society'), findsOneWidget);
    expect(find.text('Gaming Society'), findsNothing);
  });

  testWidgets('Home page still renders on a compact screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const UnifyApp());
    await tester.pumpAndSettle();

    expect(find.text('Unify'), findsOneWidget);
    expect(find.text('Find societies'), findsWidgets);
    expect(find.text('Featured this week'), findsOneWidget);
  });
}
