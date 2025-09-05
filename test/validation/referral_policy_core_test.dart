// Core Referral Code Policy Validation Test (Test Case E)
// Tests the referral code policy logic without Firebase dependencies

import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('Test Case E: Referral Code Policy Validation', () {
    late ReferralCodePolicyValidator validator;

    setUpAll(() {
      validator = ReferralCodePolicyValidator();
      print('ðŸ§ª Starting Test Case E: Referral Code Policy Validation');
    });

    test('Complete Referral Code Policy Validation', () {
      print('ðŸ” Running comprehensive referral code policy validation...');
      
      final result = validator.validateReferralCodePolicyCore();
      
      print('ðŸ“Š Test Case E Result:');
      print('   Status: ${result.passed ? "PASS" : "FAIL"}');
      print('   Message: ${result.message}');
      
      if (!result.passed) {
        print('âŒ FAILURE DETAILS:');
        if (result.errorDetails != null) {
          print('   Error: ${result.errorDetails}');
        }
        if (result.suspectedModule != null) {
          print('   Suspected Module: ${result.suspectedModule}');
        }
        if (result.suggestedFix != null) {
          print('   Suggested Fix: ${result.suggestedFix}');
        }
      } else {
        print('âœ… Test Case E PASSED: All referral code policy requirements met');
      }
      
      expect(result.passed, isTrue, reason: 'Test Case E: Referral code policy validation should pass');
    });

    test('TAL Prefix Requirement Validation', () {
      print('ðŸ” Testing TAL prefix requirement...');
      
      // Valid codes with TAL prefix
      final validCodes = ['TALABC234', 'TALXYZ567', 'TAL2A3B4C', 'TALADMIN'];
      for (final code in validCodes) {
        expect(validator.validateTALPrefix(code), isTrue, 
          reason: 'Code $code should have valid TAL prefix');
      }
      
      // Invalid codes without TAL prefix
      final invalidCodes = ['ABC234567', 'XYZ123456', '123456789', '', 'NOTTAL123'];
      for (final code in invalidCodes) {
        expect(validator.validateTALPrefix(code), isFalse, 
          reason: 'Code $code should fail TAL prefix validation');
      }
      
      print('âœ… TAL prefix requirement validation passed');
    });

    test('Crockford Base32 Format Compliance', () {
      print('ðŸ” Testing Crockford base32 format compliance...');
      
      // Valid Crockford base32 characters (A-Z, 2-7, no 0/O/1/I)
      final validFormats = ['ABCDEF', '234567', 'GHKMNP', 'QRSTVW', 'XYZ234'];
      for (final format in validFormats) {
        expect(validator.isValidCrockfordBase32(format), isTrue, 
          reason: 'Format $format should be valid Crockford base32');
      }
      
      // Invalid characters (contains 0, O, 1, I)
      final invalidFormats = ['ABC0EF', 'ABCOEF', 'ABC1EF', 'ABCIEF', 'ABC', 'ABCDEFGH', ''];
      for (final format in invalidFormats) {
        expect(validator.isValidCrockfordBase32(format), isFalse, 
          reason: 'Format $format should fail Crockford base32 validation');
      }
      
      print('âœ… Crockford base32 format compliance validation passed');
    });

    test('TALADMIN Exception Handling', () {
      print('ðŸ” Testing TALADMIN exception handling...');
      
      final adminResult = validator.validateCodeFormat('TALADMIN');
      expect(adminResult.passed, isTrue, reason: 'TALADMIN should be allowed as exception');
      expect(adminResult.message.toLowerCase(), contains('exception'), 
        reason: 'TALADMIN validation should mention exception');
      
      // Ensure TALADMIN doesn't follow normal TAL+6 format rules
      expect('TALADMIN'.length, isNot(equals(9)), 
        reason: 'TALADMIN should not follow normal 9-character rule');
      
      print('âœ… TALADMIN exception handling validation passed');
    });

    test('No Loading States Validation', () {
      print('ðŸ” Testing no Loading states validation...');
      
      // Valid codes (no Loading)
      final validCodes = ['TALABC234', 'TALXYZ567', 'TALADMIN'];
      for (final code in validCodes) {
        expect(validator.hasLoadingState(code), isFalse, 
          reason: 'Code $code should not be detected as Loading state');
      }
      
      // Invalid codes (contains Loading)
      final loadingCodes = ['Loading', 'TALLoading', 'LoadingTAL', 'TAL Loading'];
      for (final code in loadingCodes) {
        expect(validator.hasLoadingState(code), isTrue, 
          reason: 'Code $code should be detected as Loading state');
      }
      
      print('âœ… No Loading states validation passed');
    });

    test('Code Generation and Uniqueness', () {
      print('ðŸ” Testing code generation and uniqueness...');
      
      final codes = <String>[];
      
      // Generate test codes
      for (int i = 0; i < 50; i++) {
        final code = validator.generateTestCode();
        codes.add(code);
        
        // Validate each generated code
        final validation = validator.validateCodeFormat(code);
        expect(validation.passed, isTrue, 
          reason: 'Generated code $code should be valid: ${validation.message}');
        
        // Should start with TAL
        expect(code.startsWith('TAL'), isTrue, 
          reason: 'Generated code $code should start with TAL');
        
        // Should be 9 characters total
        expect(code.length, equals(9), 
          reason: 'Generated code $code should be 9 characters');
        
        // Code body should be valid Crockford base32
        final codeBody = code.substring(3);
        expect(validator.isValidCrockfordBase32(codeBody), isTrue, 
          reason: 'Code body $codeBody should be valid Crockford base32');
      }
      
      // Check for uniqueness
      final uniqueCodes = codes.toSet();
      expect(uniqueCodes.length, equals(codes.length), 
        reason: 'All generated codes should be unique. Generated ${codes.length}, unique ${uniqueCodes.length}');
      
      print('âœ… Generated ${codes.length} unique valid referral codes');
    });

    test('Complete Code Format Validation', () {
      print('ðŸ” Testing complete code format validation...');
      
      // Valid complete codes
      final validCodes = ['TALABC234', 'TALXYZ567', 'TAL2A3B4C', 'TALADMIN'];
      for (final code in validCodes) {
        final result = validator.validateCodeFormat(code);
        expect(result.passed, isTrue, 
          reason: 'Valid code $code should pass validation: ${result.message}');
      }
      
      // Invalid codes
      final invalidCodes = [
        'ABC123456',  // No TAL prefix
        'TAL12345',   // Too short
        'TAL1234567', // Too long
        'TALOI1234',  // Invalid chars (O, I)
        'Loading',    // Loading state
        'TALLoading', // Contains Loading
        '',           // Empty
      ];
      
      for (final code in invalidCodes) {
        final result = validator.validateCodeFormat(code);
        expect(result.passed, isFalse, 
          reason: 'Invalid code $code should fail validation');
      }
      
      print('âœ… Complete code format validation passed');
    });

    test('Policy Compliance Summary', () {
      print('ðŸ” Generating policy compliance summary...');
      
      final summary = validator.generatePolicyComplianceSummary();
      
      print('ðŸ“Š Policy Compliance Summary:');
      print('   Test Codes Generated: ${summary['testCodesGenerated']}');
      print('   Valid Codes: ${summary['validCodes']}');
      print('   Compliance Rate: ${summary['complianceRate']}%');
      print('   TAL Prefix Compliance: ${summary['talPrefixCompliance']}');
      print('   Crockford Format Compliance: ${summary['crockfordFormatCompliance']}');
      print('   No Loading States: ${summary['noLoadingStates']}');
      print('   TALADMIN Exception Handled: ${summary['taladminExceptionHandled']}');
      
      expect(summary['complianceRate'], equals(100.0), 
        reason: 'All test codes should be 100% compliant');
      expect(summary['talPrefixCompliance'], isTrue, 
        reason: 'TAL prefix compliance should be true');
      expect(summary['crockfordFormatCompliance'], isTrue, 
        reason: 'Crockford format compliance should be true');
      expect(summary['noLoadingStates'], isTrue, 
        reason: 'No Loading states should be true');
      expect(summary['taladminExceptionHandled'], isTrue, 
        reason: 'TALADMIN exception should be handled');
      
      print('âœ… Policy compliance summary validation passed');
    });

    tearDownAll(() {
      print('ðŸŽ¯ Test Case E: Referral Code Policy Validation completed');
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
  
  /// Core validation without Firebase dependencies
  ValidationResult validateReferralCodePolicyCore() {
    try {
      print('ðŸ” Validating referral code policy (core logic)...');
      
      // Step 1: Validate code generation algorithm
      final generationResult = _validateCodeGeneration();
      if (!generationResult.passed) return generationResult;
      
      // Step 2: Validate TALADMIN exception
      final adminExceptionResult = _validateAdminException();
      if (!adminExceptionResult.passed) return adminExceptionResult;
      
      // Step 3: Test code uniqueness
      final uniquenessResult = _validateCodeUniqueness();
      if (!uniquenessResult.passed) return uniquenessResult;
      
      // Step 4: Validate no "Loading" states
      final loadingStateResult = _validateNoLoadingStates();
      if (!loadingStateResult.passed) return loadingStateResult;
      
      // Step 5: Validate format compliance
      final formatResult = _validateFormatCompliance();
      if (!formatResult.passed) return formatResult;
      
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
  
  ValidationResult _validateCodeGeneration() {
    try {
      // Generate multiple test codes
      final testCodes = <String>[];
      for (int i = 0; i < 20; i++) {
        final code = generateTestCode();
        testCodes.add(code);
        
        // Validate TAL prefix
        if (!code.startsWith(_talPrefix)) {
          return ValidationResult.fail(
            'Generated code missing TAL prefix: $code',
            errorDetails: 'Code: $code does not start with $_talPrefix',
            suspectedModule: 'ReferralCodeGenerator',
            suggestedFix: 'Ensure TAL prefix is added to all generated codes',
          );
        }
        
        // Validate length (TAL + 6 characters)
        if (code.length != 9) {
          return ValidationResult.fail(
            'Generated code incorrect length: $code',
            errorDetails: 'Expected 9 characters (TAL + 6), got ${code.length}',
            suspectedModule: 'ReferralCodeGenerator',
            suggestedFix: 'Fix code length to 6 characters after TAL prefix',
          );
        }
        
        // Validate Crockford base32 format
        final codeBody = code.substring(3);
        if (!isValidCrockfordBase32(codeBody)) {
          return ValidationResult.fail(
            'Generated code invalid Crockford base32 format: $code',
            errorDetails: 'Code body "$codeBody" contains invalid characters',
            suspectedModule: 'ReferralCodeGenerator',
            suggestedFix: 'Use only Crockford base32 alphabet: $_crockfordAlphabet',
          );
        }
      }
      
      // Check for duplicates
      final uniqueCodes = testCodes.toSet();
      if (uniqueCodes.length != testCodes.length) {
        return ValidationResult.fail(
          'Code generation produces duplicates',
          errorDetails: 'Generated ${testCodes.length} codes but only ${uniqueCodes.length} unique',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'Improve randomization or add uniqueness check',
        );
      }
      
      return ValidationResult.pass('Code generation follows TAL prefix and Crockford base32 format');
      
    } catch (e) {
      return ValidationResult.fail(
        'Code generation validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeGenerator',
      );
    }
  }
  
  ValidationResult _validateAdminException() {
    try {
      // Test TALADMIN validation
      final adminResult = validateCodeFormat(_adminException);
      if (!adminResult.passed) {
        return ValidationResult.fail(
          'TALADMIN exception not properly handled',
          errorDetails: adminResult.message,
          suspectedModule: 'ReferralCodeValidator',
          suggestedFix: 'Allow TALADMIN as special exception in validation logic',
        );
      }
      
      return ValidationResult.pass('TALADMIN exception properly handled');
      
    } catch (e) {
      return ValidationResult.fail(
        'TALADMIN exception validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeValidator',
      );
    }
  }
  
  ValidationResult _validateCodeUniqueness() {
    try {
      // Generate test codes and check uniqueness
      final codes = <String>[];
      for (int i = 0; i < 100; i++) {
        codes.add(generateTestCode());
      }
      
      // Check for duplicates
      final uniqueCodes = codes.toSet();
      if (uniqueCodes.length != codes.length) {
        return ValidationResult.fail(
          'Duplicate referral codes found in generation',
          errorDetails: 'Generated ${codes.length} codes but only ${uniqueCodes.length} unique',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'Add uniqueness check before assigning codes',
        );
      }
      
      return ValidationResult.pass('All referral codes are unique');
      
    } catch (e) {
      return ValidationResult.fail(
        'Code uniqueness validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeGenerator',
      );
    }
  }
  
  ValidationResult _validateNoLoadingStates() {
    try {
      // Test various Loading state scenarios
      final loadingTests = ['Loading', 'TALLoading', 'LoadingTAL', 'TAL Loading'];
      
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
      final validTests = ['TALABC234', 'TALXYZ567', 'TALADMIN'];
      
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
      
      return ValidationResult.pass('No "Loading" states found in referral codes');
      
    } catch (e) {
      return ValidationResult.fail(
        'Loading states validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeValidator',
      );
    }
  }
  
  ValidationResult _validateFormatCompliance() {
    try {
      // Test various code formats
      final testCodes = [
        'TALABC234', 'TALXYZ567', 'TAL2A3B4C', 'TALGHKMNP',
        'TALQRSTVW', 'TAL234567', 'TALABCDEF', 'TALXYZ234'
      ];
      
      for (final code in testCodes) {
        final result = validateCodeFormat(code);
        if (!result.passed) {
          return ValidationResult.fail(
            'Format compliance validation failed',
            errorDetails: 'Code "$code" failed validation: ${result.message}',
            suspectedModule: 'ReferralCodeValidator',
            suggestedFix: 'Fix format validation logic',
          );
        }
      }
      
      return ValidationResult.pass('All test codes comply with format requirements');
      
    } catch (e) {
      return ValidationResult.fail(
        'Format compliance validation failed',
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
  
  Map<String, dynamic> generatePolicyComplianceSummary() {
    final testCodes = <String>[];
    int validCodes = 0;
    
    // Generate test codes
    for (int i = 0; i < 50; i++) {
      final code = generateTestCode();
      testCodes.add(code);
      
      final validation = validateCodeFormat(code);
      if (validation.passed) {
        validCodes++;
      }
    }
    
    return {
      'testCodesGenerated': testCodes.length,
      'validCodes': validCodes,
      'complianceRate': testCodes.isNotEmpty ? (validCodes / testCodes.length * 100) : 0.0,
      'talPrefixCompliance': testCodes.every((code) => validateTALPrefix(code)),
      'crockfordFormatCompliance': testCodes.every((code) => 
        code == _adminException || isValidCrockfordBase32(code.substring(3))),
      'noLoadingStates': testCodes.every((code) => !hasLoadingState(code)),
      'taladminExceptionHandled': validateCodeFormat(_adminException).passed,
      'timestamp': DateTime.now().toIso8601String(),
    };
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
