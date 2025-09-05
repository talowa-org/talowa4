// Test runner for Referral Code Policy Validation (Test Case E)
// This file allows testing the referral code policy validator independently

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'referral_code_policy_validator.dart';

void main() {
  group('Referral Code Policy Validation Tests', () {
    setUpAll(() async {
      // Initialize Firebase for testing
      try {
        await Firebase.initializeApp();
      } catch (e) {
        print('Firebase already initialized or not available: $e');
      }
    });

    test('Test Case E: Referral Code Policy Validation', () async {
      print('ðŸ§ª Running Test Case E: Referral Code Policy Validation...');
      
      final result = await ReferralCodePolicyValidator.validateReferralCodePolicy();
      
      print('Result: ${result.toString()}');
      
      if (result.passed) {
        print('âœ… Test Case E PASSED: ${result.message}');
      } else {
        print('âŒ Test Case E FAILED: ${result.message}');
        if (result.errorDetails != null) {
          print('   Error Details: ${result.errorDetails}');
        }
        if (result.suggestedFix != null) {
          print('   Suggested Fix: ${result.suggestedFix}');
        }
      }
      
      expect(result.passed, isTrue, reason: result.message);
    });

    test('Validate specific referral code formats', () async {
      print('ðŸ§ª Testing specific referral code formats...');
      
      // Test valid codes
      final validCodes = [
        'TALABC234',
        'TALXYZ567',
        'TAL2A3B4C',
        'TALADMIN', // Admin exception
      ];
      
      for (final code in validCodes) {
        final result = ReferralCodePolicyValidator.validateCodeFormat(code);
        print('Code "$code": ${result.passed ? "VALID" : "INVALID"} - ${result.message}');
        
        if (code == 'TALADMIN') {
          expect(result.passed, isTrue, reason: 'TALADMIN should be allowed as exception');
        } else {
          expect(result.passed, isTrue, reason: 'Valid code "$code" should pass validation');
        }
      }
      
      // Test invalid codes
      final invalidCodes = [
        'ABC123456', // Missing TAL prefix
        'TAL12345', // Too short
        'TAL1234567', // Too long
        'TALOI1234', // Contains O, I (invalid Crockford)
        'Loading', // Loading state
        'TALLoading', // Contains Loading
        '', // Empty
      ];
      
      for (final code in invalidCodes) {
        final result = ReferralCodePolicyValidator.validateCodeFormat(code);
        print('Code "$code": ${result.passed ? "VALID" : "INVALID"} - ${result.message}');
        expect(result.passed, isFalse, reason: 'Invalid code "$code" should fail validation');
      }
    });

    test('Get policy compliance summary', () async {
      print('ðŸ§ª Getting policy compliance summary...');
      
      final summary = await ReferralCodePolicyValidator.getPolicyComplianceSummary();
      
      print('Policy Compliance Summary:');
      print('  Total Codes: ${summary['totalCodes']}');
      print('  Valid Codes: ${summary['validCodes']}');
      print('  Compliance Rate: ${summary['complianceRate']}%');
      print('  Admin Exceptions: ${summary['adminExceptions']}');
      
      if (summary['violations'] != null) {
        final violations = summary['violations'] as Map<String, dynamic>;
        print('  Violations:');
        print('    TAL Prefix: ${violations['talPrefixViolations']}');
        print('    Format: ${violations['formatViolations']}');
        print('    Loading States: ${violations['loadingStates']}');
      }
      
      expect(summary['totalCodes'], greaterThanOrEqualTo(0));
      expect(summary['validCodes'], greaterThanOrEqualTo(0));
    });
  });
}
