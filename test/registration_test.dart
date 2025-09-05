import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:talowa/screens/auth/real_user_registration_screen.dart';

// Mock Firebase for testing
class MockFirebaseApp extends Fake implements FirebaseApp {
  @override
  String get name => 'test';
}

void main() {
  group('Registration Screen Tests', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;

    setUp(() async {
      // Initialize mock Firebase
      mockAuth = MockFirebaseAuth();
      mockFirestore = FakeFirebaseFirestore();
    });

    testWidgets('Registration screen loads without errors', (
      WidgetTester tester,
    ) async {
      // Build the registration screen
      await tester.pumpWidget(
        const MaterialApp(home: RealUserRegistrationScreen()),
      );

      // Verify the screen loads
      expect(find.text('Register'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('Form validation works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RealUserRegistrationScreen()),
      );

      // Try to submit empty form
      final submitButton = find.text('Register');
      await tester.tap(submitButton);
      await tester.pump();

      // Should show validation errors
      expect(
        find.text('Please fill in all required fields correctly'),
        findsOneWidget,
      );
    });

    testWidgets('Phone number validation works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RealUserRegistrationScreen()),
      );

      // Enter invalid phone number
      final phoneField = find.byKey(const Key('phone_field'));
      await tester.enterText(phoneField, '123');

      final submitButton = find.text('Register');
      await tester.tap(submitButton);
      await tester.pump();

      // Should show phone validation error
      expect(find.textContaining('phone'), findsOneWidget);
    });

    testWidgets('PIN validation works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RealUserRegistrationScreen()),
      );

      // Enter valid phone but invalid PIN
      final phoneField = find.byKey(const Key('phone_field'));
      await tester.enterText(phoneField, '9876543210');

      final pinField = find.byKey(const Key('pin_field'));
      await tester.enterText(pinField, '12');

      final submitButton = find.text('Register');
      await tester.tap(submitButton);
      await tester.pump();

      // Should show PIN validation error
      expect(find.textContaining('PIN'), findsOneWidget);
    });

    testWidgets('Address fields are required', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RealUserRegistrationScreen()),
      );

      // Fill only phone and PIN
      final phoneField = find.byKey(const Key('phone_field'));
      await tester.enterText(phoneField, '9876543210');

      final pinField = find.byKey(const Key('pin_field'));
      await tester.enterText(pinField, '1234');

      final nameField = find.byKey(const Key('name_field'));
      await tester.enterText(nameField, 'Test User');

      final submitButton = find.text('Register');
      await tester.tap(submitButton);
      await tester.pump();

      // Should show address validation error
      expect(find.text('Please fill in all required fields'), findsOneWidget);
    });

    testWidgets('Terms acceptance is required', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RealUserRegistrationScreen()),
      );

      // Fill all fields but don't accept terms
      await _fillAllRequiredFields(tester);

      final submitButton = find.text('Register');
      await tester.tap(submitButton);
      await tester.pump();

      // Should show terms acceptance error
      expect(
        find.text('Please accept the terms and conditions'),
        findsOneWidget,
      );
    });
  });
}

// Helper function to fill all required fields
Future<void> _fillAllRequiredFields(WidgetTester tester) async {
  final phoneField = find.byKey(const Key('phone_field'));
  await tester.enterText(phoneField, '9876543210');

  final pinField = find.byKey(const Key('pin_field'));
  await tester.enterText(pinField, '1234');

  final confirmPinField = find.byKey(const Key('confirm_pin_field'));
  await tester.enterText(confirmPinField, '1234');

  final nameField = find.byKey(const Key('name_field'));
  await tester.enterText(nameField, 'Test User');

  final villageField = find.byKey(const Key('village_field'));
  await tester.enterText(villageField, 'Test Village');

  final mandalField = find.byKey(const Key('mandal_field'));
  await tester.enterText(mandalField, 'Test Mandal');

  final districtField = find.byKey(const Key('district_field'));
  await tester.enterText(districtField, 'Test District');
}

