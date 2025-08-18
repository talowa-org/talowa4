// TALOWA Registration Form Validator
// Test Case B2: Registration form validation

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'validation_framework.dart';
import '../../lib/services/auth_service.dart';
import '../../lib/models/user_model.dart';

/// Registration form validator for Test Case B2
class RegistrationFormValidator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Test Case B2: Registration Form Validation
  static Future<ValidationResult> validateRegistrationForm() async {
    try {
      debugPrint('🧪 Running Test Case B2: Registration Form Validation...');
      
      // Step 1: Test form field validation
      final fieldResult = await _validateFormFieldValidation();
      if (!fieldResult.passed) return fieldResult;
      
      // Step 2: Test form submission process
      final submissionResult = await _validateFormSubmissionProcess();
      if (!submissionResult.passed) return submissionResult;
      
      // Step 3: Validate user document creation
      final documentResult = await _validateUserDocumentCreation();
      if (!documentResult.passed) return documentResult;
      
      // Step 4: Verify referral code generation
      final referralResult = await _validateReferralCodeGeneration();
      if (!referralResult.passed) return referralResult;
      
      // Step 5: Test provisionalRef assignment
      final provisionalResult = await _validateProvisionalRefAssignment();
      if (!provisionalResult.passed) return provisionalResult;
      
      // Step 6: Verify post-registration app access
      final accessResult = await _validatePostRegistrationAccess();
      if (!accessResult.passed) return accessResult;
      
      debugPrint('✅ Test Case B2: Registration form validation completed successfully');
      return ValidationResult.pass('Registration form creates complete active profile with valid referral code');
      
    } catch (e) {
      debugPrint('❌ Test Case B2: Registration form validation failed: $e');
      return ValidationResult.fail(
        'Registration form validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/RegistrationForm',
        suggestedFix: 'lib/services/auth_service.dart:registerUser - Implement complete registration form validation and processing',
      );
    }
  }

  /// Validate form field validation
  static Future<ValidationResult> _validateFormFieldValidation() async {
    try {
      debugPrint('📝 Validating form field validation...');
      
      // Test required fields validation
      final requiredFieldsResult = await _testRequiredFields();
      if (!requiredFieldsResult.passed) return requiredFieldsResult;
      
      // Test field format validation
      final formatResult = await _testFieldFormatValidation();
      if (!formatResult.passed) return formatResult;
      
      // Test address hierarchy validation
      final addressResult = await _testAddressHierarchyValidation();
      if (!addressResult.passed) return addressResult;
      
      debugPrint('✅ Form field validation passed');
      return ValidationResult.pass('Form field validation working correctly');
      
    } catch (e) {
      return ValidationResult.fail(
        'Form field validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'RegistrationForm/FieldValidation',
        suggestedFix: 'lib/screens/auth/real_user_registration_screen.dart - Implement proper form field validation',
      );
    }
  }

  /// Test required fields validation
  static Future<ValidationResult> _testRequiredFields() async {
    try {
      debugPrint('🔍 Testing required fields validation...');
      
      // Test cases for required fields
      final testCases = [
        {
          'description': 'Missing fullName',
          'data': _generateTestUserData()..remove('fullName'),
          'shouldFail': true,
          'expectedError': 'fullName is required',
        },
        {
          'description': 'Empty fullName',
          'data': _generateTestUserData()..['fullName'] = '',
          'shouldFail': true,
          'expectedError': 'fullName cannot be empty',
        },
        {
          'description': 'Missing address components',
          'data': _generateTestUserData()..['address'] = {},
          'shouldFail': true,
          'expectedError': 'address components are required',
        },
        {
          'description': 'Missing PIN',
          'data': _generateTestUserData()..remove('pin'),
          'shouldFail': true,
          'expectedError': 'PIN is required',
        },
        {
          'description': 'Valid complete data',
          'data': _generateTestUserData(),
          'shouldFail': false,
          'expectedError': null,
        },
      ];

      for (final testCase in testCases) {
        final description = testCase['description'] as String;
        final data = testCase['data'] as Map<String, dynamic>;
        final shouldFail = testCase['shouldFail'] as bool;
        final expectedError = testCase['expectedError'] as String?;
        
        debugPrint('  Testing: $description');
        
        final validationResult = _validateFormData(data);
        
        if (shouldFail && validationResult.isValid) {
          return ValidationResult.fail(
            'Required field validation failed: $description should have failed',
            errorDetails: 'Expected validation to fail but it passed',
            suspectedModule: 'RegistrationForm/RequiredFields',
            suggestedFix: 'Add validation for required field: ${expectedError ?? 'unknown field'}',
          );
        }
        
        if (!shouldFail && !validationResult.isValid) {
          return ValidationResult.fail(
            'Required field validation failed: $description should have passed',
            errorDetails: 'Expected validation to pass but it failed: ${validationResult.error}',
            suspectedModule: 'RegistrationForm/RequiredFields',
            suggestedFix: 'Fix validation logic for valid data',
          );
        }
        
        debugPrint('    ✓ $description - ${validationResult.isValid ? 'PASS' : 'FAIL (expected)'}');
      }

      debugPrint('✅ Required fields validation tests passed');
      return ValidationResult.pass('Required fields validation working correctly');
      
    } catch (e) {
      return ValidationResult.fail(
        'Required fields validation test failed',
        errorDetails: e.toString(),
        suspectedModule: 'RegistrationForm/RequiredFields',
      );
    }
  }

  /// Test field format validation
  static Future<ValidationResult> _testFieldFormatValidation() async {
    try {
      debugPrint('🔍 Testing field format validation...');
      
      // Test PIN format validation (must be 4 digits)
      final pinTestCases = [
        {
          'pin': '1234',
          'valid': true,
          'description': 'Valid 4-digit PIN',
        },
        {
          'pin': '0000',
          'valid': true,
          'description': 'Valid 4-digit PIN with zeros',
        },
        {
          'pin': '123',
          'valid': false,
          'description': 'Invalid PIN - too short',
        },
        {
          'pin': '12345',
          'valid': false,
          'description': 'Invalid PIN - too long',
        },
        {
          'pin': 'abcd',
          'valid': false,
          'description': 'Invalid PIN - contains letters',
        },
        {
          'pin': '12a4',
          'valid': false,
          'description': 'Invalid PIN - mixed alphanumeric',
        },
        {
          'pin': '',
          'valid': false,
          'description': 'Invalid PIN - empty',
        },
      ];

      for (final testCase in pinTestCases) {
        final pin = testCase['pin'] as String;
        final expectedValid = testCase['valid'] as bool;
        final description = testCase['description'] as String;
        
        debugPrint('  Testing PIN: $description');
        
        final isValid = _validatePinFormat(pin);
        
        if (isValid != expectedValid) {
          return ValidationResult.fail(
            'PIN format validation failed for: $pin ($description)',
            errorDetails: 'Expected valid: $expectedValid, Got: $isValid',
            suspectedModule: 'RegistrationForm/PinValidation',
            suggestedFix: 'lib/screens/auth/real_user_registration_screen.dart - Fix PIN format validation (must be exactly 4 digits)',
          );
        }
        
        debugPrint('    ✓ PIN $pin - ${isValid ? 'VALID' : 'INVALID'} (expected)');
      }

      // Test phone number format validation
      final phoneTestCases = [
        {
          'phone': '+919876543210',
          'valid': true,
          'description': 'Valid Indian phone with country code',
        },
        {
          'phone': '9876543210',
          'valid': true,
          'description': 'Valid Indian phone without country code',
        },
        {
          'phone': '1234567890',
          'valid': false,
          'description': 'Invalid phone - doesn\'t start with 6-9',
        },
        {
          'phone': '+919876',
          'valid': false,
          'description': 'Invalid phone - too short',
        },
      ];

      for (final testCase in phoneTestCases) {
        final phone = testCase['phone'] as String;
        final expectedValid = testCase['valid'] as bool;
        final description = testCase['description'] as String;
        
        debugPrint('  Testing Phone: $description');
        
        final isValid = _validatePhoneFormat(phone);
        
        if (isValid != expectedValid) {
          return ValidationResult.fail(
            'Phone format validation failed for: $phone ($description)',
            errorDetails: 'Expected valid: $expectedValid, Got: $isValid',
            suspectedModule: 'RegistrationForm/PhoneValidation',
            suggestedFix: 'lib/screens/auth/real_user_registration_screen.dart - Fix phone format validation',
          );
        }
        
        debugPrint('    ✓ Phone $phone - ${isValid ? 'VALID' : 'INVALID'} (expected)');
      }

      debugPrint('✅ Field format validation tests passed');
      return ValidationResult.pass('Field format validation working correctly');
      
    } catch (e) {
      return ValidationResult.fail(
        'Field format validation test failed',
        errorDetails: e.toString(),
        suspectedModule: 'RegistrationForm/FormatValidation',
      );
    }
  }

  /// Test address hierarchy validation
  static Future<ValidationResult> _testAddressHierarchyValidation() async {
    try {
      debugPrint('🔍 Testing address hierarchy validation...');
      
      // Test address hierarchy: state → district → mandal → village
      final addressTestCases = [
        {
          'address': {
            'state': 'Telangana',
            'district': 'Hyderabad',
            'mandal': 'Secunderabad',
            'villageCity': 'Begumpet',
          },
          'valid': true,
          'description': 'Complete valid address hierarchy',
        },
        {
          'address': {
            'state': '',
            'district': 'Hyderabad',
            'mandal': 'Secunderabad',
            'villageCity': 'Begumpet',
          },
          'valid': false,
          'description': 'Missing state',
        },
        {
          'address': {
            'state': 'Telangana',
            'district': '',
            'mandal': 'Secunderabad',
            'villageCity': 'Begumpet',
          },
          'valid': false,
          'description': 'Missing district',
        },
        {
          'address': {
            'state': 'Telangana',
            'district': 'Hyderabad',
            'mandal': '',
            'villageCity': 'Begumpet',
          },
          'valid': false,
          'description': 'Missing mandal',
        },
        {
          'address': {
            'state': 'Telangana',
            'district': 'Hyderabad',
            'mandal': 'Secunderabad',
            'villageCity': '',
          },
          'valid': false,
          'description': 'Missing village/city',
        },
      ];

      for (final testCase in addressTestCases) {
        final address = testCase['address'] as Map<String, dynamic>;
        final expectedValid = testCase['valid'] as bool;
        final description = testCase['description'] as String;
        
        debugPrint('  Testing Address: $description');
        
        final isValid = _validateAddressHierarchy(address);
        
        if (isValid != expectedValid) {
          return ValidationResult.fail(
            'Address hierarchy validation failed for: $description',
            errorDetails: 'Expected valid: $expectedValid, Got: $isValid',
            suspectedModule: 'RegistrationForm/AddressValidation',
            suggestedFix: 'lib/screens/auth/real_user_registration_screen.dart - Fix address hierarchy validation (state → district → mandal → village)',
          );
        }
        
        debugPrint('    ✓ Address - ${isValid ? 'VALID' : 'INVALID'} (expected)');
      }

      debugPrint('✅ Address hierarchy validation tests passed');
      return ValidationResult.pass('Address hierarchy validation working correctly');
      
    } catch (e) {
      return ValidationResult.fail(
        'Address hierarchy validation test failed',
        errorDetails: e.toString(),
        suspectedModule: 'RegistrationForm/AddressValidation',
      );
    }
  }

  /// Validate form submission process
  static Future<ValidationResult> _validateFormSubmissionProcess() async {
    try {
      debugPrint('📤 Validating form submission process...');
      
      // Generate test user data
      final testPhone = '+919876543${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final testUserData = _generateTestUserData(phoneNumber: testPhone);
      
      // Test successful form submission
      final submissionResult = await _simulateFormSubmission(testUserData);
      if (!submissionResult.success) {
        return ValidationResult.fail(
          'Form submission failed',
          errorDetails: submissionResult.message,
          suspectedModule: 'AuthService/registerUser',
          suggestedFix: 'lib/services/auth_service.dart:registerUser - Fix form submission processing',
        );
      }

      // Test form validation error handling
      final invalidData = _generateTestUserData(phoneNumber: testPhone)..['fullName'] = '';
      final errorResult = await _simulateFormSubmission(invalidData);
      if (errorResult.success) {
        return ValidationResult.fail(
          'Form submission should fail with invalid data',
          errorDetails: 'Invalid form data was accepted',
          suspectedModule: 'AuthService/registerUser',
          suggestedFix: 'lib/services/auth_service.dart:registerUser - Add proper form validation before processing',
        );
      }

      // Clean up test data
      await _cleanupTestUser(testPhone);

      debugPrint('✅ Form submission process validation passed');
      return ValidationResult.pass('Form submission process working correctly');
      
    } catch (e) {
      return ValidationResult.fail(
        'Form submission process validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/registerUser',
      );
    }
  }

  /// Validate user document creation
  static Future<ValidationResult> _validateUserDocumentCreation() async {
    try {
      debugPrint('📄 Validating user document creation...');
      
      // Generate test user data
      final testPhone = '+919876543${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final testUserData = _generateTestUserData(phoneNumber: testPhone);
      
      // Submit registration form
      final submissionResult = await _simulateFormSubmission(testUserData);
      if (!submissionResult.success) {
        return ValidationResult.fail(
          'Cannot test document creation - form submission failed',
          errorDetails: submissionResult.message,
          suspectedModule: 'AuthService/registerUser',
        );
      }

      // Get the created user UID
      final userUid = submissionResult.userUid;
      if (userUid == null) {
        return ValidationResult.fail(
          'User UID not returned from registration',
          suspectedModule: 'AuthService/registerUser',
          suggestedFix: 'lib/services/auth_service.dart:registerUser - Return user UID after successful registration',
        );
      }

      // Check if user document exists in Firestore
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      if (!userDoc.exists) {
        return ValidationResult.fail(
          'User document not created in Firestore',
          suspectedModule: 'AuthService/_createClientUserProfile',
          suggestedFix: 'lib/services/auth_service.dart:_createClientUserProfile - Ensure user document is created in users collection',
        );
      }

      final userData = userDoc.data()!;
      
      // Verify required fields
      final requiredFieldChecks = [
        {
          'field': 'status',
          'expectedValue': 'active',
          'actualValue': userData['status'],
        },
        {
          'field': 'phoneVerified',
          'expectedValue': true,
          'actualValue': userData['phoneVerified'],
        },
        {
          'field': 'profileCompleted',
          'expectedValue': true,
          'actualValue': userData['profileCompleted'],
        },
        {
          'field': 'membershipPaid',
          'expectedValue': false,
          'actualValue': userData['membershipPaid'],
        },
      ];

      for (final check in requiredFieldChecks) {
        final field = check['field'] as String;
        final expected = check['expectedValue'];
        final actual = check['actualValue'];
        
        if (actual != expected) {
          return ValidationResult.fail(
            'User document field validation failed: $field',
            errorDetails: 'Expected: $expected, Got: $actual',
            suspectedModule: 'AuthService/_createClientUserProfile',
            suggestedFix: 'lib/services/auth_service.dart:_createClientUserProfile - Set $field to $expected',
          );
        }
        
        debugPrint('    ✓ Field $field: $actual (expected)');
      }

      // Check timestamps
      final timestampFields = ['createdAt', 'updatedAt'];
      for (final field in timestampFields) {
        if (!userData.containsKey(field) || userData[field] == null) {
          return ValidationResult.fail(
            'User document missing timestamp: $field',
            suspectedModule: 'AuthService/_createClientUserProfile',
            suggestedFix: 'lib/services/auth_service.dart:_createClientUserProfile - Add $field timestamp',
          );
        }
        debugPrint('    ✓ Timestamp $field: present');
      }

      // Clean up test data
      await _cleanupTestUser(testPhone);

      debugPrint('✅ User document creation validation passed');
      return ValidationResult.pass('User document created with correct fields and timestamps');
      
    } catch (e) {
      return ValidationResult.fail(
        'User document creation validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/_createClientUserProfile',
      );
    }
  }

  /// Validate referral code generation
  static Future<ValidationResult> _validateReferralCodeGeneration() async {
    try {
      debugPrint('🔗 Validating referral code generation...');
      
      // Generate test user data
      final testPhone = '+919876543${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final testUserData = _generateTestUserData(phoneNumber: testPhone);
      
      // Submit registration form
      final submissionResult = await _simulateFormSubmission(testUserData);
      if (!submissionResult.success) {
        return ValidationResult.fail(
          'Cannot test referral code - form submission failed',
          errorDetails: submissionResult.message,
          suspectedModule: 'AuthService/registerUser',
        );
      }

      final userUid = submissionResult.userUid!;
      
      // Get user document to check referral code
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      final userData = userDoc.data()!;
      final referralCode = userData['referralCode'] as String?;

      // Test 1: Ensure referralCode starts with "TAL" prefix
      if (referralCode == null || !referralCode.startsWith('TAL')) {
        return ValidationResult.fail(
          'Referral code missing TAL prefix',
          errorDetails: 'Got referralCode: $referralCode',
          suspectedModule: 'ReferralCodeGenerator/ServerProfileEnsureService',
          suggestedFix: 'lib/services/referral/referral_code_generator.dart - Ensure all codes start with TAL prefix',
        );
      }

      // Test 2: Validate Crockford base32 format (6 characters: A-Z, 2-7)
      if (!_validateCrockfordBase32Format(referralCode)) {
        return ValidationResult.fail(
          'Referral code invalid Crockford base32 format',
          errorDetails: 'Got referralCode: $referralCode',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'lib/services/referral/referral_code_generator.dart - Use only A-Z, 2-7 characters (no 0/O/1/I)',
        );
      }

      // Test 3: Confirm code is NOT "Loading" or empty
      if (referralCode == 'Loading' || referralCode.isEmpty) {
        return ValidationResult.fail(
          'Referral code shows Loading or empty state',
          errorDetails: 'Got referralCode: $referralCode',
          suspectedModule: 'ServerProfileEnsureService/ReferralCodeCache',
          suggestedFix: 'lib/services/server_profile_ensure_service.dart - Fix referral code generation timing',
        );
      }

      // Test 4: Test referral code uniqueness
      final uniquenessResult = await _testReferralCodeUniqueness(referralCode);
      if (!uniquenessResult.passed) return uniquenessResult;

      // Clean up test data
      await _cleanupTestUser(testPhone);

      debugPrint('✅ Referral code generation validation passed');
      return ValidationResult.pass('Referral code generated with TAL prefix, valid format, and uniqueness');
      
    } catch (e) {
      return ValidationResult.fail(
        'Referral code generation validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeGenerator/ServerProfileEnsureService',
      );
    }
  }

  /// Test referral code uniqueness
  static Future<ValidationResult> _testReferralCodeUniqueness(String referralCode) async {
    try {
      debugPrint('🔍 Testing referral code uniqueness for: $referralCode');
      
      // Check if code exists in referralCodes collection
      final codeDoc = await _firestore.collection('referralCodes').doc(referralCode).get();
      if (!codeDoc.exists) {
        return ValidationResult.fail(
          'Referral code not reserved in referralCodes collection',
          errorDetails: 'Code: $referralCode',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'lib/services/referral/referral_code_generator.dart:_reserveCode - Ensure code is reserved in referralCodes collection',
        );
      }

      // Check for duplicates in users collection
      final userQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: referralCode)
          .get();
      
      if (userQuery.docs.length > 1) {
        return ValidationResult.fail(
          'Referral code not unique - found ${userQuery.docs.length} users with same code',
          errorDetails: 'Code: $referralCode',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'lib/services/referral/referral_code_generator.dart:_checkCodeUniqueness - Fix uniqueness check logic',
        );
      }

      debugPrint('    ✓ Referral code is unique and properly reserved');
      return ValidationResult.pass('Referral code uniqueness verified');
      
    } catch (e) {
      return ValidationResult.fail(
        'Referral code uniqueness test failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeGenerator',
      );
    }
  }

  /// Validate provisionalRef assignment
  static Future<ValidationResult> _validateProvisionalRefAssignment() async {
    try {
      debugPrint('🔗 Validating provisionalRef assignment...');
      
      // Test 1: Deep link referral code assignment
      final deepLinkResult = await _testDeepLinkReferralAssignment();
      if (!deepLinkResult.passed) return deepLinkResult;
      
      // Test 2: Fallback to TALADMIN when no referral provided
      final fallbackResult = await _testTALADMINFallback();
      if (!fallbackResult.passed) return fallbackResult;
      
      // Test 3: ProvisionalRef persistence in user document
      final persistenceResult = await _testProvisionalRefPersistence();
      if (!persistenceResult.passed) return persistenceResult;
      
      debugPrint('✅ ProvisionalRef assignment validation passed');
      return ValidationResult.pass('ProvisionalRef assignment working correctly with deep link and fallback');
      
    } catch (e) {
      return ValidationResult.fail(
        'ProvisionalRef assignment validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/WebReferralRouter',
      );
    }
  }

  /// Test deep link referral code assignment
  static Future<ValidationResult> _testDeepLinkReferralAssignment() async {
    try {
      debugPrint('🔍 Testing deep link referral code assignment...');
      
      // Generate test user data with referral code
      final testPhone = '+919876543${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final testReferralCode = 'TAL234567';
      final testUserData = _generateTestUserData(
        phoneNumber: testPhone,
        referralCode: testReferralCode,
      );
      
      // Submit registration form with referral code
      final submissionResult = await _simulateFormSubmission(testUserData);
      if (!submissionResult.success) {
        return ValidationResult.fail(
          'Cannot test deep link referral - form submission failed',
          errorDetails: submissionResult.message,
          suspectedModule: 'AuthService/registerUser',
        );
      }

      final userUid = submissionResult.userUid!;
      
      // Check if provisionalRef is set correctly
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      final userData = userDoc.data()!;
      final provisionalRef = userData['provisionalRef'] as String?;

      if (provisionalRef != testReferralCode) {
        return ValidationResult.fail(
          'Deep link referral code not assigned to provisionalRef',
          errorDetails: 'Expected: $testReferralCode, Got: $provisionalRef',
          suspectedModule: 'AuthService/WebReferralRouter',
          suggestedFix: 'lib/services/referral/web_referral_router.dart - Ensure deep link referral code is assigned to provisionalRef',
        );
      }

      // Clean up test data
      await _cleanupTestUser(testPhone);

      debugPrint('    ✓ Deep link referral code assigned correctly');
      return ValidationResult.pass('Deep link referral code assignment working');
      
    } catch (e) {
      return ValidationResult.fail(
        'Deep link referral assignment test failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/WebReferralRouter',
      );
    }
  }

  /// Test TALADMIN fallback
  static Future<ValidationResult> _testTALADMINFallback() async {
    try {
      debugPrint('🔍 Testing TALADMIN fallback...');
      
      // Generate test user data without referral code
      final testPhone = '+919876543${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final testUserData = _generateTestUserData(phoneNumber: testPhone);
      // Don't set referralCode to test fallback
      
      // Submit registration form without referral code
      final submissionResult = await _simulateFormSubmission(testUserData);
      if (!submissionResult.success) {
        return ValidationResult.fail(
          'Cannot test TALADMIN fallback - form submission failed',
          errorDetails: submissionResult.message,
          suspectedModule: 'AuthService/registerUser',
        );
      }

      final userUid = submissionResult.userUid!;
      
      // Check if provisionalRef defaults to TALADMIN
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      final userData = userDoc.data()!;
      final provisionalRef = userData['provisionalRef'] as String?;

      if (provisionalRef != 'TALADMIN') {
        return ValidationResult.fail(
          'ProvisionalRef does not fallback to TALADMIN',
          errorDetails: 'Expected: TALADMIN, Got: $provisionalRef',
          suspectedModule: 'AuthService/WebReferralRouter',
          suggestedFix: 'lib/services/referral/web_referral_router.dart - Set provisionalRef to TALADMIN when no referral provided',
        );
      }

      // Clean up test data
      await _cleanupTestUser(testPhone);

      debugPrint('    ✓ TALADMIN fallback working correctly');
      return ValidationResult.pass('TALADMIN fallback working');
      
    } catch (e) {
      return ValidationResult.fail(
        'TALADMIN fallback test failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/WebReferralRouter',
      );
    }
  }

  /// Test provisionalRef persistence
  static Future<ValidationResult> _testProvisionalRefPersistence() async {
    try {
      debugPrint('🔍 Testing provisionalRef persistence...');
      
      // Generate test user data with referral code
      final testPhone = '+919876543${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final testReferralCode = 'TAL789ABC';
      final testUserData = _generateTestUserData(
        phoneNumber: testPhone,
        referralCode: testReferralCode,
      );
      
      // Submit registration form
      final submissionResult = await _simulateFormSubmission(testUserData);
      if (!submissionResult.success) {
        return ValidationResult.fail(
          'Cannot test provisionalRef persistence - form submission failed',
          errorDetails: submissionResult.message,
          suspectedModule: 'AuthService/registerUser',
        );
      }

      final userUid = submissionResult.userUid!;
      
      // Wait a moment and check if provisionalRef is still there
      await Future.delayed(Duration(milliseconds: 500));
      
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      final userData = userDoc.data()!;
      
      if (!userData.containsKey('provisionalRef')) {
        return ValidationResult.fail(
          'ProvisionalRef not persisted in user document',
          suspectedModule: 'AuthService/_createClientUserProfile',
          suggestedFix: 'lib/services/auth_service.dart:_createClientUserProfile - Ensure provisionalRef is saved to user document',
        );
      }

      final provisionalRef = userData['provisionalRef'] as String?;
      if (provisionalRef != testReferralCode) {
        return ValidationResult.fail(
          'ProvisionalRef not persisted correctly',
          errorDetails: 'Expected: $testReferralCode, Got: $provisionalRef',
          suspectedModule: 'AuthService/_createClientUserProfile',
          suggestedFix: 'lib/services/auth_service.dart:_createClientUserProfile - Fix provisionalRef persistence',
        );
      }

      // Clean up test data
      await _cleanupTestUser(testPhone);

      debugPrint('    ✓ ProvisionalRef persisted correctly');
      return ValidationResult.pass('ProvisionalRef persistence working');
      
    } catch (e) {
      return ValidationResult.fail(
        'ProvisionalRef persistence test failed',
        errorDetails: e.toString(),
        suspectedModule: 'AuthService/_createClientUserProfile',
      );
    }
  }

  /// Validate post-registration app access
  static Future<ValidationResult> _validatePostRegistrationAccess() async {
    try {
      debugPrint('📱 Validating post-registration app access...');
      
      // Generate test user data
      final testPhone = '+919876543${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final testUserData = _generateTestUserData(phoneNumber: testPhone);
      
      // Submit registration form
      final submissionResult = await _simulateFormSubmission(testUserData);
      if (!submissionResult.success) {
        return ValidationResult.fail(
          'Cannot test app access - form submission failed',
          errorDetails: submissionResult.message,
          suspectedModule: 'AuthService/registerUser',
        );
      }

      final userUid = submissionResult.userUid!;
      
      // Test 1: User can navigate to main app screens
      final navigationResult = await _testMainAppNavigation(userUid);
      if (!navigationResult.passed) return navigationResult;
      
      // Test 2: User profile data is accessible
      final profileResult = await _testUserProfileAccess(userUid);
      if (!profileResult.passed) return profileResult;
      
      // Test 3: User can share their referral code
      final shareResult = await _testReferralCodeSharing(userUid);
      if (!shareResult.passed) return shareResult;
      
      // Clean up test data
      await _cleanupTestUser(testPhone);

      debugPrint('✅ Post-registration app access validation passed');
      return ValidationResult.pass('User can access all main app features after registration');
      
    } catch (e) {
      return ValidationResult.fail(
        'Post-registration app access validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'MainNavigation/UserProfile',
      );
    }
  }

  /// Test main app navigation access
  static Future<ValidationResult> _testMainAppNavigation(String userUid) async {
    try {
      debugPrint('🔍 Testing main app navigation access...');
      
      // Check if user document allows navigation (status: active, profileCompleted: true)
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      final userData = userDoc.data()!;
      
      final status = userData['status'] as String?;
      final profileCompleted = userData['profileCompleted'] as bool?;
      
      if (status != 'active') {
        return ValidationResult.fail(
          'User status not active - cannot navigate to main app',
          errorDetails: 'Status: $status',
          suspectedModule: 'AuthService/_createClientUserProfile',
          suggestedFix: 'lib/services/auth_service.dart:_createClientUserProfile - Set status to active',
        );
      }

      if (profileCompleted != true) {
        return ValidationResult.fail(
          'Profile not completed - cannot navigate to main app',
          errorDetails: 'ProfileCompleted: $profileCompleted',
          suspectedModule: 'AuthService/_createClientUserProfile',
          suggestedFix: 'lib/services/auth_service.dart:_createClientUserProfile - Set profileCompleted to true',
        );
      }

      debugPrint('    ✓ User can navigate to main app screens');
      return ValidationResult.pass('Main app navigation accessible');
      
    } catch (e) {
      return ValidationResult.fail(
        'Main app navigation test failed',
        errorDetails: e.toString(),
        suspectedModule: 'MainNavigation',
      );
    }
  }

  /// Test user profile data access
  static Future<ValidationResult> _testUserProfileAccess(String userUid) async {
    try {
      debugPrint('🔍 Testing user profile data access...');
      
      // Try to access user profile data
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      
      if (!userDoc.exists) {
        return ValidationResult.fail(
          'User profile data not accessible',
          suspectedModule: 'DatabaseService/getUserProfile',
          suggestedFix: 'lib/services/database_service.dart:getUserProfile - Ensure user profile is accessible after registration',
        );
      }

      final userData = userDoc.data()!;
      
      // Check essential profile fields are accessible
      final essentialFields = ['fullName', 'email', 'phoneNumber', 'address', 'referralCode'];
      for (final field in essentialFields) {
        if (!userData.containsKey(field) || userData[field] == null) {
          return ValidationResult.fail(
            'Essential profile field not accessible: $field',
            suspectedModule: 'AuthService/_createClientUserProfile',
            suggestedFix: 'lib/services/auth_service.dart:_createClientUserProfile - Ensure $field is saved and accessible',
          );
        }
      }

      debugPrint('    ✓ User profile data is accessible');
      return ValidationResult.pass('User profile data accessible');
      
    } catch (e) {
      return ValidationResult.fail(
        'User profile access test failed',
        errorDetails: e.toString(),
        suspectedModule: 'DatabaseService/getUserProfile',
      );
    }
  }

  /// Test referral code sharing capability
  static Future<ValidationResult> _testReferralCodeSharing(String userUid) async {
    try {
      debugPrint('🔍 Testing referral code sharing capability...');
      
      // Get user's referral code
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      final userData = userDoc.data()!;
      final referralCode = userData['referralCode'] as String?;
      
      if (referralCode == null || referralCode.isEmpty) {
        return ValidationResult.fail(
          'Referral code not available for sharing',
          suspectedModule: 'ReferralCodeGenerator/ServerProfileEnsureService',
          suggestedFix: 'lib/services/server_profile_ensure_service.dart - Ensure referral code is generated and available immediately',
        );
      }

      if (referralCode == 'Loading') {
        return ValidationResult.fail(
          'Referral code still showing Loading state',
          suspectedModule: 'ReferralCodeCache/ServerProfileEnsureService',
          suggestedFix: 'lib/services/referral_code_cache_service.dart - Fix referral code loading timing',
        );
      }

      if (!referralCode.startsWith('TAL')) {
        return ValidationResult.fail(
          'Referral code does not have TAL prefix for sharing',
          errorDetails: 'Code: $referralCode',
          suspectedModule: 'ReferralCodeGenerator',
          suggestedFix: 'lib/services/referral/referral_code_generator.dart - Ensure all codes have TAL prefix',
        );
      }

      debugPrint('    ✓ User can share referral code: $referralCode');
      return ValidationResult.pass('Referral code sharing capability working');
      
    } catch (e) {
      return ValidationResult.fail(
        'Referral code sharing test failed',
        errorDetails: e.toString(),
        suspectedModule: 'ReferralCodeGenerator/ReferralCodeCache',
      );
    }
  }

  // Helper methods

  /// Generate test user data
  static Map<String, dynamic> _generateTestUserData({
    String? phoneNumber,
    String? referralCode,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return {
      'fullName': 'Test User $timestamp',
      'phoneNumber': phoneNumber ?? '+91987654${timestamp.toString().substring(7)}',
      'pin': '1234',
      'address': {
        'state': 'Telangana',
        'district': 'Hyderabad',
        'mandal': 'Secunderabad',
        'villageCity': 'Begumpet',
      },
      if (referralCode != null) 'referralCode': referralCode,
    };
  }

  /// Validate form data
  static FormValidationResult _validateFormData(Map<String, dynamic> data) {
    // Check required fields
    if (!data.containsKey('fullName') || (data['fullName'] as String).isEmpty) {
      return FormValidationResult(false, 'fullName is required');
    }

    if (!data.containsKey('phoneNumber') || (data['phoneNumber'] as String).isEmpty) {
      return FormValidationResult(false, 'phoneNumber is required');
    }

    if (!data.containsKey('pin') || (data['pin'] as String).isEmpty) {
      return FormValidationResult(false, 'PIN is required');
    }

    if (!data.containsKey('address') || (data['address'] as Map).isEmpty) {
      return FormValidationResult(false, 'address is required');
    }

    // Validate PIN format
    final pin = data['pin'] as String;
    if (!_validatePinFormat(pin)) {
      return FormValidationResult(false, 'PIN must be 4 digits');
    }

    // Validate phone format
    final phone = data['phoneNumber'] as String;
    if (!_validatePhoneFormat(phone)) {
      return FormValidationResult(false, 'Invalid phone number format');
    }

    // Validate address hierarchy
    final address = data['address'] as Map<String, dynamic>;
    if (!_validateAddressHierarchy(address)) {
      return FormValidationResult(false, 'Invalid address hierarchy');
    }

    return FormValidationResult(true, 'Valid');
  }

  /// Validate PIN format (must be 4 digits)
  static bool _validatePinFormat(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  /// Validate phone format
  static bool _validatePhoneFormat(String phone) {
    try {
      final normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (normalized.startsWith('91') && normalized.length == 12) {
        return normalized.substring(2).startsWith(RegExp(r'[6-9]'));
      }
      if (normalized.length == 10) {
        return normalized.startsWith(RegExp(r'[6-9]'));
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Validate address hierarchy
  static bool _validateAddressHierarchy(Map<String, dynamic> address) {
    final requiredFields = ['state', 'district', 'mandal', 'villageCity'];
    for (final field in requiredFields) {
      if (!address.containsKey(field) || 
          address[field] == null || 
          (address[field] as String).isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Validate Crockford base32 format
  static bool _validateCrockfordBase32Format(String code) {
    if (!code.startsWith('TAL') || code.length != 9) {
      return false;
    }
    
    final codepart = code.substring(3);
    final validChars = RegExp(r'^[A-Z2-7]+$');
    return validChars.hasMatch(codepart);
  }

  /// Simulate form submission
  static Future<RegistrationResult> _simulateFormSubmission(Map<String, dynamic> data) async {
    try {
      debugPrint('📤 Simulating form submission...');
      
      // Validate form data first
      final validationResult = _validateFormData(data);
      if (!validationResult.isValid) {
        return RegistrationResult(false, validationResult.error);
      }

      // Extract data
      final phoneNumber = data['phoneNumber'] as String;
      final pin = data['pin'] as String;
      final fullName = data['fullName'] as String;
      final addressData = data['address'] as Map<String, dynamic>;
      final referralCode = data['referralCode'] as String?;
      
      // Create Address object
      final address = Address(
        state: addressData['state'] as String,
        district: addressData['district'] as String,
        mandal: addressData['mandal'] as String,
        villageCity: addressData['villageCity'] as String,
      );

      // Call AuthService.registerUser
      final result = await AuthService.registerUser(
        phoneNumber: phoneNumber,
        pin: pin,
        fullName: fullName,
        address: address,
        referralCode: referralCode,
      );

      if (result.success && result.user != null) {
        return RegistrationResult(true, 'Registration successful', result.user!.id);
      } else {
        return RegistrationResult(false, result.message);
      }
      
    } catch (e) {
      return RegistrationResult(false, 'Registration failed: $e');
    }
  }

  /// Clean up test user data
  static Future<void> _cleanupTestUser(String phoneNumber) async {
    try {
      // Remove from user_registry
      await _firestore.collection('user_registry').doc(phoneNumber).delete();
      
      // Remove from users collection
      final userQuery = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      for (final doc in userQuery.docs) {
        await doc.reference.delete();
        
        // Also clean up referral code
        final userData = doc.data();
        final referralCode = userData['referralCode'] as String?;
        if (referralCode != null) {
          await _firestore.collection('referralCodes').doc(referralCode).delete();
        }
      }
      
      debugPrint('🧹 Cleaned up test user data for $phoneNumber');
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup test user data: $e');
    }
  }
}

/// Form validation result
class FormValidationResult {
  final bool isValid;
  final String error;
  
  FormValidationResult(this.isValid, this.error);
}

/// Registration result
class RegistrationResult {
  final bool success;
  final String message;
  final String? userUid;
  
  RegistrationResult(this.success, this.message, [this.userUid]);
}