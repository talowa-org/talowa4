// Simple test for referral code policy validation logic
// Tests the core validation logic without Firebase dependencies

import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('Referral Code Policy Tests', () {
    test('Validate TAL prefix requirement', () {
      // Valid codes with TAL prefix
      expect(validateTALPrefix('TALABC234'), isTrue);
      expect(validateTALPrefix('TALXYZ567'), isTrue);
      expect(validateTALPrefix('TALADMIN'), isTrue); // Admin exception
      
      // Invalid codes without TAL prefix
      expect(validateTALPrefix('ABC234567'), isFalse);
      expect(validateTALPrefix('XYZ123456'), isFalse);
      expect(validateTALPrefix('123456789'), isFalse);
      expect(validateTALPrefix(''), isFalse);
    });

    test('Validate Crockford base32 format', () {
      // Valid Crockford base32 characters (A-Z, 2-7, no 0/O/1/I)
      expect(isValidCrockfordBase32('ABCDEF'), isTrue);
      expect(isValidCrockfordBase32('234567'), isTrue);
      expect(isValidCrockfordBase32('GHKMNP'), isTrue);
      expect(isValidCrockfordBase32('QRSTVW'), isTrue);
      expect(isValidCrockfordBase32('XYZ234'), isTrue);
      
      // Invalid characters (contains 0, O, 1, I)
      expect(isValidCrockfordBase32('ABC0EF'), isFalse);
      expect(isValidCrockfordBase32('ABCOEF'), isFalse);
      expect(isValidCrockfordBase32('ABC1EF'), isFalse);
      expect(isValidCrockfordBase32('ABCIEF'), isFalse);
      
      // Invalid length
      expect(isValidCrockfordBase32('ABC'), isFalse);
      expect(isValidCrockfordBase32('ABCDEFGH'), isFalse);
      expect(isValidCrockfordBase32(''), isFalse);
    });

    test('Validate complete referral code format', () {
      // Valid complete codes
      expect(validateCompleteReferralCode('TALABC234'), isTrue);
      expect(validateCompleteReferralCode('TALXYZ567'), isTrue);
      expect(validateCompleteReferralCode('TAL2A3B4C'), isTrue);
      expect(validateCompleteReferralCode('TALADMIN'), isTrue); // Admin exception
      
      // Invalid codes
      expect(validateCompleteReferralCode('ABC123456'), isFalse); // No TAL prefix
      expect(validateCompleteReferralCode('TAL12345'), isFalse); // Too short
      expect(validateCompleteReferralCode('TAL1234567'), isFalse); // Too long
      expect(validateCompleteReferralCode('TALOI1234'), isFalse); // Invalid chars
      expect(validateCompleteReferralCode('Loading'), isFalse); // Loading state
      expect(validateCompleteReferralCode('TALLoading'), isFalse); // Contains Loading
      expect(validateCompleteReferralCode(''), isFalse); // Empty
    });

    test('Validate no Loading states', () {
      expect(hasLoadingState('TALABC234'), isFalse);
      expect(hasLoadingState('TALXYZ567'), isFalse);
      expect(hasLoadingState('TALADMIN'), isFalse);
      
      expect(hasLoadingState('Loading'), isTrue);
      expect(hasLoadingState('TALLoading'), isTrue);
      expect(hasLoadingState('LoadingTAL'), isTrue);
      expect(hasLoadingState('TAL Loading'), isTrue);
    });

    test('Generate test referral codes', () {
      for (int i = 0; i < 10; i++) {
        final code = generateTestReferralCode();
        
        // Should start with TAL
        expect(code.startsWith('TAL'), isTrue, reason: 'Code $code should start with TAL');
        
        // Should be 9 characters total
        expect(code.length, equals(9), reason: 'Code $code should be 9 characters');
        
        // Code body should be valid Crockford base32
        final codeBody = code.substring(3);
        expect(isValidCrockfordBase32(codeBody), isTrue, reason: 'Code body $codeBody should be valid Crockford base32');
        
        print('Generated test code: $code');
      }
    });

    test('Validate code uniqueness in batch', () {
      final codes = <String>[];
      
      // Generate 20 test codes
      for (int i = 0; i < 20; i++) {
        codes.add(generateTestReferralCode());
      }
      
      // Check for duplicates
      final uniqueCodes = codes.toSet();
      expect(uniqueCodes.length, equals(codes.length), 
        reason: 'All generated codes should be unique. Generated ${codes.length}, unique ${uniqueCodes.length}');
      
      print('Generated ${codes.length} unique codes successfully');
    });
  });
}

// Helper functions for validation logic

bool validateTALPrefix(String code) {
  return code.startsWith('TAL');
}

bool isValidCrockfordBase32(String code) {
  const crockfordAlphabet = 'ABCDEFGHJKMNPQRSTVWXYZ234567';
  
  if (code.length != 6) return false;
  
  for (int i = 0; i < code.length; i++) {
    if (!crockfordAlphabet.contains(code[i])) {
      return false;
    }
  }
  return true;
}

bool validateCompleteReferralCode(String code) {
  // Check empty
  if (code.isEmpty) return false;
  
  // Check Loading state
  if (hasLoadingState(code)) return false;
  
  // Check admin exception
  if (code == 'TALADMIN') return true;
  
  // Check TAL prefix
  if (!validateTALPrefix(code)) return false;
  
  // Check length
  if (code.length != 9) return false;
  
  // Check Crockford base32 format
  final codeBody = code.substring(3);
  return isValidCrockfordBase32(codeBody);
}

bool hasLoadingState(String code) {
  return code == 'Loading' || code.contains('Loading');
}

final Random _random = Random();

String generateTestReferralCode() {
  const crockfordAlphabet = 'ABCDEFGHJKMNPQRSTVWXYZ234567';
  
  final codeBuffer = StringBuffer('TAL');
  
  // Generate 6 random characters using proper Random
  for (int i = 0; i < 6; i++) {
    final randomIndex = _random.nextInt(crockfordAlphabet.length);
    codeBuffer.write(crockfordAlphabet[randomIndex]);
  }
  
  return codeBuffer.toString();
}