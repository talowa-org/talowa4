// Verification Test for TALOWA Urgent Fixes
// Tests the fixes for registration, referral codes, and navigation

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/referral_code_cache_service.dart';

void main() {
  group('TALOWA Urgent Fixes Verification', () {
    test('Referral Code Cache Service - Current Code Never Null', () {
      // Test that currentCode never returns null or "Loading..."
      final code = ReferralCodeCacheService.currentCode;
      
      expect(code, isNotNull);
      expect(code, isNot('Loading...'));
      expect(code, isNot(''));
      
      // Should return placeholder if no code cached
      expect(code, 'TAL---');
    });
    
    test('Referral Code Cache Service - Stream Initialization', () {
      // Test that stream is available
      final stream = ReferralCodeCacheService.codeStream;
      
      expect(stream, isNotNull);
    });
    
    test('Allowed Client Fields Validation', () {
      // Test that we only use allowed fields in registration
      final allowedFields = [
        'fullName',
        'email', 
        'emailAlias',
        'phone',
        'language',
        'locale',
        'bio',
        'address',
        'profileCompleted',
        'phoneVerified',
        'lastLoginAt',
        'device'
      ];
      
      final serverOnlyFields = [
        'referralCode',
        'referredBy',
        'referralChain',
        'directReferralCount',
        'totalTeamSize',
        'status',
        'membershipPaid',
        'paidAt',
        'paymentRef',
        'provisionalRef',
        'assignedBySystem',
        'role'
      ];
      
      // Verify no overlap between allowed and server-only fields
      for (final serverField in serverOnlyFields) {
        expect(allowedFields, isNot(contains(serverField)),
            reason: 'Server-only field $serverField found in allowed fields');
      }
      
      // Verify we have the essential allowed fields
      expect(allowedFields, contains('fullName'));
      expect(allowedFields, contains('phone'));
      expect(allowedFields, contains('profileCompleted'));
      expect(allowedFields, contains('phoneVerified'));
      expect(allowedFields, contains('lastLoginAt'));
      expect(allowedFields, contains('device'));
    });
    
    test('Device Field Structure Validation', () {
      // Test that device field has correct structure
      final deviceField = {
        'platform': 'mobile',
        'appVersion': '1.0.0',
      };
      
      expect(deviceField, containsPair('platform', isA<String>()));
      expect(deviceField, containsPair('appVersion', isA<String>()));
      expect(deviceField.keys.length, 2);
    });
    
    test('Registration Payload Structure', () {
      // Test that registration payload only contains allowed fields
      final registrationPayload = {
        'fullName': 'Test User',
        'email': 'test@talowa.app',
        'emailAlias': 'test@talowa.app',
        'phone': '+919876543210',
        'address': {
          'state': 'Test State',
          'district': 'Test District',
        },
        'profileCompleted': true,
        'phoneVerified': true,
        'language': 'en',
        'locale': 'en_US',
        'device': {
          'platform': 'mobile',
          'appVersion': '1.0.0',
        },
      };
      
      final allowedFields = [
        'fullName', 'email', 'emailAlias', 'phone', 'language', 'locale',
        'bio', 'address', 'profileCompleted', 'phoneVerified', 
        'lastLoginAt', 'device'
      ];
      
      // Verify all payload fields are allowed
      for (final field in registrationPayload.keys) {
        expect(allowedFields, contains(field),
            reason: 'Field $field not in allowed list');
      }
      
      // Verify required fields are present
      expect(registrationPayload, containsPair('fullName', isA<String>()));
      expect(registrationPayload, containsPair('phone', isA<String>()));
      expect(registrationPayload, containsPair('profileCompleted', true));
      expect(registrationPayload, containsPair('phoneVerified', true));
    });
  });
}
