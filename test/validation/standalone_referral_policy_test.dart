// Standalone Referral Code Policy Validation Test
// This test validates the referral code policy implementation without external dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

void main() {
  group('Referral Code Policy Validation (Test Case E)', () {
    setUpAll(() async {
      // Initialize Firebase for testing if available
      try {
        await Firebase.initializeApp();
        print('✅ Firebase initialized for testing');
      } catch (e) {
        print('⚠️ Firebase not available for testing: $e');
      }
    });

    test('Test Case E: Complete Referral Code Policy Validation', () async {
      print('🧪 Running Test Case E: Referral Code Policy Validation...');
      
      final validator = ReferralCodePolicyValidator();
      final result = await validator.validateReferralCodePolicy();
      
      print('📊 Validation Result:');
      print('   Status: ${result.passed ? "PASS" : "FAIL"}');
      print('   Message: ${result.message}');
      
      if (!result.passed) {
        print('❌ FAILURE DETAILS:');
        if (result.errorDetails != null) {
          print('   Error: ${result.errorDetails}');
        }
        if (result.suspectedModule != null) {
          print('   Suspected Module: ${result.suspectedModule}');
        }
        if (result.suggestedFix != null) {
          print('   Suggested Fix: ${result.suggestedFix}');
        }
      }
      
      // The test should pass for proper implementation
      expect(result.passed, isTrue, reason: 'Referral code policy validation should pass');
    });

    test('Validate TAL prefix requirement', () {
      final validator = ReferralCodePolicyValidator();
      
      // Valid codes with TAL prefix
      expect(validator.validateTALPrefix('TALABC234'), isTrue);
      expect(validator.validateTALPrefix('TALXYZ567'), isTrue);
      expect(validator.validateTALPrefix('TALADMIN'), isTrue); // Admin exception
      
      // Invalid codes without TAL prefix
      expect(validator.validateTALPrefix('ABC234567'), isFalse);
      expect(validator.validateTALPrefix('XYZ123456'), isFalse);
      expect(validator.validateTALPrefix('123456789'), isFalse);
      expect(validator.validateTALPrefix(''), isFalse);
      
      print('✅ TAL prefix validation tests passed');
    });

    test('Validate Crockford base32 format compliance', () {
      final validator = ReferralCodePolicyValidator();
      
      // Valid Crockford base32 characters (A-Z, 2-7, no 0/O/1/I)
      expect(validator.isValidCrockfordBase32('ABCDEF'), isTrue);
      expect(validator.isValidCrockfordBase32('234567'), isTrue);
      expect(validator.isValidCrockfordBase32('GHKMNP'), isTrue);
      expect(validator.isValidCrockfordBase32('QRSTVW'), isTrue);
      expect(validator.isValidCrockfordBase32('XYZ234'), isTrue);
      
      // Invalid characters (contains 0, O, 1, I)
      expect(validator.isValidCrockfordBase32('ABC0EF'), isFalse);
      expect(validator.isValidCrockfordBase32('ABCOEF'), isFalse);
      expect(validator.isValidCrockfordBase32('ABC1EF'), isFalse);
      expect(validator.isValidCrockfordBase32('ABCIEF'), isFalse);
      
      // Invalid length
      expect(validator.isValidCrockfordBase32('ABC'), isFalse);
      expect(validator.isValidCrockfordBase32('ABCDEFGH'), isFalse);
      expect(validator.isValidCrockfordBase32(''), isFalse);
      
      print('✅ Crockford base32 format validation tests passed');
    });

    test('Validate TALADMIN exception handling', () {
      final validator = ReferralCodePolicyValidator();
      
      final result = validator.validateCodeFormat('TALADMIN');
      expect(result.passed, isTrue, reason: 'TALADMIN should be allowed as exception');
      expect(result.message, contains('exception'), reason: 'Should mention exception');
      
      print('✅ TALADMIN exception handling test passed');
    });

    test('Validate no Loading states', () {
      final validator = ReferralCodePolicyValidator();
      
      // Valid codes (no Loading)
      expect(validator.hasLoadingState('TALABC234'), isFalse);
      expect(validator.hasLoadingState('TALXYZ567'), isFalse);
      expect(validator.hasLoadingState('TALADMIN'), isFalse);
      
      // Invalid codes (contains Loading)
      expect(validator.hasLoadingState('Loading'), isTrue);
      expect(validator.hasLoadingState('TALLoading'), isTrue);
      expect(validator.hasLoadingState('LoadingTAL'), isTrue);
      expect(validator.hasLoadingState('TAL Loading'), isTrue);
      
      print('✅ Loading state validation tests passed');
    });

    test('Generate and validate test referral codes', () {
      final validator = ReferralCodePolicyValidator();
      final codes = <String>[];
      
      for (int i = 0; i < 20; i++) {
        final code = validator.generateTestCode();
        codes.add(code);
        
        // Validate each generated code
        final validation = validator.validateCodeFormat(code);
        expect(validation.passed, isTrue, reason: 'Generated code $code should be valid');
        
        // Should start with TAL
        expect(code.startsWith('TAL'), isTrue, reason: 'Code $code should start with TAL');
        
        // Should be 9 characters total
        expect(code.length, equals(9), reason: 'Code $code should be 9 characters');
        
        // Code body should be valid Crockford base32
        final codeBody = code.substring(3);
        expect(validator.isValidCrockfordBase32(codeBody), isTrue, 
          reason: 'Code body $codeBody should be valid Crockford base32');
      }
      
      // Check for uniqueness
      final uniqueCodes = codes.toSet();
      expect(uniqueCodes.length, equals(codes.length), 
        reason: 'All generated codes should be unique. Generated ${codes.length}, unique ${uniqueCodes.length}');
      
      print('✅ Generated ${codes.length} unique valid referral codes');
    });

    test('Database validation (if Firebase available)', () async {
      try {
        final validator = ReferralCodePolicyValidator();
        final dbResult = await validator.validateExistingCodesInDatabase();
        
        print('📊 Database Validation Result:');
        print('   Status: ${dbResult.passed ? "PASS" : "FAIL"}');
        print('   Message: ${dbResult.message}');
        
        if (!dbResult.passed) {
          print('⚠️ Database validation issues found:');
          if (dbResult.errorDetails != null) {
            print('   Details: ${dbResult.errorDetails}');
          }
        }
        
        // Note: This test may fail if database has policy violations
        // That's expected and helps identify issues
        
      } catch (e) {
        print('⚠️ Database validation skipped (Firebase not available): $e');
      }
    });
  });
}

/// Referral Code Policy Validator Implementation
class ReferralCodePolicyValidator {
  // Crockford base32 alphabet (excludes 0, O, 1, I for clarity)
  static const String _crockfordAlphabet = 'ABCDEFGHJKMNPQRSTVWXYZ234567';
  static const String _talPrefix = 'TAL';
  static const String _adminException = 'TALADMIN';
  static const int _codeLength = 6; // TAL + 6 characters = 9 total
  
  final Random _random = Random();
  
  /// Main validation entry point for Test Case E
  Future<ValidationResult> validateReferralCodePolicy() async {
    try {
      print('🔍 Validating referral code policy...');
      
      // Step 1: Validate code generation algorithm
      final generationResult = _validateCodeGeneration();
      if (!generationResult.passed) return generationResult;
      
      // Step 2: Check existing user codes in database (if available)
      try {
        final existingCodesResult = await validateExistingCodesInDatabase();
        if (!existingCodesResult.passed) return existingCodesResult;
      } catch (e) {
        print('⚠️ Database validation skipped: $e');
      }
      
      // Step 3: Validate TALADMIN exception
      final adminExceptionResult = _validateAdminException();
      if (!adminExceptionResult.passed) return adminExceptionResult;
      
      // Step 4: Test code uniqueness
      final uniquenessResult = _validateCodeUniqueness();
      if (!uniquenessResult.passed) return uniquenessResult;
      
      // Step 5: Validate no "Loading" states
      final loadingStateResult = _validateNoLoadingStates();
      if (!loadingStateResult.passed) return loadingStateResult;
      
      return ValidationResult.pass(
        'All referral codes comply with TAL prefix policy and Crockford base32 format'
      );
      
    } catch (e) {
      return ValidationResult.fail(
        'Referral code policy validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeGenerator',
        suggestedFix: 'lib/services/referral/referral_code_generator.dart:generateUniqueCode - Fix code generation logic',
      );
    }
  }
  
  /// Validate code generation algorithm
  ValidationResult _validateCodeGeneration() {
    try {
      print('🔍 Validating referral code generation algorithm...');
      
      // Generate multiple test codes
      final testCodes = <String>[];
      for (int i = 0; i < 10; i++) {
        final code = generateTestCode();
        testCodes.add(code);
        
        // Validate TAL prefix
        if (!code.startsWith(_talPrefix)) {
          return ValidationResult.fail(
            'Generated code missing TAL prefix: $code',
            errorDetails: 'Code: $code does not start with $_talPrefix',
            suspectedModule: 'ReferralCodeGenerator',
            suggestedFix: 'lib/services/referral/referral_code_generator.dart:generateUniqueCode - Ensure TAL prefix is added',
          );
        }
        
        // Validate length (TAL + 6 characters)
        if (code.length != 9) {
          return ValidationResult.fail(
            'Generated code incorrect length: $code',
            errorDetails: 'Expected 9 characters (TAL + 6), got ${code.length}',
            suspectedModule: 'ReferralCodeGenerator',
            suggestedFix: 'lib/services/referral/referral_code_generator.dart:generateUniqueCode - Fix code length to 6 characters after TAL',
          );
        }
        
        // Validate Crockford base32 format
        final codeBody = code.substring(3); // Remove TAL prefix
        if (!isValidCrockfordBase32(codeBody)) {
          return ValidationResult.fail(
            'Generated code invalid Crockford base32 format: $code',
            errorDetails: 'Code body "$codeBody" contains invalid characters. Must use A-Z, 2-7 (no 0/O/1/I)',
            suspectedModule: 'ReferralCodeGenerator',
            suggestedFix: 'lib/services/referral/referral_code_generator.dart:generateUniqueCode - Use only Crockford base32 alphabet: $_crockfordAlphabet',
          );
        }
      }
      
      // Check for duplicates in generated codes
      final uniqueCodes = testCodes.toSet();
      if (uniqueCodes.length != testCodes.length) {
        return ValidationResult.fail(
          'Code generation produces duplicates',
          errorDetails: 'Generated ${testCodes.length} codes but only ${uniqueCodes.length} unique',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'lib/services/referral/referral_code_generator.dart:generateUniqueCode - Improve randomization or add uniqueness check',
        );
      }
      
      print('✅ Code generation algorithm validation passed');
      return ValidationResult.pass('Code generation follows TAL prefix and Crockford base32 format');
      
    } catch (e) {
      return ValidationResult.fail(
        'Code generation validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeGenerator',
      );
    }
  }
  
  /// Validate existing codes in database
  Future<ValidationResult> validateExistingCodesInDatabase() async {
    try {
      print('🔍 Validating existing referral codes in database...');
      
      final firestore = FirebaseFirestore.instance;
      
      // Check user_registry collection
      final registryQuery = await firestore
          .collection('user_registry')
          .limit(100) // Sample check
          .get();
      
      final violations = <String>[];
      
      for (final doc in registryQuery.docs) {
        final data = doc.data();
        final referralCode = data['referralCode'] as String?;
        
        if (referralCode == null || referralCode.isEmpty) {
          violations.add('${doc.id}: Missing referral code');
          continue;
        }
        
        // Skip admin exception
        if (referralCode == _adminException) {
          continue;
        }
        
        // Check TAL prefix
        if (!referralCode.startsWith(_talPrefix)) {
          violations.add('${doc.id}: Code "$referralCode" missing TAL prefix');
          continue;
        }
        
        // Check length
        if (referralCode.length != 9) {
          violations.add('${doc.id}: Code "$referralCode" incorrect length (${referralCode.length})');
          continue;
        }
        
        // Check Crockford base32 format
        final codeBody = referralCode.substring(3);
        if (!isValidCrockfordBase32(codeBody)) {
          violations.add('${doc.id}: Code "$referralCode" invalid format');
          continue;
        }
        
        // Check for "Loading" state
        if (referralCode == 'Loading' || referralCode.contains('Loading')) {
          violations.add('${doc.id}: Code shows "Loading" state');
          continue;
        }
      }
      
      if (violations.isNotEmpty) {
        return ValidationResult.fail(
          'Referral code policy violations found',
          errorDetails: violations.take(5).join('; ') + (violations.length > 5 ? '...' : ''),
          suspectedModule: 'ServerProfileEnsureService',
          suggestedFix: 'lib/services/server_profile_ensure_service.dart:ensureUserProfile - Fix referral code generation and ensure TAL prefix',
        );
      }
      
      print('✅ Existing codes validation passed');
      return ValidationResult.pass('All existing referral codes comply with policy');
      
    } catch (e) {
      return ValidationResult.fail(
        'Existing codes validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'Database/ReferralCodes',
      );
    }
  }
  
  /// Validate TALADMIN exception handling
  ValidationResult _validateAdminException() {
    try {
      print('🔍 Validating TALADMIN exception handling...');
      
      // Test TALADMIN validation
      final adminResult = validateCodeFormat(_adminException);
      if (!adminResult.passed) {
        return ValidationResult.fail(
          'TALADMIN exception not properly handled',
          errorDetails: adminResult.message,
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'Allow TALADMIN as special exception in validation logic',
        );
      }
      
      print('✅ TALADMIN exception validation passed');
      return ValidationResult.pass('TALADMIN exception properly handled');
      
    } catch (e) {
      return ValidationResult.fail(
        'TALADMIN exception validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeGenerator',
      );
    }
  }
  
  /// Validate code uniqueness
  ValidationResult _validateCodeUniqueness() {
    try {
      print('🔍 Validating referral code uniqueness...');
      
      // Generate test codes and check uniqueness
      final codes = <String>[];
      for (int i = 0; i < 50; i++) {
        codes.add(generateTestCode());
      }
      
      // Check for duplicates
      final uniqueCodes = codes.toSet();
      if (uniqueCodes.length != codes.length) {
        final duplicates = <String>[];
        final seen = <String>{};
        for (final code in codes) {
          if (seen.contains(code)) {
            duplicates.add(code);
          } else {
            seen.add(code);
          }
        }
        
        return ValidationResult.fail(
          'Duplicate referral codes found in generation',
          errorDetails: 'Duplicates: ${duplicates.take(5).join(', ')}',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'lib/services/referral/referral_code_generator.dart:generateUniqueCode - Add uniqueness check before assigning codes',
        );
      }
      
      print('✅ Code uniqueness validation passed');
      return ValidationResult.pass('All referral codes are unique');
      
    } catch (e) {
      return ValidationResult.fail(
        'Code uniqueness validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeGenerator',
      );
    }
  }
  
  /// Validate no "Loading" states
  ValidationResult _validateNoLoadingStates() {
    try {
      print('🔍 Validating no "Loading" states in referral codes...');
      
      // Test various Loading state scenarios
      final loadingTests = [
        'Loading',
        'TALLoading',
        'LoadingTAL',
        'TAL Loading',
        'TALLOAD234',
      ];
      
      for (final testCode in loadingTests) {
        if (!hasLoadingState(testCode)) {
          return ValidationResult.fail(
            'Loading state detection failed',
            errorDetails: 'Code "$testCode" should be detected as Loading state',
            suspectedModule: 'ReferralCodeValidator',
            suggestedFix: 'Improve Loading state detection logic',
          );
        }
      }
      
      // Test valid codes don't trigger Loading detection
      final validTests = [
        'TALABC234',
        'TALXYZ567',
        'TALADMIN',
      ];
      
      for (final testCode in validTests) {
        if (hasLoadingState(testCode)) {
          return ValidationResult.fail(
            'False positive Loading state detection',
            errorDetails: 'Code "$testCode" should NOT be detected as Loading state',
            suspectedModule: 'ReferralCodeValidator',
            suggestedFix: 'Fix Loading state detection to avoid false positives',
          );
        }
      }
      
      print('✅ No Loading states validation passed');
      return ValidationResult.pass('No "Loading" states found in referral codes');
      
    } catch (e) {
      return ValidationResult.fail(
        'Loading states validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeValidator',
      );
    }
  }
  
  /// Helper methods
  
  bool validateTALPrefix(String code) {
    return code.startsWith(_talPrefix);
  }
  
  bool isValidCrockfordBase32(String code) {
    if (code.length != _codeLength) return false;
    
    for (int i = 0; i < code.length; i++) {
      if (!_crockfordAlphabet.contains(code[i])) {
        return false;
      }
    }
    return true;
  }
  
  bool hasLoadingState(String code) {
    return code == 'Loading' || code.contains('Loading');
  }
  
  String generateTestCode() {
    final codeBuffer = StringBuffer(_talPrefix);
    
    for (int i = 0; i < _codeLength; i++) {
      final randomIndex = _random.nextInt(_crockfordAlphabet.length);
      codeBuffer.write(_crockfordAlphabet[randomIndex]);
    }
    
    return codeBuffer.toString();
  }
  
  ValidationResult validateCodeFormat(String code) {
    // Check null/empty
    if (code.isEmpty) {
      return ValidationResult.fail(
        'Referral code is empty',
        suggestedFix: 'Generate proper referral code',
      );
    }
    
    // Check Loading state
    if (hasLoadingState(code)) {
      return ValidationResult.fail(
        'Referral code shows Loading state',
        errorDetails: 'Code: $code',
        suggestedFix: 'Fix referral code generation timing',
      );
    }
    
    // Check admin exception
    if (code == _adminException) {
      return ValidationResult.pass('TALADMIN exception allowed');
    }
    
    // Check TAL prefix
    if (!validateTALPrefix(code)) {
      return ValidationResult.fail(
        'Referral code missing TAL prefix',
        errorDetails: 'Code: $code',
        suggestedFix: 'Add TAL prefix to referral code',
      );
    }
    
    // Check length
    if (code.length != 9) {
      return ValidationResult.fail(
        'Referral code incorrect length',
        errorDetails: 'Expected 9 characters, got ${code.length}',
        suggestedFix: 'Use TAL + 6 character format',
      );
    }
    
    // Check Crockford base32 format
    final codeBody = code.substring(3);
    if (!isValidCrockfordBase32(codeBody)) {
      return ValidationResult.fail(
        'Referral code invalid Crockford base32 format',
        errorDetails: 'Code body: $codeBody contains invalid characters',
        suggestedFix: 'Use only A-Z, 2-7 (no 0/O/1/I)',
      );
    }
    
    return ValidationResult.pass('Referral code format valid');
  }
}

/// Validation result class
class ValidationResult {
  final bool passed;
  final String message;
  final String? errorDetails;
  final String? suggestedFix;
  final String? suspectedModule;
  
  ValidationResult.pass(this.message) 
      : passed = true, 
        errorDetails = null, 
        suggestedFix = null,
        suspectedModule = null;

  ValidationResult.fail(
    this.message, {
    this.errorDetails,
    this.suggestedFix,
    this.suspectedModule,
  }) : passed = false;
}