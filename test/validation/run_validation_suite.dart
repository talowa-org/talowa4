// TALOWA Validation Suite Runner
// Main entry point for executing complete validation suite

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'comprehensive_validator.dart';
import 'validation_framework.dart';
import 'admin_bootstrap_validator.dart';
import 'navigation_validator.dart';
import 'otp_validator.dart';
import 'test_environment.dart';

/// Main validation suite runner
class ValidationSuiteRunner {
  
  /// Run complete TALOWA validation suite
  static Future<void> main() async {
    print('🚀 TALOWA VALIDATION SUITE');
    print('=' * 50);
    print('Executing comprehensive validation for login, registration, and referral systems');
    print('Tasks: Phase 1 (1.1-1.3) through Phase 6 (6.1-6.2)');
    print('=' * 50);
    
    final startTime = DateTime.now();
    
    try {
      // Execute complete validation suite
      final report = await ComprehensiveValidator.runCompleteValidationSuite();
      
      // Print detailed results
      print('\n📊 VALIDATION RESULTS');
      print('=' * 50);
      print(report.generateReport());
      
      // Print statistics
      final stats = ComprehensiveValidator.getValidationStatistics();
      print('\n📈 EXECUTION STATISTICS');
      print('=' * 30);
      print('Total Tests: ${stats['totalTests']}');
      print('Passed: ${stats['passedTests']}');
      print('Failed: ${stats['failedTests']}');
      print('Success Rate: ${stats['successRate']}%');
      print('Execution Time: ${stats['executionTime']}s');
      
      // Final verdict
      print('\n🎯 FINAL VERDICT');
      print('=' * 20);
      if (stats['flowMatchesSpec'] == true) {
        print('✅ FLOW MATCHES SPEC: YES');
        print('🎉 All validation tests passed successfully!');
        print('🚀 TALOWA is ready for production deployment.');
      } else {
        print('❌ FLOW MATCHES SPEC: NO');
        print('⚠️  Some validation tests failed.');
        print('🔧 Review failed tests and apply suggested fixes.');
        
        // List failed tests
        if (report.failedTests.isNotEmpty) {
          print('\n❌ FAILED TESTS:');
          for (final entry in report.failedTests) {
            print('  • ${entry.key}: ${entry.value.message}');
            if (entry.value.suggestedFix != null) {
              print('    Fix: ${entry.value.suggestedFix}');
            }
          }
        }
      }
      
      // Save report to file
      await _saveReportToFile(report, stats);
      
      final endTime = DateTime.now();
      final totalDuration = endTime.difference(startTime);
      print('\n⏱️  Total execution time: ${totalDuration.inSeconds}s');
      
    } catch (e) {
      print('\n❌ VALIDATION SUITE FAILED');
      print('Error: $e');
      exit(1);
    }
  }

  /// Save validation report to file
  static Future<void> _saveReportToFile(ValidationReport report, Map<String, dynamic> stats) async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'validation_report_$timestamp.md';
      
      final reportContent = _generateMarkdownReport(report, stats);
      
      // In a real implementation, this would save to file system
      debugPrint('📄 Validation report would be saved to: $filename');
      debugPrint('Report content length: ${reportContent.length} characters');
      
    } catch (e) {
      debugPrint('⚠️ Failed to save report to file: $e');
    }
  }

  /// Generate markdown report
  static String _generateMarkdownReport(ValidationReport report, Map<String, dynamic> stats) {
    final buffer = StringBuffer();
    
    buffer.writeln('# TALOWA Validation Report');
    buffer.writeln();
    buffer.writeln('**Generated**: ${DateTime.now().toIso8601String()}');
    buffer.writeln('**Execution Time**: ${stats['executionTime']}s');
    buffer.writeln('**Success Rate**: ${stats['successRate']}%');
    buffer.writeln();
    
    buffer.writeln('## Executive Summary');
    buffer.writeln();
    if (stats['flowMatchesSpec'] == true) {
      buffer.writeln('✅ **FLOW MATCHES SPEC: YES**');
      buffer.writeln();
      buffer.writeln('All validation tests passed successfully. TALOWA is ready for production deployment.');
    } else {
      buffer.writeln('❌ **FLOW MATCHES SPEC: NO**');
      buffer.writeln();
      buffer.writeln('Some validation tests failed. Review and apply suggested fixes before production deployment.');
    }
    buffer.writeln();
    
    buffer.writeln('## Test Results Summary');
    buffer.writeln();
    buffer.writeln('| Test Case | Status | Message |');
    buffer.writeln('|-----------|--------|---------|');
    
    for (final entry in report.testResults.entries) {
      final status = entry.value.passed ? '✅ PASS' : '❌ FAIL';
      final message = entry.value.message.replaceAll('|', '\\|');
      buffer.writeln('| ${entry.key} | $status | $message |');
    }
    buffer.writeln();
    
    buffer.writeln('## Admin Bootstrap Status');
    buffer.writeln();
    buffer.writeln('**Admin bootstrap verified**: ${report.adminBootstrapVerified ? "YES" : "NO"}');
    buffer.writeln();
    
    if (report.failedTests.isNotEmpty) {
      buffer.writeln('## Failed Tests Analysis');
      buffer.writeln();
      
      for (final entry in report.failedTests) {
        buffer.writeln('### ${entry.key}');
        buffer.writeln();
        buffer.writeln('**Error**: ${entry.value.message}');
        if (entry.value.errorDetails != null) {
          buffer.writeln();
          buffer.writeln('**Details**: ${entry.value.errorDetails}');
        }
        if (entry.value.suspectedModule != null) {
          buffer.writeln();
          buffer.writeln('**Suspected Module**: ${entry.value.suspectedModule}');
        }
        if (entry.value.suggestedFix != null) {
          buffer.writeln();
          buffer.writeln('**Suggested Fix**: ${entry.value.suggestedFix}');
        }
        buffer.writeln();
      }
    }
    
    buffer.writeln('## Validation Statistics');
    buffer.writeln();
    buffer.writeln('- **Total Tests**: ${stats['totalTests']}');
    buffer.writeln('- **Passed Tests**: ${stats['passedTests']}');
    buffer.writeln('- **Failed Tests**: ${stats['failedTests']}');
    buffer.writeln('- **Success Rate**: ${stats['successRate']}%');
    buffer.writeln('- **Admin Bootstrap**: ${stats['adminBootstrapVerified'] ? "Verified" : "Not Verified"}');
    buffer.writeln('- **Flow Matches Spec**: ${stats['flowMatchesSpec'] ? "YES" : "NO"}');
    buffer.writeln();
    
    buffer.writeln('## Next Steps');
    buffer.writeln();
    if (stats['flowMatchesSpec'] == true) {
      buffer.writeln('1. ✅ All validation tests passed');
      buffer.writeln('2. 🚀 TALOWA is ready for production deployment');
      buffer.writeln('3. 📊 Monitor production metrics and user feedback');
      buffer.writeln('4. 🔄 Schedule regular validation runs');
    } else {
      buffer.writeln('1. 🔧 Apply suggested fixes for failed tests');
      buffer.writeln('2. 🧪 Re-run validation suite after fixes');
      buffer.writeln('3. ✅ Ensure all tests pass before production');
      buffer.writeln('4. 📋 Update documentation with any changes');
    }
    buffer.writeln();
    
    buffer.writeln('---');
    buffer.writeln('*Generated by TALOWA Validation Suite*');
    
    return buffer.toString();
  }

  /// Quick validation check (subset of tests)
  static Future<bool> quickValidationCheck() async {
    try {
      debugPrint('⚡ Running quick validation check...');
      
      // Run critical tests only
      final report = ValidationReport();
      
      // Check admin bootstrap
      final adminResult = await AdminBootstrapValidator.verifyAdminBootstrap();
      report.addResult('Admin Bootstrap', adminResult);
      report.adminBootstrapVerified = adminResult.passed;
      
      // Check navigation
      final navResult = await NavigationValidator.validateTopLevelNavigation();
      report.addResult('Navigation', navResult);
      
      // Check basic security
      final securityPassed = await TestEnvironment.testSecurityRules();
      report.addResult('Security', securityPassed 
          ? ValidationResult.pass('Security rules enforced')
          : ValidationResult.fail('Security rules not enforced'));
      
      final allPassed = report.allTestsPassed && report.adminBootstrapVerified;
      
      debugPrint(allPassed 
          ? '✅ Quick validation passed' 
          : '❌ Quick validation failed');
      
      return allPassed;
      
    } catch (e) {
      debugPrint('❌ Quick validation check failed: $e');
      return false;
    }
  }

  /// Validate specific test case
  static Future<ValidationResult> validateSpecificTestCase(String testCase) async {
    try {
      debugPrint('🎯 Running specific test case: $testCase');
      
      switch (testCase.toUpperCase()) {
        case 'A':
          return await NavigationValidator.validateTopLevelNavigation();
        case 'B1':
          return await OTPValidator.validateOTPVerification();
        case 'ADMIN':
          return await AdminBootstrapValidator.verifyAdminBootstrap();
        default:
          return ValidationResult.fail('Unknown test case: $testCase');
      }
    } catch (e) {
      return ValidationResult.fail(
        'Specific test case validation failed',
        errorDetails: e.toString(),
      );
    }
  }
}

/// Entry point for running validation suite
Future<void> main() async {
  await ValidationSuiteRunner.main();
}