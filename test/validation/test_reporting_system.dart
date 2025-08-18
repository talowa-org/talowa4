// Test script to verify the enhanced reporting system
// This demonstrates the new reporting capabilities

import 'package:flutter/foundation.dart';
import 'validation_framework.dart';
import 'validation_report_service.dart';

/// Test the enhanced reporting system
Future<void> testReportingSystem() async {
  debugPrint('🧪 Testing Enhanced Reporting System...');
  
  // Create a sample validation report with mixed results
  final report = ValidationReport();
  
  // Add some successful test results
  report.addResult('Test Case A', ValidationResult.pass('Navigation buttons functional'));
  report.addResult('Test Case B1', ValidationResult.pass('OTP verification working'));
  report.addResult('Test Case B2', ValidationResult.pass('Registration form creates profile correctly'));
  
  // Add some failed test results with detailed information
  report.addResult('Test Case C', ValidationResult.fail(
    'Existing user login failed',
    errorDetails: 'Authentication service returned 401 Unauthorized',
    suspectedModule: 'AuthService',
    suggestedFix: 'lib/services/auth_service.dart:loginUser - Fix PIN validation logic',
  ));
  
  report.addResult('Test Case D', ValidationResult.fail(
    'Deep link auto-fill not working',
    errorDetails: 'Referral code not extracted from URL parameters',
    suspectedModule: 'WebReferralRouter',
    suggestedFix: 'lib/services/referral/web_referral_router.dart:parseReferralCodeFromUrl - Fix URL parsing regex',
    severity: ValidationSeverity.error,
  ));
  
  // Add a warning result
  report.addResult('Test Case E', ValidationResult.warning(
    'Referral code policy mostly compliant',
    errorDetails: 'Some codes missing TAL prefix in test data',
    suspectedModule: 'ReferralCodeGenerator',
    suggestedFix: 'lib/services/referral/referral_code_generator.dart:generateUniqueCode - Ensure TAL prefix always added',
  ));
  
  // Set admin bootstrap status
  report.adminBootstrapVerified = true;
  
  debugPrint('📊 Report Statistics:');
  debugPrint('- Total Tests: ${report.executionStats['totalTests']}');
  debugPrint('- Passed: ${report.executionStats['passedTests']}');
  debugPrint('- Failed: ${report.executionStats['failedTests']}');
  debugPrint('- Warnings: ${report.executionStats['warningTests']}');
  
  // Test the enhanced report generation
  debugPrint('\n📋 Testing Enhanced Report Generation...');
  
  try {
    // Generate comprehensive report
    final comprehensiveReport = report.generateReport();
    debugPrint('✅ Comprehensive report generated (${comprehensiveReport.length} characters)');
    
    // Generate detailed execution log
    final executionLog = report.generateDetailedExecutionLog();
    debugPrint('✅ Detailed execution log generated (${executionLog.length} characters)');
    
    // Generate fix suggestions report
    final fixSuggestions = report.generateFixSuggestionsReport();
    debugPrint('✅ Fix suggestions report generated (${fixSuggestions.length} characters)');
    
    // Test ValidationReportService
    debugPrint('\n🔧 Testing ValidationReportService...');
    
    await ValidationReportService.generateAllReports(
      report,
      executionLog: [
        '[2025-08-18T10:00:00] 🚀 Starting TALOWA Validation Suite...',
        '[2025-08-18T10:00:01] 🔧 Initializing test environment...',
        '[2025-08-18T10:00:02] 🧪 Running Test Case A: Navigation...',
        '[2025-08-18T10:00:03] ✅ Test Case A passed',
        '[2025-08-18T10:00:04] 🧪 Running Test Case C: Login...',
        '[2025-08-18T10:00:05] ❌ Test Case C failed: Authentication error',
        '[2025-08-18T10:00:06] 📊 Generating reports...',
      ],
      metadata: {
        'testEnvironment': 'Development',
        'firebaseProject': 'talowa-test',
        'dartVersion': '3.0.0',
        'flutterVersion': '3.10.0',
      },
    );
    
    // Test CI/CD export
    final cicdData = ValidationReportService.exportForCICD(report);
    debugPrint('✅ CI/CD export generated with ${cicdData.keys.length} top-level keys');
    
    // Test summary report
    final summaryReport = ValidationReportService.generateSummaryReport(report);
    debugPrint('✅ Summary report generated (${summaryReport.length} characters)');
    
    debugPrint('\n🎉 All reporting system tests passed!');
    
    // Display sample output
    debugPrint('\n📄 Sample Report Output:');
    debugPrint('=' * 50);
    debugPrint(report.generateSummary());
    debugPrint('=' * 50);
    
  } catch (e) {
    debugPrint('❌ Reporting system test failed: $e');
    rethrow;
  }
}

/// Main function to run the test
Future<void> main() async {
  await testReportingSystem();
}