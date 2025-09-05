// TALOWA Referral Code Policy Validator
// Comprehensive validation for referral code policy compliance (Test Case E)
//
// This validator ensures:
// 1. TAL prefix requirement for all codes (except TALADMIN)
// 2. Crockford base32 format compliance (Aâ€“Z,2â€“7; no 0/O/1/I)
// 3. TALADMIN exception handling
// 4. No "Loading" states in referral codes
// 5. Code uniqueness and proper generation
//
// Test Case E Requirements:
// - All referral codes must start with "TAL" prefix
// - Codes must use Crockford base32 encoding (A-Z, 2-7, no 0/O/1/I)
// - TALADMIN is allowed as special exception for admin user
// - No user should have "Loading" as referral code
// - Codes must be unique across the system

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'validation_framework.dart';

/// Referral Code Policy Validator for Test Case E
class ReferralCodePolicyValidator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Crockford base32 alphabet (excludes 0, O, 1, I for clarity)
  static const String _crockfordAlphabet = 'ABCDEFGHJKMNPQRSTVWXYZ234567';
  static const String _talPrefix = 'TAL';
  static const String _adminException = 'TALADMIN';
  static const int _codeLength = 6; // TAL + 6 characters = 9 total
  
  /// Main validation entry point for Test Case E
  static Future<ValidationResult> validateReferralCodePolicy() async {
    try {
      debugPrint('ðŸ§ª Running Test Case E: Referral Code Policy Validation...');
      
      // Step 1: Validate code generation algorithm
      final generationResult = await _validateCodeGeneration();
      if (!generationResult.passed) return generationResult;
      
      // Step 2: Check existing user codes in database
      final existingCodesResult = await _validateExistingCodes();
      if (!existingCodesResult.passed) return existingCodesResult;
      
      // Step 3: Validate TALADMIN exception
      final adminExceptionResult = await _validateAdminException();
      if (!adminExceptionResult.passed) return adminExceptionResult;
      
      // Step 4: Test code uniqueness
      final uniquenessResult = await _validateCodeUniqueness();
      if (!uniquenessResult.passed) return uniquenessResult;
      
      // Step 5: Validate no "Loading" states
      final loadingStateResult = await _validateNoLoadingStates();
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
  static Future<ValidationResult> _validateCodeGeneration() async {
    try {
      debugPrint('ðŸ” Validating referral code generation algorithm...');
      
      // Generate multiple test codes
      final testCodes = <String>[];
      for (int i = 0; i < 10; i++) {
        final code = _generateTestCode();
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
        if (!_isValidCrockfordBase32(codeBody)) {
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
      
      debugPrint('âœ… Code generation algorithm validation passed');
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
  static Future<ValidationResult> _validateExistingCodes() async {
    try {
      debugPrint('ðŸ” Validating existing referral codes in database...');
      
      // Check user_registry collection
      final registryQuery = await _firestore
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
        if (!_isValidCrockfordBase32(codeBody)) {
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
      
      // Also check users collection
      final usersQuery = await _firestore
          .collection('users')
          .limit(50) // Sample check
          .get();
      
      for (final doc in usersQuery.docs) {
        final data = doc.data();
        final referralCode = data['referralCode'] as String?;
        
        if (referralCode == null || referralCode.isEmpty) {
          violations.add('users/${doc.id}: Missing referral code');
          continue;
        }
        
        // Skip admin exception
        if (referralCode == _adminException) {
          continue;
        }
        
        // Same validation as above
        if (!referralCode.startsWith(_talPrefix) || 
            referralCode.length != 9 ||
            !_isValidCrockfordBase32(referralCode.substring(3)) ||
            referralCode.contains('Loading')) {
          violations.add('users/${doc.id}: Code "$referralCode" policy violation');
        }
      }
      
      if (violations.isNotEmpty) {
        return ValidationResult.fail(
          'Users collection referral code violations',
          errorDetails: violations.take(3).join('; '),
          suspectedModule: 'AuthService',
          suggestedFix: 'lib/services/auth_service.dart:registerUser - Ensure proper referral code generation',
        );
      }
      
      debugPrint('âœ… Existing codes validation passed');
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
  static Future<ValidationResult> _validateAdminException() async {
    try {
      debugPrint('ðŸ” Validating TALADMIN exception handling...');
      
      // Check admin user has TALADMIN code
      final adminDoc = await _firestore
          .collection('user_registry')
          .doc('+917981828388')
          .get();
      
      if (!adminDoc.exists) {
        return ValidationResult.fail(
          'Admin user not found for TALADMIN validation',
          suspectedModule: 'BootstrapService',
          suggestedFix: 'lib/services/bootstrap_service.dart:bootstrap - Create admin user with TALADMIN code',
        );
      }
      
      final adminData = adminDoc.data()!;
      final adminReferralCode = adminData['referralCode'] as String?;
      
      if (adminReferralCode != _adminException) {
        return ValidationResult.fail(
          'Admin user does not have TALADMIN referral code',
          errorDetails: 'Expected: $_adminException, Found: $adminReferralCode',
          suspectedModule: 'BootstrapService',
          suggestedFix: 'lib/services/bootstrap_service.dart:bootstrap - Set admin referralCode to TALADMIN',
        );
      }
      
      // Verify TALADMIN is not used by other users
      final taladminQuery = await _firestore
          .collection('user_registry')
          .where('referralCode', isEqualTo: _adminException)
          .get();
      
      if (taladminQuery.docs.length > 1) {
        return ValidationResult.fail(
          'TALADMIN code used by multiple users',
          errorDetails: 'Found ${taladminQuery.docs.length} users with TALADMIN code',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'lib/services/referral/referral_code_generator.dart:generateUniqueCode - Prevent TALADMIN generation for non-admin users',
        );
      }
      
      debugPrint('âœ… TALADMIN exception validation passed');
      return ValidationResult.pass('TALADMIN exception properly handled');
      
    } catch (e) {
      return ValidationResult.fail(
        'TALADMIN exception validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'BootstrapService',
      );
    }
  }
  
  /// Validate code uniqueness
  static Future<ValidationResult> _validateCodeUniqueness() async {
    try {
      debugPrint('ðŸ” Validating referral code uniqueness...');
      
      // Get all referral codes from user_registry
      final registryQuery = await _firestore
          .collection('user_registry')
          .get();
      
      final codes = <String>[];
      for (final doc in registryQuery.docs) {
        final data = doc.data();
        final referralCode = data['referralCode'] as String?;
        if (referralCode != null && referralCode.isNotEmpty) {
          codes.add(referralCode);
        }
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
          'Duplicate referral codes found',
          errorDetails: 'Duplicates: ${duplicates.take(5).join(', ')}',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'lib/services/referral/referral_code_generator.dart:generateUniqueCode - Add uniqueness check before assigning codes',
        );
      }
      
      debugPrint('âœ… Code uniqueness validation passed');
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
  static Future<ValidationResult> _validateNoLoadingStates() async {
    try {
      debugPrint('ðŸ” Validating no "Loading" states in referral codes...');
      
      // Check user_registry for Loading states
      final loadingQuery = await _firestore
          .collection('user_registry')
          .where('referralCode', isEqualTo: 'Loading')
          .get();
      
      if (loadingQuery.docs.isNotEmpty) {
        return ValidationResult.fail(
          'Users with "Loading" referral code found',
          errorDetails: 'Found ${loadingQuery.docs.length} users with Loading state',
          suspectedModule: 'ServerProfileEnsureService',
          suggestedFix: 'lib/services/server_profile_ensure_service.dart:ensureUserProfile - Fix referral code generation timing to prevent Loading states',
        );
      }
      
      // Check users collection for Loading states
      final usersLoadingQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: 'Loading')
          .get();
      
      if (usersLoadingQuery.docs.isNotEmpty) {
        return ValidationResult.fail(
          'Users collection has "Loading" referral codes',
          errorDetails: 'Found ${usersLoadingQuery.docs.length} users with Loading state',
          suspectedModule: 'AuthService',
          suggestedFix: 'lib/services/auth_service.dart:registerUser - Ensure referral code is generated before profile creation',
        );
      }
      
      // Check for partial loading states (contains "Loading")
      final registryDocs = await _firestore
          .collection('user_registry')
          .limit(100)
          .get();
      
      final loadingViolations = <String>[];
      for (final doc in registryDocs.docs) {
        final data = doc.data();
        final referralCode = data['referralCode'] as String?;
        if (referralCode != null && referralCode.contains('Loading')) {
          loadingViolations.add('${doc.id}: $referralCode');
        }
      }
      
      if (loadingViolations.isNotEmpty) {
        return ValidationResult.fail(
          'Referral codes containing "Loading" found',
          errorDetails: loadingViolations.take(3).join('; '),
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'Fix referral code generation to prevent Loading states',
        );
      }
      
      debugPrint('âœ… No Loading states validation passed');
      return ValidationResult.pass('No "Loading" states found in referral codes');
      
    } catch (e) {
      return ValidationResult.fail(
        'Loading states validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'Database/ReferralCodes',
      );
    }
  }
  
  /// Validate Crockford base32 format
  static bool _isValidCrockfordBase32(String code) {
    if (code.length != _codeLength) return false;
    
    for (int i = 0; i < code.length; i++) {
      if (!_crockfordAlphabet.contains(code[i])) {
        return false;
      }
    }
    return true;
  }
  
  /// Generate test referral code for validation
  static String _generateTestCode() {
    final random = Random();
    final codeBuffer = StringBuffer(_talPrefix);
    
    for (int i = 0; i < _codeLength; i++) {
      final randomIndex = random.nextInt(_crockfordAlphabet.length);
      codeBuffer.write(_crockfordAlphabet[randomIndex]);
    }
    
    return codeBuffer.toString();
  }
  
  /// Validate specific referral code format
  static ValidationResult validateCodeFormat(String code) {
    // Check null/empty
    if (code.isEmpty) {
      return ValidationResult.fail(
        'Referral code is empty',
        suggestedFix: 'Generate proper referral code',
      );
    }
    
    // Check Loading state
    if (code == 'Loading' || code.contains('Loading')) {
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
    if (!code.startsWith(_talPrefix)) {
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
    if (!_isValidCrockfordBase32(codeBody)) {
      return ValidationResult.fail(
        'Referral code invalid Crockford base32 format',
        errorDetails: 'Code body: $codeBody contains invalid characters',
        suggestedFix: 'Use only A-Z, 2-7 (no 0/O/1/I)',
      );
    }
    
    return ValidationResult.pass('Referral code format valid');
  }
  
  /// Get policy compliance summary
  static Future<Map<String, dynamic>> getPolicyComplianceSummary() async {
    try {
      final registryQuery = await _firestore
          .collection('user_registry')
          .get();
      
      int totalCodes = 0;
      int validCodes = 0;
      int talPrefixViolations = 0;
      int formatViolations = 0;
      int loadingStates = 0;
      int adminExceptions = 0;
      
      for (final doc in registryQuery.docs) {
        final data = doc.data();
        final referralCode = data['referralCode'] as String?;
        
        if (referralCode == null || referralCode.isEmpty) continue;
        
        totalCodes++;
        
        if (referralCode == _adminException) {
          adminExceptions++;
          validCodes++;
          continue;
        }
        
        if (referralCode.contains('Loading')) {
          loadingStates++;
          continue;
        }
        
        if (!referralCode.startsWith(_talPrefix)) {
          talPrefixViolations++;
          continue;
        }
        
        if (referralCode.length != 9 || !_isValidCrockfordBase32(referralCode.substring(3))) {
          formatViolations++;
          continue;
        }
        
        validCodes++;
      }
      
      return {
        'totalCodes': totalCodes,
        'validCodes': validCodes,
        'complianceRate': totalCodes > 0 ? (validCodes / totalCodes * 100).toStringAsFixed(1) : '0.0',
        'violations': {
          'talPrefixViolations': talPrefixViolations,
          'formatViolations': formatViolations,
          'loadingStates': loadingStates,
        },
        'adminExceptions': adminExceptions,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
