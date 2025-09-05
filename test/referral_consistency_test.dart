import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/referral/referral_code_generator.dart';

/// Test suite to validate referral code consistency and format
/// 
/// This test suite:
/// 1. Validates referral code format
/// 2. Tests code generation uniqueness
/// 3. Verifies TAL prefix consistency
/// 4. Checks code validation logic

void main() {
  group('Referral Code Consistency Tests', () {
    
    test('Referral code format validation', () {
      // Test valid codes
      expect(isValidReferralCodeFormat('TAL23456A'), true);
      expect(isValidReferralCodeFormat('TALABCDEF'), true);
      expect(isValidReferralCodeFormat('TAL234567'), true);
      
      // Test invalid codes
      expect(isValidReferralCodeFormat(''), false);
      expect(isValidReferralCodeFormat('ABC123456'), false);
      expect(isValidReferralCodeFormat('TAL'), false);
      expect(isValidReferralCodeFormat('TAL12345'), false); // Too short
      expect(isValidReferralCodeFormat('TAL1234567'), false); // Too long
      expect(isValidReferralCodeFormat('TAL12345O'), false); // Contains O
      expect(isValidReferralCodeFormat('TAL12345I'), false); // Contains I
      expect(isValidReferralCodeFormat('TAL123451'), false); // Contains 1
      expect(isValidReferralCodeFormat('TAL123450'), false); // Contains 0
    });

    test('ReferralCodeGenerator format validation', () {
      // Test the actual generator's validation
      expect(ReferralCodeGenerator.isValidFormat('TAL23456A'), true);
      expect(ReferralCodeGenerator.isValidFormat('TALABCDEF'), true);
      expect(ReferralCodeGenerator.isValidFormat('TAL234567'), true);
      
      // Test invalid formats
      expect(ReferralCodeGenerator.isValidFormat(''), false);
      expect(ReferralCodeGenerator.isValidFormat('ABC123456'), false);
      expect(ReferralCodeGenerator.isValidFormat('TAL'), false);
      expect(ReferralCodeGenerator.isValidFormat('TAL12345'), false);
      expect(ReferralCodeGenerator.isValidFormat('TAL1234567'), false);
    });

    test('Test code generation produces valid format', () {
      // Generate test codes and verify format
      for (int i = 0; i < 10; i++) {
        final code = ReferralCodeGenerator.generateTestCode('test$i');
        expect(code.startsWith('TAL'), true, reason: 'Code should start with TAL: $code');
        expect(code.length, 9, reason: 'Code should be 9 characters: $code');
        expect(ReferralCodeGenerator.isValidFormat(code), true, reason: 'Generated code should be valid: $code');
      }
    });

    test('Test code uniqueness', () {
      final codes = <String>{};
      
      // Generate multiple codes and check uniqueness
      for (int i = 0; i < 100; i++) {
        final code = ReferralCodeGenerator.generateTestCode('unique$i');
        expect(codes.contains(code), false, reason: 'Generated duplicate code: $code');
        codes.add(code);
      }
      
      expect(codes.length, 100, reason: 'Should generate 100 unique codes');
    });

    test('TAL prefix validation', () {
      expect(ReferralCodeGenerator.hasValidTALPrefix('TAL123456'), true);
      expect(ReferralCodeGenerator.hasValidTALPrefix('TALABCDEF'), true);
      expect(ReferralCodeGenerator.hasValidTALPrefix('tal123456'), true); // Case insensitive
      
      expect(ReferralCodeGenerator.hasValidTALPrefix(''), false);
      expect(ReferralCodeGenerator.hasValidTALPrefix('ABC123456'), false);
      expect(ReferralCodeGenerator.hasValidTALPrefix('TA123456'), false);
      expect(ReferralCodeGenerator.hasValidTALPrefix(null), false);
    });

    test('Code normalization', () {
      expect(ReferralCodeGenerator.normalizeReferralCode('tal123456'), 'TAL123456');
      expect(ReferralCodeGenerator.normalizeReferralCode('  TAL123456  '), 'TAL123456');
      expect(ReferralCodeGenerator.normalizeReferralCode('talabcdef'), 'TALABCDEF');
    });

    test('Capacity information', () {
      final info = ReferralCodeGenerator.getCapacityInfo();
      
      expect(info['totalCombinations'], greaterThan(1000000)); // At least 1M combinations
      expect(info['canSupport20Million'], true);
      expect(info['characterSet'], contains('Crockford Base32'));
      expect(info['format'], contains('TAL'));
    });

    test('Collision probability estimation', () {
      expect(ReferralCodeGenerator.estimateCollisionProbability(0), 0.0);
      expect(ReferralCodeGenerator.estimateCollisionProbability(1000), lessThan(0.01)); // Less than 1%
      expect(ReferralCodeGenerator.estimateCollisionProbability(ReferralCodeGenerator.totalPossibleCombinations), 1.0);
    });
  });
}

/// Validate referral code format (helper function for tests)
bool isValidReferralCodeFormat(String code) {
  if (code.isEmpty) return false;
  
  // Must start with TAL
  if (!code.startsWith('TAL')) return false;
  
  // Must be 9 characters total (TAL + 6 chars)
  if (code.length != 9) return false;
  
  // Check that remaining characters are valid Crockford Base32
  const validChars = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  final codeBody = code.substring(3);
  
  for (int i = 0; i < codeBody.length; i++) {
    if (!validChars.contains(codeBody[i])) {
      return false;
    }
  }
  
  return true;
}
