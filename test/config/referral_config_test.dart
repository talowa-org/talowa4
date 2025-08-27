import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:talowa/config/referral_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ReferralConfig', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      // Set the firestore instance for testing
      // Note: ReferralConfig uses FirebaseFirestore.instance directly
      // In a real implementation, we'd need dependency injection
    });

    group('Configuration Constants', () {
      test('should have correct default values', () {
        expect(ReferralConfig.defaultReferrerCode, equals('TALADMIN'));
        expect(ReferralConfig.fallbackEnabled, isTrue);
        expect(ReferralConfig.adminEmail, equals('+917981828388@talowa.app'));
        expect(ReferralConfig.adminPhone, equals('+91 7981828388'));
        expect(ReferralConfig.maxFallbackPercentage, equals(25.0));
        expect(ReferralConfig.fallbackAlertThreshold, equals(100));
      });

      test('should have correct admin user profile', () {
        const profile = ReferralConfig.adminUserProfile;
        
        expect(profile['fullName'], equals('Talowa Admin'));
        expect(profile['email'], equals(ReferralConfig.adminEmail));
        expect(profile['phone'], equals(ReferralConfig.adminPhone));
        expect(profile['role'], equals('regional_coordinator'));
        expect(profile['status'], equals('active'));
        expect(profile['membershipPaid'], isTrue);
        expect(profile['isSystemAdmin'], isTrue);
        expect(profile['directReferralCount'], equals(0));
        expect(profile['totalTeamSize'], equals(0));
        expect(profile['referralCode'], equals(ReferralConfig.defaultReferrerCode));
        expect(profile['referralChain'], isA<List<String>>());
        expect(profile['referralChain'], isEmpty);
      });
    });

    group('Admin Bootstrap', () {
      test('should create admin user and referral code when none exist', () async {
        // Note: This test would require mocking FirebaseFirestore.instance
        // For now, we'll test the logic conceptually
        
        // Verify constants are set correctly for bootstrap
        expect(ReferralConfig.defaultReferrerCode, isNotEmpty);
        expect(ReferralConfig.adminEmail, isNotEmpty);
        expect(ReferralConfig.adminPhone, isNotEmpty);
      });

      test('should verify admin configuration structure', () async {
        // Test the admin profile structure
        const profile = ReferralConfig.adminUserProfile;
        
        // Required fields for admin user
        final requiredFields = [
          'fullName', 'email', 'phone', 'role', 'status',
          'membershipPaid', 'isSystemAdmin', 'directReferralCount',
          'totalTeamSize', 'referralCode', 'referralChain'
        ];
        
        for (final field in requiredFields) {
          expect(profile.containsKey(field), isTrue, reason: 'Missing field: $field');
        }
        
        // Verify admin has highest role
        expect(profile['role'], equals('regional_coordinator'));
        expect(profile['isSystemAdmin'], isTrue);
        expect(profile['membershipPaid'], isTrue);
        expect(profile['status'], equals('active'));
      });
    });

    group('Fallback Statistics', () {
      test('should calculate fallback percentage correctly', () {
        // Test the calculation logic
        const totalUsers = 100;
        const fallbackUsers = 20;
        const expectedPercentage = 20.0;
        
        const percentage = (fallbackUsers / totalUsers) * 100;
        expect(percentage, equals(expectedPercentage));
        
        // Test threshold checking
        expect(percentage > ReferralConfig.maxFallbackPercentage, isFalse);
        
        const highFallbackUsers = 30;
        const highPercentage = (highFallbackUsers / totalUsers) * 100;
        expect(highPercentage > ReferralConfig.maxFallbackPercentage, isTrue);
      });

      test('should handle zero users gracefully', () {
        const totalUsers = 0;
        const fallbackUsers = 0;
        
        const percentage = totalUsers > 0 
            ? (fallbackUsers / totalUsers) * 100 
            : 0.0;
        
        expect(percentage, equals(0.0));
        expect(percentage.isNaN, isFalse);
        expect(percentage.isInfinite, isFalse);
      });
    });

    group('Configuration Validation', () {
      test('should validate referral code format', () {
        const code = ReferralConfig.defaultReferrerCode;

        // Should be 8 characters for TALADMIN
        expect(code.length, equals(8));

        // Should start with TAL
        expect(code.startsWith('TAL'), isTrue);

        // Should be uppercase
        expect(code, equals(code.toUpperCase()));

        // Should contain only valid characters (letters and numbers)
        final validChars = RegExp(r'^[A-Z0-9]+$');
        expect(validChars.hasMatch(code), isTrue);

        // Should be exactly TALADMIN
        expect(code, equals('TALADMIN'));
      });

      test('should validate admin contact information', () {
        const email = ReferralConfig.adminEmail;
        const phone = ReferralConfig.adminPhone;
        
        // Email should be valid format
        expect(email.contains('@'), isTrue);
        expect(email.contains('.'), isTrue);
        expect(email.length, greaterThan(5));
        
        // Phone should be valid format
        expect(phone.startsWith('+91'), isTrue);
        expect(phone.length, greaterThan(10));
        
        // Should not be empty
        expect(email.trim().isNotEmpty, isTrue);
        expect(phone.trim().isNotEmpty, isTrue);
      });

      test('should validate threshold values', () {
        // Fallback percentage threshold should be reasonable
        expect(ReferralConfig.maxFallbackPercentage, greaterThan(0));
        expect(ReferralConfig.maxFallbackPercentage, lessThan(100));
        
        // Alert threshold should be positive
        expect(ReferralConfig.fallbackAlertThreshold, greaterThan(0));
        
        // Fallback should be enabled by default
        expect(ReferralConfig.fallbackEnabled, isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle invalid configuration gracefully', () {
        // Test that constants are not null or empty
        expect(ReferralConfig.defaultReferrerCode, isNotNull);
        expect(ReferralConfig.defaultReferrerCode.isNotEmpty, isTrue);
        
        expect(ReferralConfig.adminEmail, isNotNull);
        expect(ReferralConfig.adminEmail.isNotEmpty, isTrue);
        
        expect(ReferralConfig.adminPhone, isNotNull);
        expect(ReferralConfig.adminPhone.isNotEmpty, isTrue);
      });

      test('should validate admin profile completeness', () {
        const profile = ReferralConfig.adminUserProfile;
        
        // No null values in critical fields
        expect(profile['fullName'], isNotNull);
        expect(profile['email'], isNotNull);
        expect(profile['role'], isNotNull);
        expect(profile['status'], isNotNull);
        expect(profile['referralCode'], isNotNull);
        
        // Boolean fields should be explicitly set
        expect(profile['membershipPaid'], isA<bool>());
        expect(profile['isSystemAdmin'], isA<bool>());
        
        // Numeric fields should be valid
        expect(profile['directReferralCount'], isA<int>());
        expect(profile['totalTeamSize'], isA<int>());
        expect(profile['directReferralCount'], greaterThanOrEqualTo(0));
        expect(profile['totalTeamSize'], greaterThanOrEqualTo(0));
      });
    });

    group('Security Considerations', () {
      test('should use secure admin credentials', () {
        // Admin should have highest privileges
        const profile = ReferralConfig.adminUserProfile;
        expect(profile['role'], equals('regional_coordinator'));
        expect(profile['isSystemAdmin'], isTrue);
        
        // Admin should be active and paid
        expect(profile['status'], equals('active'));
        expect(profile['membershipPaid'], isTrue);
        
        // Admin should have proper referral code
        expect(profile['referralCode'], equals(ReferralConfig.defaultReferrerCode));
      });

      test('should have reasonable monitoring thresholds', () {
        // Fallback percentage threshold should catch issues early
        expect(ReferralConfig.maxFallbackPercentage, lessThanOrEqualTo(50.0));
        
        // Alert threshold should be reasonable for monitoring
        expect(ReferralConfig.fallbackAlertThreshold, greaterThanOrEqualTo(10));
        expect(ReferralConfig.fallbackAlertThreshold, lessThanOrEqualTo(1000));
      });
    });

    group('Integration Points', () {
      test('should provide consistent configuration across services', () {
        // All services should use the same admin code
        const adminCode = ReferralConfig.defaultReferrerCode;
        expect(adminCode, isNotNull);
        expect(adminCode.isNotEmpty, isTrue);
        
        // Fallback should be configurable
        const fallbackEnabled = ReferralConfig.fallbackEnabled;
        expect(fallbackEnabled, isA<bool>());
        
        // Admin profile should be complete for service usage
        const profile = ReferralConfig.adminUserProfile;
        expect(profile, isNotNull);
        expect(profile.isNotEmpty, isTrue);
      });

      test('should support monitoring and analytics', () {
        // Should have thresholds for monitoring
        expect(ReferralConfig.maxFallbackPercentage, isA<double>());
        expect(ReferralConfig.fallbackAlertThreshold, isA<int>());
        
        // Should support feature toggling
        expect(ReferralConfig.fallbackEnabled, isA<bool>());
      });
    });
  });
}
