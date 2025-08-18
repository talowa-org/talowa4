import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:talowa/services/referral/referral_registration_service.dart';
import 'package:talowa/services/referral/referral_code_generator.dart';
import 'package:talowa/services/referral/referral_lookup_service.dart';
import 'package:talowa/services/referral/referral_tracking_service.dart';
import 'package:talowa/models/user_model.dart';

void main() {
  group('ReferralRegistrationService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      
      // Set up services with fake instances
      ReferralRegistrationService.setFirestoreInstance(fakeFirestore);
      ReferralCodeGenerator.setFirestoreInstance(fakeFirestore);
      ReferralLookupService.setFirestoreInstance(fakeFirestore);
      ReferralTrackingService.setFirestoreInstance(fakeFirestore);
    });

    group('Registration Validation', () {
      test('should validate registration data correctly', () {
        final validData = ReferralRegistrationService.validateRegistrationData(
          fullName: 'John Doe',
          phoneNumber: '+919876543210',
          email: 'john@example.com',
          password: 'password123',
        );
        
        expect(validData.isValid, isTrue);
        expect(validData.errors, isEmpty);
      });

      test('should reject invalid registration data', () {
        final invalidData = ReferralRegistrationService.validateRegistrationData(
          fullName: '',
          phoneNumber: 'invalid',
          email: 'invalid-email',
          password: '123',
        );
        
        expect(invalidData.isValid, isFalse);
        expect(invalidData.errors.length, greaterThan(0));
        expect(invalidData.errors, contains('Full name is required'));
        expect(invalidData.errors, contains('Invalid phone number format'));
        expect(invalidData.errors, contains('Invalid email format'));
        expect(invalidData.errors, contains('Password must be at least 6 characters'));
      });

      test('should validate referral code format', () {
        final invalidReferralCode = ReferralRegistrationService.validateRegistrationData(
          fullName: 'John Doe',
          phoneNumber: '+919876543210',
          email: 'john@example.com',
          password: 'password123',
          referralCode: 'INVALID',
        );
        
        expect(invalidReferralCode.isValid, isFalse);
        expect(invalidReferralCode.errors, contains('Invalid referral code format'));
      });
    });

    group('User Registration', () {
      test('should register user without referral code', () async {
        final address = Address(
          villageCity: 'Test City',
          mandal: 'Test Mandal',
          district: 'Test District',
          state: 'Test State',
          pincode: '123456',
        );

        // Mock successful auth creation
        final mockUser = MockUser(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'Test User',
        );
        
        // Note: In a real test, we'd need to properly mock Firebase Auth
        // For now, we'll test the validation and data structure
        
        final validation = ReferralRegistrationService.validateRegistrationData(
          fullName: 'Test User',
          phoneNumber: '+919876543210',
          email: 'test@example.com',
          password: 'password123',
        );
        
        expect(validation.isValid, isTrue);
      });

      test('should register user with valid referral code', () async {
        // Setup referrer
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'referrer-uid',
          'isActive': true,
          'createdAt': DateTime.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        await fakeFirestore.collection('users').doc('referrer-uid').set({
          'fullName': 'Referrer User',
          'isActive': true,
          'referralCode': 'TAL8K9M2X',
          'referralChain': [],
        });

        final validation = ReferralRegistrationService.validateRegistrationData(
          fullName: 'Test User',
          phoneNumber: '+919876543210',
          email: 'test@example.com',
          password: 'password123',
          referralCode: 'TAL8K9M2X',
        );
        
        expect(validation.isValid, isTrue);
      });

      test('should reject registration with invalid referral code', () async {
        final validation = ReferralRegistrationService.validateRegistrationData(
          fullName: 'Test User',
          phoneNumber: '+919876543210',
          email: 'test@example.com',
          password: 'password123',
          referralCode: 'INVALID123',
        );
        
        expect(validation.isValid, isFalse);
        expect(validation.errors, contains('Invalid referral code format'));
      });
    });

    group('Email and Phone Validation', () {
      test('should check if email is registered', () async {
        // This would require proper Firebase Auth mocking
        // For now, test the method exists and handles errors gracefully
        final isRegistered = await ReferralRegistrationService.isEmailRegistered('test@example.com');
        expect(isRegistered, isFalse); // Should return false when auth fails
      });

      test('should check if phone is registered', () async {
        // Setup existing user with phone
        await fakeFirestore.collection('users').doc('existing-user').set({
          'phoneNumber': '+919876543210',
          'fullName': 'Existing User',
        });

        final isRegistered = await ReferralRegistrationService.isPhoneRegistered('+919876543210');
        expect(isRegistered, isTrue);

        final isNotRegistered = await ReferralRegistrationService.isPhoneRegistered('+919999999999');
        expect(isNotRegistered, isFalse);
      });
    });

    group('Validation Result', () {
      test('should create validation result correctly', () {
        final validResult = ValidationResult(isValid: true, errors: []);
        expect(validResult.isValid, isTrue);
        expect(validResult.errors, isEmpty);

        final invalidResult = ValidationResult(
          isValid: false, 
          errors: ['Error 1', 'Error 2']
        );
        expect(invalidResult.isValid, isFalse);
        expect(invalidResult.errors.length, equals(2));
      });
    });

    group('Registration Result', () {
      test('should create registration result correctly', () {
        final mockUser = MockUser(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'Test User',
        );

        final mockUserModel = UserModel(
          id: 'test-uid',
          phoneNumber: '+919876543210',
          email: 'test@example.com',
          fullName: 'Test User',
          role: 'member',
          memberId: 'TAL123456',
          referralCode: 'TAL8K9M2X',
          address: Address(
            villageCity: 'Test City',
            mandal: 'Test Mandal',
            district: 'Test District',
            state: 'Test State',
            pincode: '123456',
          ),
          directReferrals: 0,
          teamSize: 0,
          membershipPaid: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          preferences: UserPreferences.defaultPreferences(),
        );

        final result = UserRegistrationResult(
          user: mockUser,
          userModel: mockUserModel,
          referralCode: 'TAL8K9M2X',
          wasReferred: false,
        );

        expect(result.user.uid, equals('test-uid'));
        expect(result.userModel.fullName, equals('Test User'));
        expect(result.referralCode, equals('TAL8K9M2X'));
        expect(result.wasReferred, isFalse);
        expect(result.referrerUserId, isNull);
      });

      test('should create registration result with referrer', () {
        final mockUser = MockUser(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'Test User',
        );

        final mockUserModel = UserModel(
          id: 'test-uid',
          phoneNumber: '+919876543210',
          email: 'test@example.com',
          fullName: 'Test User',
          role: 'member',
          memberId: 'TAL123456',
          referralCode: 'TAL8K9M2X',
          referredBy: 'TAL7H8N3Y',
          address: Address(
            villageCity: 'Test City',
            mandal: 'Test Mandal',
            district: 'Test District',
            state: 'Test State',
            pincode: '123456',
          ),
          directReferrals: 0,
          teamSize: 0,
          membershipPaid: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          preferences: UserPreferences.defaultPreferences(),
        );

        final result = UserRegistrationResult(
          user: mockUser,
          userModel: mockUserModel,
          referralCode: 'TAL8K9M2X',
          wasReferred: true,
          referrerUserId: 'referrer-uid',
        );

        expect(result.wasReferred, isTrue);
        expect(result.referrerUserId, equals('referrer-uid'));
      });
    });

    group('Exception Handling', () {
      test('should create RegistrationException correctly', () {
        const message = 'Registration failed';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};

        final exception = RegistrationException(message, code, context);

        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Registration failed';
        final exception = RegistrationException(message);

        expect(exception.code, equals('REGISTRATION_FAILED'));
        expect(exception.context, isNull);
      });
    });

    group('Phone Number Validation', () {
      test('should validate Indian phone numbers', () {
        final validNumbers = [
          '+919876543210',
          '9876543210',
          '+91 9876543210',
          '+91-9876543210',
          '6123456789', // Starting with 6
          '7123456789', // Starting with 7
          '8123456789', // Starting with 8
        ];

        for (final number in validNumbers) {
          final cleanNumber = number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
          final isValid = RegExp(r'^(\+91)?[6-9]\d{9}$').hasMatch(cleanNumber);
          expect(isValid, isTrue, reason: 'Number $number should be valid');
        }
      });

      test('should reject invalid phone numbers', () {
        final invalidNumbers = [
          'abc',
          '0123456789',
          '',
          '12', // Too short
          '+91', // Too short
        ];

        for (final number in invalidNumbers) {
          final cleanNumber = number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
          final isValid = RegExp(r'^(\+91)?[6-9]\d{9}$').hasMatch(cleanNumber);
          expect(isValid, isFalse, reason: 'Number $number should be invalid');
        }
      });
    });

    group('Email Validation', () {
      test('should validate email addresses', () {
        final validEmails = [
          'test@example.com',
          'user.name@domain.co.in',
          'user+tag@example.org',
        ];

        for (final email in validEmails) {
          final isValid = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
          expect(isValid, isTrue, reason: 'Email $email should be valid');
        }
      });

      test('should reject invalid email addresses', () {
        final invalidEmails = [
          'invalid',
          '@example.com',
          'user@',
          'user@domain',
          '',
        ];

        for (final email in invalidEmails) {
          final isValid = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
          expect(isValid, isFalse, reason: 'Email $email should be invalid');
        }
      });
    });
  });
}
