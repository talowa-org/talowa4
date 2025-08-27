// TALOWA Existing User Login Validation (Test Case C)
// Validates login with mobilenumber@talowa.com format and PIN authentication

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talowa/services/auth_service.dart';
import 'package:talowa/services/database_service.dart';
import 'validation_framework.dart';
import 'test_environment.dart' hide ValidationResult;

/// Validator for existing user login functionality (Test Case C)
class ExistingUserLoginValidator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Main validation method for Test Case C
  static Future<ValidationResult> validateExistingUserLogin() async {
    try {
      debugPrint('🧪 Running Test Case C: Existing User Login Validation...');
      
      // Step 1: Create a test user to login with
      final testUser = await _createTestUserForLogin();
      
      // Step 2: Test login with mobilenumber@talowa.com format
      final loginResult = await _testLoginWithEmailFormat(testUser);
      if (!loginResult.passed) {
        return loginResult;
      }
      
      // Step 3: Verify successful access to app features
      final accessResult = await _verifyAppAccess(testUser);
      if (!accessResult.passed) {
        return accessResult;
      }
      
      // Step 4: Test PIN authentication specifically
      final pinResult = await _testPinAuthentication(testUser);
      if (!pinResult.passed) {
        return pinResult;
      }
      
      // Step 5: Test invalid credentials handling
      final invalidResult = await _testInvalidCredentials(testUser);
      if (!invalidResult.passed) {
        return invalidResult;
      }
      
      // Cleanup test user
      await _cleanupTestUser(testUser);
      
      return ValidationResult.pass(
        'Existing user login validation completed successfully'
      );
      
    } catch (e) {
      debugPrint('❌ Existing user login validation failed: $e');
      return ValidationResult.fail(
        'Existing user login validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/ExistingUserLogin',
        suggestedFix: 'lib/services/auth_service.dart:loginUser - Check login implementation',
      );
    }
  }

  /// Create a test user for login testing
  static Future<TestUser> _createTestUserForLogin() async {
    try {
      debugPrint('👤 Creating test user for login validation...');
      
      // Create test user with known credentials
      final testUser = await TestEnvironment.createTestUser(
        fullName: 'Login Test User',
        referralCode: 'TALADMIN',
      );
      
      // Register the user first so we can login
      await TestEnvironment.simulateUserRegistration(testUser);
      
      // Set the user ID for later cleanup
      testUser.userId = 'test_${testUser.phoneNumber}';
      
      debugPrint('✅ Test user created for login: ${testUser.phoneNumber}');
      return testUser;
      
    } catch (e) {
      debugPrint('❌ Failed to create test user for login: $e');
      rethrow;
    }
  }

  /// Test login with mobilenumber@talowa.com format
  static Future<ValidationResult> _testLoginWithEmailFormat(TestUser testUser) async {
    try {
      debugPrint('🔐 Testing login with email format: ${testUser.phoneNumber}@talowa.app');
      
      // Test login using the email alias format
      final loginResult = await AuthService.loginUser(
        phoneNumber: '${testUser.phoneNumber}@talowa.app',
        pin: testUser.pin,
      );
      
      if (!loginResult.success) {
        return ValidationResult.fail(
          'Login with email format failed',
          errorDetails: loginResult.message,
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'lib/services/auth_service.dart:loginUser - Check email format handling',
        );
      }
      
      // Verify user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return ValidationResult.fail(
          'User not authenticated after login',
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'lib/services/auth_service.dart:loginUser - Check authentication state',
        );
      }
      
      // Verify user profile is returned
      if (loginResult.user == null) {
        return ValidationResult.fail(
          'User profile not returned after login',
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'lib/services/auth_service.dart:loginUser - Check user profile retrieval',
        );
      }
      
      debugPrint('✅ Login with email format successful');
      return ValidationResult.pass('Login with email format working correctly');
      
    } catch (e) {
      debugPrint('❌ Login with email format test failed: $e');
      return ValidationResult.fail(
        'Login with email format test failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService.loginUser',
        suggestedFix: 'lib/services/auth_service.dart:loginUser - Check email format parsing',
      );
    }
  }

  /// Verify successful access to app features after login
  static Future<ValidationResult> _verifyAppAccess(TestUser testUser) async {
    try {
      debugPrint('🏠 Verifying app access after login...');
      
      // Check if user can access their profile
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return ValidationResult.fail(
          'No authenticated user found',
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'lib/services/auth_service.dart:loginUser - Check authentication persistence',
        );
      }
      
      // Try to fetch user profile (simulates accessing app features)
      final userProfile = await DatabaseService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        return ValidationResult.fail(
          'Cannot access user profile after login',
          suspectedModule: 'DatabaseService.getUserProfile',
          suggestedFix: 'lib/services/database_service.dart:getUserProfile - Check profile access',
        );
      }
      
      // Verify profile has expected fields
      if (userProfile.phoneNumber != testUser.phoneNumber) {
        return ValidationResult.fail(
          'User profile mismatch after login',
          errorDetails: 'Expected: ${testUser.phoneNumber}, Got: ${userProfile.phoneNumber}',
          suspectedModule: 'DatabaseService.getUserProfile',
        );
      }
      
      // Check if user can access user registry (simulates network features)
      final isRegistered = await DatabaseService.isPhoneRegistered(testUser.phoneNumber);
      if (!isRegistered) {
        return ValidationResult.fail(
          'Cannot access user registry after login',
          suspectedModule: 'DatabaseService.isPhoneRegistered',
          suggestedFix: 'lib/services/database_service.dart:isPhoneRegistered - Check registry access',
        );
      }
      
      debugPrint('✅ App access verification successful');
      return ValidationResult.pass('User can access app features after login');
      
    } catch (e) {
      debugPrint('❌ App access verification failed: $e');
      return ValidationResult.fail(
        'App access verification failed',
        errorDetails: e.toString(),
        suspectedModule: 'DatabaseService',
        suggestedFix: 'Check database service methods for proper access control',
      );
    }
  }

  /// Test PIN authentication specifically
  static Future<ValidationResult> _testPinAuthentication(TestUser testUser) async {
    try {
      debugPrint('🔢 Testing PIN authentication...');
      
      // First logout to test fresh login
      await AuthService.logout();
      
      // Test login with correct PIN
      final correctPinResult = await AuthService.loginUser(
        phoneNumber: testUser.phoneNumber,
        pin: testUser.pin,
      );
      
      if (!correctPinResult.success) {
        return ValidationResult.fail(
          'Login with correct PIN failed',
          errorDetails: correctPinResult.message,
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'lib/services/auth_service.dart:loginUser - Check PIN validation',
        );
      }
      
      // Logout again for next test
      await AuthService.logout();
      
      // Test login with incorrect PIN
      final incorrectPinResult = await AuthService.loginUser(
        phoneNumber: testUser.phoneNumber,
        pin: '9999', // Wrong PIN
      );
      
      if (incorrectPinResult.success) {
        return ValidationResult.fail(
          'Login with incorrect PIN succeeded (should fail)',
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'lib/services/auth_service.dart:loginUser - Check PIN validation logic',
        );
      }
      
      // Verify error code is appropriate
      if (incorrectPinResult.errorCode != 'invalid-credentials' && 
          incorrectPinResult.errorCode != 'login-error') {
        return ValidationResult.warning(
          'PIN authentication working but error code could be more specific',
          errorDetails: 'Got error code: ${incorrectPinResult.errorCode}',
          suggestedFix: 'lib/services/auth_service.dart:loginUser - Improve error codes',
        );
      }
      
      debugPrint('✅ PIN authentication test successful');
      return ValidationResult.pass('PIN authentication working correctly');
      
    } catch (e) {
      debugPrint('❌ PIN authentication test failed: $e');
      return ValidationResult.fail(
        'PIN authentication test failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService.loginUser',
        suggestedFix: 'lib/services/auth_service.dart:loginUser - Check PIN handling',
      );
    }
  }

  /// Test invalid credentials handling
  static Future<ValidationResult> _testInvalidCredentials(TestUser testUser) async {
    try {
      debugPrint('🚫 Testing invalid credentials handling...');
      
      // Test with non-existent phone number
      final nonExistentResult = await AuthService.loginUser(
        phoneNumber: '+919999999999',
        pin: '1234',
      );
      
      if (nonExistentResult.success) {
        return ValidationResult.fail(
          'Login with non-existent phone number succeeded (should fail)',
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'lib/services/auth_service.dart:loginUser - Check phone number validation',
        );
      }
      
      // Test with invalid phone format
      final invalidFormatResult = await AuthService.loginUser(
        phoneNumber: 'invalid-phone',
        pin: '1234',
      );
      
      if (invalidFormatResult.success) {
        return ValidationResult.fail(
          'Login with invalid phone format succeeded (should fail)',
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'lib/services/auth_service.dart:_normalizePhoneNumber - Check format validation',
        );
      }
      
      // Test rate limiting (attempt multiple failed logins)
      for (int i = 0; i < 6; i++) {
        await AuthService.loginUser(
          phoneNumber: testUser.phoneNumber,
          pin: 'wrong',
        );
      }
      
      // The 6th attempt should be rate limited
      final rateLimitResult = await AuthService.loginUser(
        phoneNumber: testUser.phoneNumber,
        pin: 'wrong',
      );
      
      if (rateLimitResult.success || rateLimitResult.errorCode != 'rate-limit-exceeded') {
        return ValidationResult.warning(
          'Rate limiting not working as expected',
          errorDetails: 'Expected rate-limit-exceeded, got: ${rateLimitResult.errorCode}',
          suggestedFix: 'lib/services/auth_service.dart:_canAttemptLogin - Check rate limiting logic',
        );
      }
      
      debugPrint('✅ Invalid credentials handling test successful');
      return ValidationResult.pass('Invalid credentials handling working correctly');
      
    } catch (e) {
      debugPrint('❌ Invalid credentials test failed: $e');
      return ValidationResult.fail(
        'Invalid credentials test failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService.loginUser',
        suggestedFix: 'lib/services/auth_service.dart:loginUser - Check error handling',
      );
    }
  }

  /// Test login with both phone number formats
  static Future<ValidationResult> testBothLoginFormats(TestUser testUser) async {
    try {
      debugPrint('📱 Testing both login formats...');
      
      // Test 1: Login with plain phone number
      await AuthService.logout();
      final phoneResult = await AuthService.loginUser(
        phoneNumber: testUser.phoneNumber,
        pin: testUser.pin,
      );
      
      if (!phoneResult.success) {
        return ValidationResult.fail(
          'Login with phone number format failed',
          errorDetails: phoneResult.message,
          suspectedModule: 'AuthService.loginUser',
        );
      }
      
      // Test 2: Login with email alias format
      await AuthService.logout();
      final emailResult = await AuthService.loginUser(
        phoneNumber: '${testUser.phoneNumber}@talowa.app',
        pin: testUser.pin,
      );
      
      if (!emailResult.success) {
        return ValidationResult.fail(
          'Login with email alias format failed',
          errorDetails: emailResult.message,
          suspectedModule: 'AuthService.loginUser',
        );
      }
      
      debugPrint('✅ Both login formats working');
      return ValidationResult.pass('Both phone and email alias login formats working');
      
    } catch (e) {
      return ValidationResult.fail(
        'Login format test failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService.loginUser',
      );
    }
  }

  /// Test session persistence after login
  static Future<ValidationResult> testSessionPersistence(TestUser testUser) async {
    try {
      debugPrint('🔄 Testing session persistence...');
      
      // Login user
      final loginResult = await AuthService.loginUser(
        phoneNumber: testUser.phoneNumber,
        pin: testUser.pin,
      );
      
      if (!loginResult.success) {
        return ValidationResult.fail(
          'Initial login failed for session test',
          errorDetails: loginResult.message,
        );
      }
      
      // Check if user remains authenticated
      await Future.delayed(const Duration(seconds: 1));
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return ValidationResult.fail(
          'User session not persisted after login',
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'Check Firebase Auth session configuration',
        );
      }
      
      // Verify user can still access profile
      final profile = await DatabaseService.getUserProfile(currentUser.uid);
      if (profile == null) {
        return ValidationResult.fail(
          'Cannot access profile after session check',
          suspectedModule: 'DatabaseService.getUserProfile',
        );
      }
      
      debugPrint('✅ Session persistence working');
      return ValidationResult.pass('User session persists correctly after login');
      
    } catch (e) {
      return ValidationResult.fail(
        'Session persistence test failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/Firebase',
      );
    }
  }

  /// Cleanup test user data
  static Future<void> _cleanupTestUser(TestUser testUser) async {
    try {
      debugPrint('🧹 Cleaning up test user: ${testUser.phoneNumber}');
      
      // Sign out first
      await AuthService.logout();
      
      // Remove from user_registry
      await _firestore.collection('user_registry').doc(testUser.phoneNumber).delete();
      
      // Remove from users collection
      if (testUser.userId != null) {
        await _firestore.collection('users').doc(testUser.userId!).delete();
      }
      
      debugPrint('✅ Test user cleanup completed');
    } catch (e) {
      debugPrint('⚠️ Test user cleanup failed (non-blocking): $e');
    }
  }

  /// Comprehensive existing user login validation
  static Future<ValidationResult> runComprehensiveValidation() async {
    try {
      debugPrint('🔍 Running comprehensive existing user login validation...');
      
      // Create test user
      final testUser = await _createTestUserForLogin();
      
      final results = <ValidationResult>[];
      
      // Run all validation tests
      results.add(await _testLoginWithEmailFormat(testUser));
      results.add(await _verifyAppAccess(testUser));
      results.add(await _testPinAuthentication(testUser));
      results.add(await _testInvalidCredentials(testUser));
      results.add(await testBothLoginFormats(testUser));
      results.add(await testSessionPersistence(testUser));
      
      // Cleanup
      await _cleanupTestUser(testUser);
      
      // Check if any tests failed
      final failedTests = results.where((r) => !r.passed).toList();
      if (failedTests.isNotEmpty) {
        final failureMessages = failedTests.map((r) => r.message).join('; ');
        return ValidationResult.fail(
          'Some existing user login tests failed',
          errorDetails: failureMessages,
          suspectedModule: 'AuthService',
        );
      }
      
      // Check for warnings
      final warnings = results.where((r) => r.severity == ValidationSeverity.warning).toList();
      if (warnings.isNotEmpty) {
        final warningMessages = warnings.map((r) => r.message).join('; ');
        return ValidationResult.warning(
          'Existing user login working with minor issues',
          errorDetails: warningMessages,
          suspectedModule: 'AuthService',
        );
      }
      
      return ValidationResult.pass(
        'All existing user login validation tests passed'
      );
      
    } catch (e) {
      debugPrint('❌ Comprehensive validation failed: $e');
      return ValidationResult.fail(
        'Comprehensive existing user login validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ExistingUserLoginValidator',
      );
    }
  }

  /// Quick validation for integration with main test suite
  static Future<ValidationResult> quickValidation() async {
    try {
      debugPrint('⚡ Running quick existing user login validation...');
      
      // Check if auth service exists and is properly configured
      final authServiceExists = await _checkAuthServiceConfiguration();
      if (!authServiceExists.passed) {
        return authServiceExists;
      }
      
      // Create minimal test user
      final testUser = await TestEnvironment.createTestUser(
        fullName: 'Quick Login Test',
      );
      
      // Register user
      await TestEnvironment.simulateUserRegistration(testUser);
      testUser.userId = 'test_${testUser.phoneNumber}';
      
      // Test basic login
      final loginResult = await AuthService.loginUser(
        phoneNumber: testUser.phoneNumber,
        pin: testUser.pin,
      );
      
      // Cleanup
      await _cleanupTestUser(testUser);
      
      if (!loginResult.success) {
        return ValidationResult.fail(
          'Quick login test failed',
          errorDetails: loginResult.message,
          suspectedModule: 'AuthService.loginUser',
          suggestedFix: 'lib/services/auth_service.dart:loginUser - Check basic login functionality',
        );
      }
      
      return ValidationResult.pass('Quick existing user login validation passed');
      
    } catch (e) {
      return ValidationResult.fail(
        'Quick validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService',
      );
    }
  }

  /// Check if auth service is properly configured
  static Future<ValidationResult> _checkAuthServiceConfiguration() async {
    try {
      // Check if Firebase Auth is initialized
      FirebaseAuth.instance.currentUser; // This will throw if Firebase is not initialized
      
      // Check if required methods exist (basic reflection check)
      // In a real implementation, we might check method signatures
      
      return ValidationResult.pass('Auth service configuration check passed');
      
    } catch (e) {
      return ValidationResult.fail(
        'Auth service not properly configured',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/Firebase',
        suggestedFix: 'Ensure Firebase is properly initialized in main.dart',
      );
    }
  }
}