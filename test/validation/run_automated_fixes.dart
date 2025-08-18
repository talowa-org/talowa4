// TALOWA Automated Fix Application Runner
// Main entry point for applying automated fixes to failed validation tests

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'validation_framework.dart';
import 'automated_fix_service.dart';
import 'fix_suggestion_service.dart';
import 'validation_report_service.dart';
import 'comprehensive_validator.dart';

/// Main function to run automated fix application
Future<void> main() async {
  print('🔧 TALOWA Automated Fix Application System');
  print('=' * 60);
  
  try {
    // Step 1: Run validation suite to identify failures
    print('\n📊 Step 1: Running validation suite to identify failures...');
    final initialReport = await ComprehensiveValidator.runCompleteValidationSuite(
      enableRetries: false, // Don't apply fixes yet
      stopOnFirstFailure: false,
    );
    
    print('Initial validation completed:');
    print('- Total Tests: ${initialReport.executionStats['totalTests']}');
    print('- Failed Tests: ${initialReport.executionStats['failedTests']}');
    print('- Success Rate: ${initialReport._calculateSuccessRate()}%');
    
    if (initialReport.allTestsPassed) {
      print('\n✅ All tests passed - no fixes needed!');
      return;
    }
    
    // Step 2: Generate fix suggestions
    print('\n💡 Step 2: Generating fix suggestions...');
    final fixSuggestions = FixSuggestionService.generateFixSuggestions(initialReport);
    print('Generated ${fixSuggestions.length} fix suggestions');
    
    // Step 3: Apply automated fixes
    print('\n🔧 Step 3: Applying automated fixes...');
    final fixResult = await AutomatedFixService.applyFixesForFailedTests(
      initialReport,
      dryRun: false,
      enableRollback: true,
    );
    
    print('Fix application completed:');
    print('- Total Fixes Attempted: ${fixResult.totalFixes}');
    print('- Successful Fixes: ${fixResult.successfulFixes}');
    print('- Failed Fixes: ${fixResult.failedFixes}');
    
    // Step 4: Re-run validation to verify fixes
    print('\n🔍 Step 4: Re-running validation to verify fixes...');
    final finalReport = await ComprehensiveValidator.runCompleteValidationSuite(
      enableRetries: false,
      stopOnFirstFailure: false,
    );
    
    print('Final validation completed:');
    print('- Total Tests: ${finalReport.executionStats['totalTests']}');
    print('- Failed Tests: ${finalReport.executionStats['failedTests']}');
    print('- Success Rate: ${finalReport._calculateSuccessRate()}%');
    
    // Step 5: Generate comprehensive reports
    print('\n📋 Step 5: Generating comprehensive reports...');
    await ValidationReportService.generateAllReports(
      finalReport,
      executionLog: _generateExecutionLog(initialReport, fixResult, finalReport),
      metadata: {
        'fixApplicationEnabled': true,
        'initialFailures': initialReport.executionStats['failedTests'],
        'finalFailures': finalReport.executionStats['failedTests'],
        'fixesApplied': fixResult.successfulFixes,
        'automatedFixVersion': 'AutomatedFixService v1.0',
      },
    );
    
    // Step 6: Display final results
    print('\n📊 FINAL RESULTS:');
    print('=' * 40);
    
    final improvement = (initialReport.executionStats['failedTests']! - 
                        finalReport.executionStats['failedTests']!);
    
    if (finalReport.allTestsPassed && finalReport.adminBootstrapVerified) {
      print('🎉 SUCCESS: All tests now pass!');
      print('✅ Production ready: YES');
      print('🔧 Fixes resolved: $improvement issue(s)');
    } else {
      print('⚠️ PARTIAL SUCCESS: Some issues remain');
      print('❌ Production ready: NO');
      print('🔧 Fixes resolved: $improvement issue(s)');
      print('📋 Remaining issues: ${finalReport.executionStats['failedTests']}');
      
      // Show remaining issues
      if (finalReport.failedTests.isNotEmpty) {
        print('\nRemaining Issues:');
        for (final entry in finalReport.failedTests) {
          print('- ${entry.key}: ${entry.value.message}');
        }
      }
    }
    
    print('\n📄 Reports generated:');
    print('- validation_execution_log.md');
    print('- validation_report.md');
    print('- validation_fix_suggestions.md');
    
    print('\n' + '=' * 60);
    print('Automated Fix Application Complete');
    
  } catch (e) {
    print('❌ Automated fix application failed: $e');
    print('\nThis may indicate a critical system issue that requires manual intervention.');
  }
}

/// Run automated fixes with specific configuration
Future<FixApplicationResult> runAutomatedFixes({
  bool dryRun = false,
  bool enableRollback = true,
  List<String>? onlyTests,
  bool verbose = false,
}) async {
  if (verbose) {
    debugPrint('🔧 Running automated fixes with configuration:');
    debugPrint('- Dry Run: $dryRun');
    debugPrint('- Enable Rollback: $enableRollback');
    debugPrint('- Only Tests: ${onlyTests?.join(', ') ?? 'All'}');
  }
  
  try {
    // Run initial validation
    final initialReport = await ComprehensiveValidator.runCompleteValidationSuite(
      enableRetries: false,
      stopOnFirstFailure: false,
      specificTests: onlyTests,
    );
    
    if (initialReport.allTestsPassed) {
      if (verbose) debugPrint('✅ All tests passed - no fixes needed');
      return FixApplicationResult()..addFixResult('No Fixes Needed', 
        FixResult.success('All tests passed - no fixes required'));
    }
    
    // Apply fixes
    final fixResult = await AutomatedFixService.applyFixesForFailedTests(
      initialReport,
      dryRun: dryRun,
      enableRollback: enableRollback,
    );
    
    if (verbose) {
      debugPrint('🔧 Fix application completed:');
      debugPrint('- Successful: ${fixResult.successfulFixes}');
      debugPrint('- Failed: ${fixResult.failedFixes}');
    }
    
    return fixResult;
    
  } catch (e) {
    if (verbose) debugPrint('❌ Automated fix execution failed: $e');
    
    final errorResult = FixApplicationResult();
    errorResult.addFixResult('Fix Execution Error', FixResult.error(
      'Automated fix execution failed',
      errorDetails: e.toString(),
    ));
    return errorResult;
  }
}

/// Run fix application in dry-run mode to preview changes
Future<FixApplicationResult> previewAutomatedFixes() async {
  debugPrint('👁️ Running automated fixes in preview mode...');
  
  return await runAutomatedFixes(
    dryRun: true,
    enableRollback: false,
    verbose: true,
  );
}

/// Apply fixes for specific test cases only
Future<FixApplicationResult> applyFixesForSpecificTests(List<String> testNames) async {
  debugPrint('🎯 Applying fixes for specific tests: ${testNames.join(', ')}');
  
  return await runAutomatedFixes(
    dryRun: false,
    enableRollback: true,
    onlyTests: testNames,
    verbose: true,
  );
}

/// Generate execution log for fix application process
List<String> _generateExecutionLog(
  ValidationReport initialReport,
  FixApplicationResult fixResult,
  ValidationReport finalReport,
) {
  final log = <String>[];
  final timestamp = DateTime.now().toIso8601String();
  
  log.add('[$timestamp] 🔧 Automated Fix Application Started');
  log.add('[$timestamp] 📊 Initial validation: ${initialReport.executionStats['failedTests']} failures');
  
  // Log fix attempts
  for (final entry in fixResult.fixResults.entries) {
    final testName = entry.key;
    final result = entry.value;
    final status = result.success ? 'SUCCESS' : 'FAILED';
    log.add('[$timestamp] 🔧 Fix for $testName: $status - ${result.message}');
  }
  
  log.add('[$timestamp] 🔍 Final validation: ${finalReport.executionStats['failedTests']} failures');
  log.add('[$timestamp] ✅ Automated Fix Application Completed');
  
  return log;
}

/// Rollback all applied fixes (emergency function)
Future<RollbackResult> emergencyRollback() async {
  print('🚨 EMERGENCY ROLLBACK: Rolling back all applied fixes...');
  
  try {
    final rollbackResult = await AutomatedFixService.rollbackAllFixes();
    
    print('Rollback completed:');
    print('- Total Rollbacks: ${rollbackResult.totalRollbacks}');
    print('- Successful: ${rollbackResult.successfulRollbacks}');
    print('- Failed: ${rollbackResult.failedRollbacks}');
    
    if (rollbackResult.allRollbacksSuccessful) {
      print('✅ All fixes rolled back successfully');
    } else {
      print('⚠️ Some rollbacks failed - manual intervention may be required');
    }
    
    return rollbackResult;
    
  } catch (e) {
    print('❌ Emergency rollback failed: $e');
    print('🚨 CRITICAL: Manual intervention required immediately');
    rethrow;
  }
}

/// Display fix application help
void displayHelp() {
  print('''
TALOWA Automated Fix Application System

USAGE:
  dart test/validation/run_automated_fixes.dart

FUNCTIONS:
  main()                           - Run complete fix application process
  runAutomatedFixes()             - Run with custom configuration
  previewAutomatedFixes()         - Preview fixes without applying
  applyFixesForSpecificTests()    - Apply fixes for specific tests only
  emergencyRollback()             - Rollback all applied fixes

EXAMPLES:
  // Preview fixes
  final preview = await previewAutomatedFixes();
  
  // Apply fixes for specific tests
  final result = await applyFixesForSpecificTests(['Admin Bootstrap', 'Test Case A']);
  
  // Emergency rollback
  final rollback = await emergencyRollback();

CONFIGURATION:
  - dryRun: Preview changes without applying
  - enableRollback: Enable automatic rollback on failure
  - onlyTests: Apply fixes only for specified tests
  - verbose: Enable detailed logging

SAFETY FEATURES:
  - Automatic backup creation before applying fixes
  - Rollback capability for failed fixes
  - Validation of applied fixes
  - Comprehensive error handling and logging

For more information, see the documentation in automated_fix_service.dart
''');
}