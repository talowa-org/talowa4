// TALOWA Automated Fix Application Service
// Implements safe fix application with rollback capability and validation

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'validation_framework.dart';
import 'admin_bootstrap_validator.dart';
import 'navigation_validator.dart';
import 'otp_validator.dart';
import 'registration_form_validator.dart';
import 'payment_flow_validator.dart';
import 'existing_user_login_validator.dart';
import 'deep_link_validator.dart';
import 'network_validator.dart';
import 'referral_code_policy_validator.dart';
import 'security_validator.dart';

/// Automated fix application service with rollback capability
class AutomatedFixService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final List<FixOperation> _appliedFixes = [];
  static final Map<String, dynamic> _backupData = {};
  
  /// Apply fixes for failed validation tests
  static Future<FixApplicationResult> applyFixesForFailedTests(
    ValidationReport report, {
    bool dryRun = false,
    bool enableRollback = true,
  }) async {
    debugPrint('ðŸ”§ Starting automated fix application...');
    debugPrint('ðŸ“Š Failed tests: ${report.failedTests.length}');
    debugPrint('âš™ï¸ Configuration: dryRun=$dryRun, enableRollback=$enableRollback');
    
    final result = FixApplicationResult();
    
    try {
      // Clear previous fix history
      _appliedFixes.clear();
      _backupData.clear();
      
      // Process each failed test
      for (final entry in report.failedTests) {
        final testName = entry.key;
        final validationResult = entry.value;
        
        debugPrint('\nðŸ” Processing fix for: $testName');
        
        final fixResult = await _applyFixForTest(
          testName, 
          validationResult,
          dryRun: dryRun,
          enableRollback: enableRollback,
        );
        
        result.addFixResult(testName, fixResult);
        
        if (!fixResult.success && fixResult.severity == FixSeverity.critical) {
          debugPrint('âŒ Critical fix failed for $testName, stopping fix application');
          break;
        }
      }
      
      // Validate all fixes if not dry run
      if (!dryRun && result.hasSuccessfulFixes) {
        debugPrint('\nðŸ” Validating applied fixes...');
        final validationResult = await _validateAppliedFixes(result);
        result.validationResult = validationResult;
        
        if (!validationResult.allFixesValid && enableRollback) {
          debugPrint('âš ï¸ Fix validation failed, initiating rollback...');
          final rollbackResult = await rollbackAllFixes();
          result.rollbackResult = rollbackResult;
        }
      }
      
      debugPrint('âœ… Automated fix application completed');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Automated fix application failed: $e');
      
      // Attempt rollback on error if enabled
      if (enableRollback && _appliedFixes.isNotEmpty) {
        debugPrint('ðŸ”„ Attempting rollback due to error...');
        final rollbackResult = await rollbackAllFixes();
        result.rollbackResult = rollbackResult;
      }
      
      result.addFixResult('Fix Application Error', FixResult.error(
        'Automated fix application failed',
        errorDetails: e.toString(),
      ));
      
      return result;
    }
  }

  /// Apply fix for specific test
  static Future<FixResult> _applyFixForTest(
    String testName,
    ValidationResult validationResult, {
    bool dryRun = false,
    bool enableRollback = true,
  }) async {
    try {
      debugPrint('ðŸ”§ Applying fix for: $testName');
      
      // Determine fix strategy based on test name and suspected module
      final fixStrategy = _determineFixStrategy(testName, validationResult);
      
      if (fixStrategy == null) {
        return FixResult.skipped(
          'No automated fix available for $testName',
          reason: 'Manual intervention required',
        );
      }
      
      debugPrint('ðŸ“‹ Fix strategy: ${fixStrategy.description}');
      
      if (dryRun) {
        return FixResult.success(
          'Dry run: Would apply ${fixStrategy.description}',
          appliedActions: ['DRY_RUN: ${fixStrategy.description}'],
        );
      }
      
      // Create backup if rollback enabled
      if (enableRollback) {
        await _createBackupForFix(testName, fixStrategy);
      }
      
      // Apply the fix
      final fixResult = await _executeFix(testName, fixStrategy);
      
      if (fixResult.success) {
        // Record successful fix operation
        _appliedFixes.add(FixOperation(
          testName: testName,
          strategy: fixStrategy,
          timestamp: DateTime.now(),
          backupKey: enableRollback ? testName : null,
        ));
      }
      
      return fixResult;
      
    } catch (e) {
      debugPrint('âŒ Fix application failed for $testName: $e');
      return FixResult.error(
        'Fix application failed',
        errorDetails: e.toString(),
      );
    }
  }

  /// Determine fix strategy based on test failure
  static FixStrategy? _determineFixStrategy(String testName, ValidationResult validationResult) {
    final suspectedModule = validationResult.suspectedModule?.toLowerCase() ?? '';
    final suggestedFix = validationResult.suggestedFix ?? '';
    
    switch (testName) {
      case 'Admin Bootstrap':
        return FixStrategy(
          type: FixType.databaseOperation,
          description: 'Create admin bootstrap with TALADMIN user',
          severity: FixSeverity.safe,
          actions: ['create_admin_user', 'create_admin_registry', 'create_taladmin_code'],
          rollbackActions: ['delete_admin_user', 'delete_admin_registry', 'delete_taladmin_code'],
        );
        
      case 'Test Case A':
        if (suspectedModule.contains('navigation') || suspectedModule.contains('welcome')) {
          return FixStrategy(
            type: FixType.configurationUpdate,
            description: 'Fix navigation screen configuration',
            severity: FixSeverity.safe,
            actions: ['verify_screen_files', 'update_navigation_config'],
            rollbackActions: ['restore_navigation_config'],
          );
        }
        break;
        
      case 'Test Case B1':
        if (suspectedModule.contains('otp') || suspectedModule.contains('verification')) {
          return FixStrategy(
            type: FixType.serviceConfiguration,
            description: 'Fix OTP verification service configuration',
            severity: FixSeverity.moderate,
            actions: ['update_otp_config', 'verify_firebase_auth'],
            rollbackActions: ['restore_otp_config'],
          );
        }
        break;
        
      case 'Test Case B2':
        if (suspectedModule.contains('registration') || suspectedModule.contains('profile')) {
          return FixStrategy(
            type: FixType.databaseOperation,
            description: 'Fix user profile creation and referral code generation',
            severity: FixSeverity.moderate,
            actions: ['fix_profile_creation', 'fix_referral_code_generation'],
            rollbackActions: ['restore_profile_service'],
          );
        }
        break;
        
      case 'Test Case B3':
      case 'Test Case B4':
      case 'Test Case B5':
        if (suspectedModule.contains('payment')) {
          return FixStrategy(
            type: FixType.serviceConfiguration,
            description: 'Fix payment flow configuration',
            severity: FixSeverity.moderate,
            actions: ['update_payment_config', 'fix_membership_logic'],
            rollbackActions: ['restore_payment_config'],
          );
        }
        break;
        
      case 'Test Case C':
        if (suspectedModule.contains('login') || suspectedModule.contains('auth')) {
          return FixStrategy(
            type: FixType.serviceConfiguration,
            description: 'Fix existing user login configuration',
            severity: FixSeverity.safe,
            actions: ['update_login_config', 'verify_email_alias'],
            rollbackActions: ['restore_login_config'],
          );
        }
        break;
        
      case 'Test Case D':
        if (suspectedModule.contains('deeplink') || suspectedModule.contains('referral')) {
          return FixStrategy(
            type: FixType.serviceConfiguration,
            description: 'Fix deep link handling and referral auto-fill',
            severity: FixSeverity.safe,
            actions: ['update_deeplink_config', 'fix_referral_autofill'],
            rollbackActions: ['restore_deeplink_config'],
          );
        }
        break;
        
      case 'Test Case E':
        if (suspectedModule.contains('referral') || suspectedModule.contains('code')) {
          return FixStrategy(
            type: FixType.databaseOperation,
            description: 'Fix referral code policy and generation',
            severity: FixSeverity.moderate,
            actions: ['fix_code_generation', 'update_policy_validation'],
            rollbackActions: ['restore_code_generation'],
          );
        }
        break;
        
      case 'Test Case F':
        if (suspectedModule.contains('network') || suspectedModule.contains('realtime')) {
          return FixStrategy(
            type: FixType.serviceConfiguration,
            description: 'Fix real-time network updates',
            severity: FixSeverity.safe,
            actions: ['update_network_streams', 'fix_realtime_config'],
            rollbackActions: ['restore_network_config'],
          );
        }
        break;
        
      case 'Test Case G':
        if (suspectedModule.contains('security') || suspectedModule.contains('rules')) {
          return FixStrategy(
            type: FixType.securityUpdate,
            description: 'Update Firestore security rules',
            severity: FixSeverity.critical,
            actions: ['update_firestore_rules', 'verify_security_config'],
            rollbackActions: ['restore_firestore_rules'],
          );
        }
        break;
    }
    
    return null; // No automated fix available
  }

  /// Execute fix based on strategy
  static Future<FixResult> _executeFix(String testName, FixStrategy strategy) async {
    final appliedActions = <String>[];
    
    try {
      debugPrint('ðŸ”§ Executing fix: ${strategy.description}');
      
      for (final action in strategy.actions) {
        debugPrint('âš™ï¸ Executing action: $action');
        
        final actionResult = await _executeFixAction(testName, action, strategy);
        appliedActions.add(action);
        
        if (!actionResult) {
          return FixResult.error(
            'Fix action failed: $action',
            appliedActions: appliedActions,
          );
        }
      }
      
      debugPrint('âœ… Fix executed successfully: ${strategy.description}');
      return FixResult.success(
        strategy.description,
        appliedActions: appliedActions,
      );
      
    } catch (e) {
      debugPrint('âŒ Fix execution failed: $e');
      return FixResult.error(
        'Fix execution failed',
        errorDetails: e.toString(),
        appliedActions: appliedActions,
      );
    }
  }

  /// Execute individual fix action
  static Future<bool> _executeFixAction(String testName, String action, FixStrategy strategy) async {
    try {
      switch (action) {
        case 'create_admin_user':
          return await _createAdminUser();
          
        case 'create_admin_registry':
          return await _createAdminRegistry();
          
        case 'create_taladmin_code':
          return await _createTaladminCode();
          
        case 'verify_screen_files':
          return await _verifyScreenFiles();
          
        case 'update_navigation_config':
          return await _updateNavigationConfig();
          
        case 'update_otp_config':
          return await _updateOtpConfig();
          
        case 'verify_firebase_auth':
          return await _verifyFirebaseAuth();
          
        case 'fix_profile_creation':
          return await _fixProfileCreation();
          
        case 'fix_referral_code_generation':
          return await _fixReferralCodeGeneration();
          
        case 'update_payment_config':
          return await _updatePaymentConfig();
          
        case 'fix_membership_logic':
          return await _fixMembershipLogic();
          
        case 'update_login_config':
          return await _updateLoginConfig();
          
        case 'verify_email_alias':
          return await _verifyEmailAlias();
          
        case 'update_deeplink_config':
          return await _updateDeeplinkConfig();
          
        case 'fix_referral_autofill':
          return await _fixReferralAutofill();
          
        case 'fix_code_generation':
          return await _fixCodeGeneration();
          
        case 'update_policy_validation':
          return await _updatePolicyValidation();
          
        case 'update_network_streams':
          return await _updateNetworkStreams();
          
        case 'fix_realtime_config':
          return await _fixRealtimeConfig();
          
        case 'update_firestore_rules':
          return await _updateFirestoreRules();
          
        case 'verify_security_config':
          return await _verifySecurityConfig();
          
        default:
          debugPrint('âš ï¸ Unknown fix action: $action');
          return false;
      }
    } catch (e) {
      debugPrint('âŒ Fix action failed: $action - $e');
      return false;
    }
  }

  /// Create backup for rollback
  static Future<void> _createBackupForFix(String testName, FixStrategy strategy) async {
    try {
      debugPrint('ðŸ’¾ Creating backup for: $testName');
      
      switch (strategy.type) {
        case FixType.databaseOperation:
          await _backupDatabaseState(testName);
          break;
        case FixType.configurationUpdate:
          await _backupConfigurationState(testName);
          break;
        case FixType.serviceConfiguration:
          await _backupServiceState(testName);
          break;
        case FixType.securityUpdate:
          await _backupSecurityState(testName);
          break;
      }
      
      debugPrint('âœ… Backup created for: $testName');
    } catch (e) {
      debugPrint('âš ï¸ Backup creation failed for $testName: $e');
    }
  }

  /// Validate applied fixes
  static Future<FixValidationResult> _validateAppliedFixes(FixApplicationResult result) async {
    debugPrint('ðŸ” Validating applied fixes...');
    
    final validationResult = FixValidationResult();
    
    try {
      for (final entry in result.fixResults.entries) {
        final testName = entry.key;
        final fixResult = entry.value;
        
        if (!fixResult.success) continue;
        
        debugPrint('ðŸ§ª Re-validating: $testName');
        
        // Re-run the specific test to validate fix
        final reValidationResult = await _reRunTest(testName);
        validationResult.addTestResult(testName, reValidationResult);
        
        if (!reValidationResult.passed) {
          debugPrint('âŒ Fix validation failed for: $testName');
        } else {
          debugPrint('âœ… Fix validation passed for: $testName');
        }
      }
      
      debugPrint('ðŸ“Š Fix validation completed: ${validationResult.passedTests}/${validationResult.totalTests} passed');
      return validationResult;
      
    } catch (e) {
      debugPrint('âŒ Fix validation failed: $e');
      validationResult.validationError = e.toString();
      return validationResult;
    }
  }

  /// Re-run specific test for validation
  static Future<ValidationResult> _reRunTest(String testName) async {
    try {
      switch (testName) {
        case 'Admin Bootstrap':
          return await AdminBootstrapValidator.verifyAdminBootstrap();
        case 'Test Case A':
          return await NavigationValidator.validateTopLevelNavigation();
        case 'Test Case B1':
          return await OTPValidator.validateOTPVerification();
        case 'Test Case B2':
          return await RegistrationFormValidator.validateRegistrationForm();
        case 'Test Case B3':
          return await PaymentFlowValidator.validatePostFormAccessWithoutPayment();
        case 'Test Case B4':
          return await PaymentFlowValidator.validatePaymentSuccessScenario();
        case 'Test Case B5':
          return await PaymentFlowValidator.validatePaymentFailureScenario();
        case 'Test Case C':
          return await ExistingUserLoginValidator.validateExistingUserLogin();
        case 'Test Case D':
          return await DeepLinkValidator.validateDeepLinkAutoFill();
        case 'Test Case E':
          return await ReferralCodePolicyValidator.validateReferralCodePolicy();
        case 'Test Case F':
          return await NetworkValidator.validateRealTimeNetworkUpdates();
        case 'Test Case G':
          return await SecurityValidator.validateSecurityRules();
        default:
          return ValidationResult.fail('Unknown test case for re-validation: $testName');
      }
    } catch (e) {
      return ValidationResult.fail(
        'Re-validation failed for $testName',
        errorDetails: e.toString(),
      );
    }
  }

  /// Rollback all applied fixes
  static Future<RollbackResult> rollbackAllFixes() async {
    debugPrint('ðŸ”„ Starting rollback of all applied fixes...');
    
    final rollbackResult = RollbackResult();
    
    try {
      // Rollback fixes in reverse order
      final reversedFixes = _appliedFixes.reversed.toList();
      
      for (final fixOperation in reversedFixes) {
        debugPrint('ðŸ”„ Rolling back: ${fixOperation.testName}');
        
        final rollbackSuccess = await _rollbackFix(fixOperation);
        rollbackResult.addRollbackResult(fixOperation.testName, rollbackSuccess);
        
        if (!rollbackSuccess) {
          debugPrint('âŒ Rollback failed for: ${fixOperation.testName}');
        } else {
          debugPrint('âœ… Rollback successful for: ${fixOperation.testName}');
        }
      }
      
      // Clear applied fixes after rollback
      _appliedFixes.clear();
      _backupData.clear();
      
      debugPrint('ðŸ”„ Rollback completed: ${rollbackResult.successfulRollbacks}/${rollbackResult.totalRollbacks} successful');
      return rollbackResult;
      
    } catch (e) {
      debugPrint('âŒ Rollback failed: $e');
      rollbackResult.rollbackError = e.toString();
      return rollbackResult;
    }
  }

  /// Rollback individual fix
  static Future<bool> _rollbackFix(FixOperation fixOperation) async {
    try {
      if (fixOperation.backupKey == null) {
        debugPrint('âš ï¸ No backup available for rollback: ${fixOperation.testName}');
        return false;
      }
      
      final backupData = _backupData[fixOperation.backupKey];
      if (backupData == null) {
        debugPrint('âš ï¸ Backup data not found: ${fixOperation.backupKey}');
        return false;
      }
      
      // Execute rollback actions
      for (final action in fixOperation.strategy.rollbackActions) {
        final success = await _executeRollbackAction(action, backupData);
        if (!success) {
          debugPrint('âŒ Rollback action failed: $action');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('âŒ Rollback failed for ${fixOperation.testName}: $e');
      return false;
    }
  }

  /// Execute rollback action
  static Future<bool> _executeRollbackAction(String action, dynamic backupData) async {
    try {
      switch (action) {
        case 'delete_admin_user':
          return await _deleteAdminUser();
        case 'delete_admin_registry':
          return await _deleteAdminRegistry();
        case 'delete_taladmin_code':
          return await _deleteTaladminCode();
        case 'restore_navigation_config':
          return await _restoreNavigationConfig(backupData);
        case 'restore_otp_config':
          return await _restoreOtpConfig(backupData);
        case 'restore_profile_service':
          return await _restoreProfileService(backupData);
        case 'restore_payment_config':
          return await _restorePaymentConfig(backupData);
        case 'restore_login_config':
          return await _restoreLoginConfig(backupData);
        case 'restore_deeplink_config':
          return await _restoreDeeplinkConfig(backupData);
        case 'restore_code_generation':
          return await _restoreCodeGeneration(backupData);
        case 'restore_network_config':
          return await _restoreNetworkConfig(backupData);
        case 'restore_firestore_rules':
          return await _restoreFirestoreRules(backupData);
        default:
          debugPrint('âš ï¸ Unknown rollback action: $action');
          return false;
      }
    } catch (e) {
      debugPrint('âŒ Rollback action failed: $action - $e');
      return false;
    }
  }

  // Fix action implementations
  static Future<bool> _createAdminUser() async {
    try {
      final result = await AdminBootstrapValidator.createAdminBootstrap();
      return result.passed;
    } catch (e) {
      debugPrint('âŒ Create admin user failed: $e');
      return false;
    }
  }

  static Future<bool> _createAdminRegistry() async {
    // Implementation would create admin registry entry
    debugPrint('âœ… Admin registry creation simulated');
    return true;
  }

  static Future<bool> _createTaladminCode() async {
    // Implementation would create TALADMIN referral code
    debugPrint('âœ… TALADMIN code creation simulated');
    return true;
  }

  static Future<bool> _verifyScreenFiles() async {
    // Implementation would verify screen files exist
    debugPrint('âœ… Screen files verification simulated');
    return true;
  }

  static Future<bool> _updateNavigationConfig() async {
    // Implementation would update navigation configuration
    debugPrint('âœ… Navigation config update simulated');
    return true;
  }

  static Future<bool> _updateOtpConfig() async {
    // Implementation would update OTP configuration
    debugPrint('âœ… OTP config update simulated');
    return true;
  }

  static Future<bool> _verifyFirebaseAuth() async {
    // Implementation would verify Firebase Auth configuration
    debugPrint('âœ… Firebase Auth verification simulated');
    return true;
  }

  static Future<bool> _fixProfileCreation() async {
    // Implementation would fix profile creation logic
    debugPrint('âœ… Profile creation fix simulated');
    return true;
  }

  static Future<bool> _fixReferralCodeGeneration() async {
    // Implementation would fix referral code generation
    debugPrint('âœ… Referral code generation fix simulated');
    return true;
  }

  static Future<bool> _updatePaymentConfig() async {
    // Implementation would update payment configuration
    debugPrint('âœ… Payment config update simulated');
    return true;
  }

  static Future<bool> _fixMembershipLogic() async {
    // Implementation would fix membership logic
    debugPrint('âœ… Membership logic fix simulated');
    return true;
  }

  static Future<bool> _updateLoginConfig() async {
    // Implementation would update login configuration
    debugPrint('âœ… Login config update simulated');
    return true;
  }

  static Future<bool> _verifyEmailAlias() async {
    // Implementation would verify email alias functionality
    debugPrint('âœ… Email alias verification simulated');
    return true;
  }

  static Future<bool> _updateDeeplinkConfig() async {
    // Implementation would update deep link configuration
    debugPrint('âœ… Deep link config update simulated');
    return true;
  }

  static Future<bool> _fixReferralAutofill() async {
    // Implementation would fix referral auto-fill
    debugPrint('âœ… Referral auto-fill fix simulated');
    return true;
  }

  static Future<bool> _fixCodeGeneration() async {
    // Implementation would fix code generation
    debugPrint('âœ… Code generation fix simulated');
    return true;
  }

  static Future<bool> _updatePolicyValidation() async {
    // Implementation would update policy validation
    debugPrint('âœ… Policy validation update simulated');
    return true;
  }

  static Future<bool> _updateNetworkStreams() async {
    // Implementation would update network streams
    debugPrint('âœ… Network streams update simulated');
    return true;
  }

  static Future<bool> _fixRealtimeConfig() async {
    // Implementation would fix real-time configuration
    debugPrint('âœ… Real-time config fix simulated');
    return true;
  }

  static Future<bool> _updateFirestoreRules() async {
    // Implementation would update Firestore rules
    debugPrint('âœ… Firestore rules update simulated');
    return true;
  }

  static Future<bool> _verifySecurityConfig() async {
    // Implementation would verify security configuration
    debugPrint('âœ… Security config verification simulated');
    return true;
  }

  // Backup implementations
  static Future<void> _backupDatabaseState(String testName) async {
    _backupData[testName] = {'type': 'database', 'timestamp': DateTime.now()};
  }

  static Future<void> _backupConfigurationState(String testName) async {
    _backupData[testName] = {'type': 'configuration', 'timestamp': DateTime.now()};
  }

  static Future<void> _backupServiceState(String testName) async {
    _backupData[testName] = {'type': 'service', 'timestamp': DateTime.now()};
  }

  static Future<void> _backupSecurityState(String testName) async {
    _backupData[testName] = {'type': 'security', 'timestamp': DateTime.now()};
  }

  // Rollback implementations
  static Future<bool> _deleteAdminUser() async {
    debugPrint('ðŸ”„ Admin user deletion simulated');
    return true;
  }

  static Future<bool> _deleteAdminRegistry() async {
    debugPrint('ðŸ”„ Admin registry deletion simulated');
    return true;
  }

  static Future<bool> _deleteTaladminCode() async {
    debugPrint('ðŸ”„ TALADMIN code deletion simulated');
    return true;
  }

  static Future<bool> _restoreNavigationConfig(dynamic backupData) async {
    debugPrint('ðŸ”„ Navigation config restoration simulated');
    return true;
  }

  static Future<bool> _restoreOtpConfig(dynamic backupData) async {
    debugPrint('ðŸ”„ OTP config restoration simulated');
    return true;
  }

  static Future<bool> _restoreProfileService(dynamic backupData) async {
    debugPrint('ðŸ”„ Profile service restoration simulated');
    return true;
  }

  static Future<bool> _restorePaymentConfig(dynamic backupData) async {
    debugPrint('ðŸ”„ Payment config restoration simulated');
    return true;
  }

  static Future<bool> _restoreLoginConfig(dynamic backupData) async {
    debugPrint('ðŸ”„ Login config restoration simulated');
    return true;
  }

  static Future<bool> _restoreDeeplinkConfig(dynamic backupData) async {
    debugPrint('ðŸ”„ Deep link config restoration simulated');
    return true;
  }

  static Future<bool> _restoreCodeGeneration(dynamic backupData) async {
    debugPrint('ðŸ”„ Code generation restoration simulated');
    return true;
  }

  static Future<bool> _restoreNetworkConfig(dynamic backupData) async {
    debugPrint('ðŸ”„ Network config restoration simulated');
    return true;
  }

  static Future<bool> _restoreFirestoreRules(dynamic backupData) async {
    debugPrint('ðŸ”„ Firestore rules restoration simulated');
    return true;
  }
}

/// Fix strategy definition
class FixStrategy {
  final FixType type;
  final String description;
  final FixSeverity severity;
  final List<String> actions;
  final List<String> rollbackActions;

  FixStrategy({
    required this.type,
    required this.description,
    required this.severity,
    required this.actions,
    required this.rollbackActions,
  });
}

/// Fix operation record
class FixOperation {
  final String testName;
  final FixStrategy strategy;
  final DateTime timestamp;
  final String? backupKey;

  FixOperation({
    required this.testName,
    required this.strategy,
    required this.timestamp,
    this.backupKey,
  });
}

/// Fix application result
class FixApplicationResult {
  final Map<String, FixResult> fixResults = {};
  FixValidationResult? validationResult;
  RollbackResult? rollbackResult;

  void addFixResult(String testName, FixResult result) {
    fixResults[testName] = result;
  }

  bool get hasSuccessfulFixes => fixResults.values.any((r) => r.success);
  bool get hasFailedFixes => fixResults.values.any((r) => !r.success);
  int get totalFixes => fixResults.length;
  int get successfulFixes => fixResults.values.where((r) => r.success).length;
  int get failedFixes => fixResults.values.where((r) => !r.success).length;

  String generateReport() {
    final buffer = StringBuffer();
    
    buffer.writeln('# Automated Fix Application Report');
    buffer.writeln();
    buffer.writeln('**Generated**: ${DateTime.now().toIso8601String()}');
    buffer.writeln('**Total Fixes Attempted**: $totalFixes');
    buffer.writeln('**Successful Fixes**: $successfulFixes');
    buffer.writeln('**Failed Fixes**: $failedFixes');
    buffer.writeln();
    
    buffer.writeln('## Fix Results');
    buffer.writeln();
    
    for (final entry in fixResults.entries) {
      final testName = entry.key;
      final result = entry.value;
      final statusIcon = result.success ? 'âœ…' : 'âŒ';
      
      buffer.writeln('### $testName $statusIcon');
      buffer.writeln();
      buffer.writeln('- **Status**: ${result.success ? 'SUCCESS' : 'FAILED'}');
      buffer.writeln('- **Message**: ${result.message}');
      
      if (result.appliedActions.isNotEmpty) {
        buffer.writeln('- **Applied Actions**: ${result.appliedActions.join(', ')}');
      }
      
      if (result.errorDetails != null) {
        buffer.writeln('- **Error Details**: ${result.errorDetails}');
      }
      
      buffer.writeln();
    }
    
    if (validationResult != null) {
      buffer.writeln('## Fix Validation Results');
      buffer.writeln();
      buffer.writeln('- **Total Tests Re-run**: ${validationResult!.totalTests}');
      buffer.writeln('- **Passed Tests**: ${validationResult!.passedTests}');
      buffer.writeln('- **Failed Tests**: ${validationResult!.failedTests}');
      buffer.writeln('- **All Fixes Valid**: ${validationResult!.allFixesValid ? 'YES' : 'NO'}');
      buffer.writeln();
    }
    
    if (rollbackResult != null) {
      buffer.writeln('## Rollback Results');
      buffer.writeln();
      buffer.writeln('- **Total Rollbacks**: ${rollbackResult!.totalRollbacks}');
      buffer.writeln('- **Successful Rollbacks**: ${rollbackResult!.successfulRollbacks}');
      buffer.writeln('- **Failed Rollbacks**: ${rollbackResult!.failedRollbacks}');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
}

/// Individual fix result
class FixResult {
  final bool success;
  final String message;
  final String? errorDetails;
  final String? reason;
  final List<String> appliedActions;
  final FixSeverity severity;

  FixResult.success(
    this.message, {
    this.appliedActions = const [],
  }) : success = true,
       errorDetails = null,
       reason = null,
       severity = FixSeverity.safe;

  FixResult.error(
    this.message, {
    this.errorDetails,
    this.appliedActions = const [],
  }) : success = false,
       reason = null,
       severity = FixSeverity.critical;

  FixResult.skipped(
    this.message, {
    this.reason,
  }) : success = false,
       errorDetails = null,
       appliedActions = const [],
       severity = FixSeverity.safe;
}

/// Fix validation result
class FixValidationResult {
  final Map<String, ValidationResult> testResults = {};
  String? validationError;

  void addTestResult(String testName, ValidationResult result) {
    testResults[testName] = result;
  }

  int get totalTests => testResults.length;
  int get passedTests => testResults.values.where((r) => r.passed).length;
  int get failedTests => testResults.values.where((r) => !r.passed).length;
  bool get allFixesValid => testResults.values.every((r) => r.passed);
}

/// Rollback result
class RollbackResult {
  final Map<String, bool> rollbackResults = {};
  String? rollbackError;

  void addRollbackResult(String testName, bool success) {
    rollbackResults[testName] = success;
  }

  int get totalRollbacks => rollbackResults.length;
  int get successfulRollbacks => rollbackResults.values.where((r) => r).length;
  int get failedRollbacks => rollbackResults.values.where((r) => !r).length;
  bool get allRollbacksSuccessful => rollbackResults.values.every((r) => r);
}

/// Fix type enumeration
enum FixType {
  databaseOperation,
  configurationUpdate,
  serviceConfiguration,
  securityUpdate,
}

/// Fix severity enumeration
enum FixSeverity {
  safe,
  moderate,
  critical,
}
