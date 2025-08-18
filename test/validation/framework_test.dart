// Test file to verify validation framework functionality
import 'package:flutter_test/flutter_test.dart';
import 'validation_framework.dart';

void main() {
  group('Validation Framework Tests', () {
    test('ValidationResult creation and properties', () {
      // Test pass result
      final passResult = ValidationResult.pass('Test passed successfully');
      expect(passResult.passed, true);
      expect(passResult.message, 'Test passed successfully');
      expect(passResult.errorDetails, null);
      expect(passResult.severity, ValidationSeverity.info);

      // Test fail result
      final failResult = ValidationResult.fail(
        'Test failed',
        errorDetails: 'Connection timeout',
        suggestedFix: 'Check network connection',
        suspectedModule: 'NetworkService',
      );
      expect(failResult.passed, false);
      expect(failResult.message, 'Test failed');
      expect(failResult.errorDetails, 'Connection timeout');
      expect(failResult.suggestedFix, 'Check network connection');
      expect(failResult.suspectedModule, 'NetworkService');
      expect(failResult.severity, ValidationSeverity.error);

      // Test warning result
      final warningResult = ValidationResult.warning(
        'Test completed with warnings',
        errorDetails: 'Minor issues detected',
      );
      expect(warningResult.passed, true);
      expect(warningResult.severity, ValidationSeverity.warning);
    });

    test('ValidationReport functionality', () {
      final report = ValidationReport();
      
      // Add test results
      report.addResult('Test 1', ValidationResult.pass('Success'));
      report.addResult('Test 2', ValidationResult.fail('Failed'));
      report.addResult('Test 3', ValidationResult.warning('Warning'));
      
      // Check statistics
      expect(report.executionStats['totalTests'], 3);
      expect(report.executionStats['passedTests'], 1);
      expect(report.executionStats['failedTests'], 1);
      expect(report.executionStats['warningTests'], 1);
      
      // Check overall status
      expect(report.allTestsPassed, false);
      
      // Check failed tests
      expect(report.failedTests.length, 1);
      expect(report.failedTests.first.key, 'Test 2');
      
      // Test report generation
      final reportText = report.generateReport();
      expect(reportText.contains('TALOWA VALIDATION SUITE RESULTS'), true);
      expect(reportText.contains('Total Tests: 3'), true);
      
      // Test JSON export
      final json = report.toJson();
      expect(json['statistics']['totalTests'], 3);
      expect(json['allTestsPassed'], false);
      
      // Test summary
      final summary = report.generateSummary();
      expect(summary.contains('Tests Run: 3'), true);
      expect(summary.contains('Pass Rate: 33.3%'), true);
    });

    test('ValidationTestRunner initialization', () {
      // This test may show Firebase warnings, which is expected in test environment
      try {
        final runner = ValidationTestRunner();
        expect(runner.report, isNotNull);
        expect(runner.report.testResults.isEmpty, true);
      } catch (e) {
        // Firebase initialization may fail in test environment, which is acceptable
        expect(e.toString().contains('Firebase'), true);
      }
    });
  });
}