// Simple test runner for NavigationValidator
import 'dart:io';
import 'navigation_validator.dart';

void main() async {
  print('🧪 Running Navigation Validation Test...');
  
  try {
    final result = await NavigationValidator.validateTopLevelNavigation();
    
    print('\n=== NAVIGATION VALIDATION RESULT ===');
    print('Status: ${result.passed ? "PASS" : "FAIL"}');
    print('Message: ${result.message}');
    
    if (!result.passed) {
      if (result.errorDetails != null) {
        print('Error Details: ${result.errorDetails}');
      }
      if (result.suspectedModule != null) {
        print('Suspected Module: ${result.suspectedModule}');
      }
      if (result.suggestedFix != null) {
        print('Suggested Fix: ${result.suggestedFix}');
      }
    }
    
    print('\n=== COMPREHENSIVE NAVIGATION TEST ===');
    final comprehensiveResult = await NavigationValidator.runComprehensiveNavigationTest();
    
    print('Status: ${comprehensiveResult.passed ? "PASS" : "FAIL"}');
    print('Message: ${comprehensiveResult.message}');
    
    if (!comprehensiveResult.passed) {
      if (comprehensiveResult.errorDetails != null) {
        print('Error Details: ${comprehensiveResult.errorDetails}');
      }
      if (comprehensiveResult.suspectedModule != null) {
        print('Suspected Module: ${comprehensiveResult.suspectedModule}');
      }
      if (comprehensiveResult.suggestedFix != null) {
        print('Suggested Fix: ${comprehensiveResult.suggestedFix}');
      }
    }
    
    print('\n=== NAVIGATION SUMMARY ===');
    final summary = NavigationValidator.getNavigationSummary();
    print('Test Case: ${summary['testCase']}');
    print('Description: ${summary['description']}');
    print('Components: ${summary['components'].length} validated');
    print('Requirements: ${summary['requirements'].length} checked');
    
    // Exit with appropriate code
    exit(result.passed && comprehensiveResult.passed ? 0 : 1);
    
  } catch (e) {
    print('❌ Navigation validation failed with error: $e');
    exit(1);
  }
}