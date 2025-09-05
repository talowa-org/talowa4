// Standalone test runner for existing user login validation (Test Case C)
// Run this file to test only the existing user login functionality

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'existing_user_login_validator.dart';
import 'test_environment.dart';
import 'validation_framework.dart';

void main() async {
  group('Existing User Login Validation (Test Case C)', () {
    setUpAll(() async {
      debugPrint('ðŸ”§ Setting up test environment for existing user login validation...');
      await TestEnvironment.initialize();
    });

    tearDownAll(() async {
      debugPrint('ðŸ§¹ Cleaning up test environment...');
      await TestEnvironment.cleanup();
    });

    test('Test Case C: Existing User Login with Email Format + PIN', () async {
      debugPrint('ðŸ§ª Starting Test Case C: Existing User Login Validation');
      
      final result = await ExistingUserLoginValidator.validateExistingUserLogin();
      
      debugPrint('ðŸ“Š Test Result: ${result.passed ? 'PASS' : 'FAIL'}');
      debugPrint('ðŸ“ Message: ${result.message}');
      
      if (!result.passed) {
        debugPrint('âŒ Error Details: ${result.errorDetails}');
        debugPrint('ðŸ”§ Suspected Module: ${result.suspectedModule}');
        debugPrint('ðŸ’¡ Suggested Fix: ${result.suggestedFix}');
      }
      
      expect(result.passed, isTrue, reason: result.message);
    });

    test('Quick Existing User Login Validation', () async {
      debugPrint('âš¡ Running quick existing user login validation...');
      
      final result = await ExistingUserLoginValidator.quickValidation();
      
      debugPrint('ðŸ“Š Quick Test Result: ${result.passed ? 'PASS' : 'FAIL'}');
      debugPrint('ðŸ“ Message: ${result.message}');
      
      if (!result.passed) {
        debugPrint('âŒ Error Details: ${result.errorDetails}');
        debugPrint('ðŸ”§ Suspected Module: ${result.suspectedModule}');
        debugPrint('ðŸ’¡ Suggested Fix: ${result.suggestedFix}');
      }
      
      expect(result.passed, isTrue, reason: result.message);
    });

    test('Comprehensive Existing User Login Validation', () async {
      debugPrint('ðŸ” Running comprehensive existing user login validation...');
      
      final result = await ExistingUserLoginValidator.runComprehensiveValidation();
      
      debugPrint('ðŸ“Š Comprehensive Test Result: ${result.passed ? 'PASS' : 'FAIL'}');
      debugPrint('ðŸ“ Message: ${result.message}');
      
      if (!result.passed) {
        debugPrint('âŒ Error Details: ${result.errorDetails}');
        debugPrint('ðŸ”§ Suspected Module: ${result.suspectedModule}');
        debugPrint('ðŸ’¡ Suggested Fix: ${result.suggestedFix}');
      }
      
      // Allow warnings but not failures
      expect(result.passed, isTrue, reason: result.message);
    });
  });
}

/// Standalone execution function for command line testing
Future<void> runStandaloneTest() async {
  debugPrint('ðŸš€ Starting standalone existing user login validation...');
  
  try {
    // Initialize test environment
    await TestEnvironment.initialize();
    
    // Run validation
    final result = await ExistingUserLoginValidator.validateExistingUserLogin();
    
    // Generate report
    final report = ValidationReport();
    report.addResult('Test Case C', result);
    
    debugPrint('\n${report.generateReport()}');
    
    // Cleanup
    await TestEnvironment.cleanup();
    
    if (result.passed) {
      debugPrint('âœ… Existing user login validation PASSED');
    } else {
      debugPrint('âŒ Existing user login validation FAILED');
    }
    
  } catch (e) {
    debugPrint('ðŸ’¥ Standalone test execution failed: $e');
  }
}
