// TALOWA Admin Bootstrap Validator
// Verifies admin user setup and TALADMIN referral code system

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'validation_framework.dart';

/// Admin bootstrap validator
class AdminBootstrapValidator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Admin user requirements
  static const String adminPhone = '+917981828388';
  static const String adminEmail = '+917981828388@talowa.app';
  static const String adminReferralCode = 'TALADMIN';

  /// Comprehensive admin bootstrap verification
  static Future<ValidationResult> verifyAdminBootstrap() async {
    try {
      debugPrint('ðŸ” Starting admin bootstrap verification...');
      
      // Step 1: Check user_registry
      final registryResult = await _verifyUserRegistry();
      if (!registryResult.passed) return registryResult;
      
      // Step 2: Check users collection
      final usersResult = await _verifyUsersCollection();
      if (!usersResult.passed) return usersResult;
      
      // Step 3: Check referral code mapping
      final referralResult = await _verifyReferralCodeMapping();
      if (!referralResult.passed) return referralResult;
      
      // Step 4: Verify admin is active and accessible
      final accessResult = await _verifyAdminAccess();
      if (!accessResult.passed) return accessResult;
      
      debugPrint('âœ… Admin bootstrap verification completed successfully');
      return ValidationResult.pass('Admin bootstrap fully verified and functional');
      
    } catch (e) {
      debugPrint('âŒ Admin bootstrap verification failed: $e');
      return ValidationResult.fail(
        'Admin bootstrap verification failed',
        errorDetails: e.toString(),
        suspectedModule: 'BootstrapService',
        suggestedFix: 'lib/services/bootstrap_service.dart:bootstrap - Initialize admin user',
      );
    }
  }

  /// Verify admin user in user_registry
  static Future<ValidationResult> _verifyUserRegistry() async {
    try {
      debugPrint('ðŸ“‹ Checking admin user in user_registry...');
      
      final registryDoc = await _firestore
          .collection('user_registry')
          .doc(adminPhone)
          .get();

      if (!registryDoc.exists) {
        return ValidationResult.fail(
          'Admin user not found in user_registry',
          errorDetails: 'Document user_registry/$adminPhone does not exist',
          suspectedModule: 'BootstrapService',
          suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminUserRegistry - Create admin registry entry',
        );
      }

      final registryData = registryDoc.data()!;
      
      // Validate required fields
      final validations = <String, dynamic>{
        'phone': adminPhone,
        'email': adminEmail,
        'referralCode': adminReferralCode,
        'isActive': true,
        'role': 'national_leadership', // Admin should have highest role
      };

      for (final entry in validations.entries) {
        if (registryData[entry.key] != entry.value) {
          return ValidationResult.fail(
            'Admin user_registry field mismatch: ${entry.key}',
            errorDetails: 'Expected: ${entry.value}, Got: ${registryData[entry.key]}',
            suspectedModule: 'BootstrapService',
            suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminUserRegistry - Fix admin registry fields',
          );
        }
      }

      // Validate UID exists
      if (registryData['uid'] == null || registryData['uid'].toString().isEmpty) {
        return ValidationResult.fail(
          'Admin user_registry missing UID',
          errorDetails: 'UID field is null or empty',
          suspectedModule: 'BootstrapService',
          suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminUserRegistry - Set proper UID',
        );
      }

      debugPrint('âœ… Admin user_registry verification passed');
      return ValidationResult.pass('Admin user_registry entry valid');
      
    } catch (e) {
      return ValidationResult.fail(
        'Admin user_registry verification failed',
        errorDetails: e.toString(),
        suspectedModule: 'Firebase/BootstrapService',
      );
    }
  }

  /// Verify admin user in users collection
  static Future<ValidationResult> _verifyUsersCollection() async {
    try {
      debugPrint('ðŸ‘¤ Checking admin user in users collection...');
      
      // First get the UID from user_registry
      final registryDoc = await _firestore
          .collection('user_registry')
          .doc(adminPhone)
          .get();
      
      if (!registryDoc.exists) {
        return ValidationResult.fail(
          'Cannot verify users collection - registry not found',
          suspectedModule: 'BootstrapService',
        );
      }

      final adminUid = registryDoc.data()!['uid'] as String;
      
      // Check users collection
      final userDoc = await _firestore
          .collection('users')
          .doc(adminUid)
          .get();

      if (!userDoc.exists) {
        return ValidationResult.fail(
          'Admin user not found in users collection',
          errorDetails: 'Document users/$adminUid does not exist',
          suspectedModule: 'BootstrapService',
          suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminUserProfile - Create admin user profile',
        );
      }

      final userData = userDoc.data()!;
      
      // Validate critical fields
      final validations = <String, dynamic>{
        'phoneNumber': adminPhone,
        'email': adminEmail,
        'referralCode': adminReferralCode,
        'role': 'national_leadership',
        'status': 'active',
        'phoneVerified': true,
        'profileCompleted': true,
      };

      for (final entry in validations.entries) {
        if (userData[entry.key] != entry.value) {
          return ValidationResult.fail(
            'Admin users collection field mismatch: ${entry.key}',
            errorDetails: 'Expected: ${entry.value}, Got: ${userData[entry.key]}',
            suspectedModule: 'BootstrapService',
            suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminUserProfile - Fix admin user fields',
          );
        }
      }

      // Validate address structure
      if (userData['address'] == null || userData['address']['state'] != 'Telangana') {
        return ValidationResult.fail(
          'Admin user address invalid',
          errorDetails: 'Address missing or state not Telangana',
          suspectedModule: 'BootstrapService',
          suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminUserProfile - Set proper admin address',
        );
      }

      debugPrint('âœ… Admin users collection verification passed');
      return ValidationResult.pass('Admin users collection entry valid');
      
    } catch (e) {
      return ValidationResult.fail(
        'Admin users collection verification failed',
        errorDetails: e.toString(),
        suspectedModule: 'Firebase/BootstrapService',
      );
    }
  }

  /// Verify TALADMIN referral code mapping
  static Future<ValidationResult> _verifyReferralCodeMapping() async {
    try {
      debugPrint('ðŸ”— Checking TALADMIN referral code mapping...');
      
      // Check if TALADMIN code exists in referralCodes collection
      final codeDoc = await _firestore
          .collection('referralCodes')
          .doc(adminReferralCode)
          .get();

      if (!codeDoc.exists) {
        return ValidationResult.fail(
          'TALADMIN referral code not found',
          errorDetails: 'Document referralCodes/TALADMIN does not exist',
          suspectedModule: 'BootstrapService/ReferralCodeGenerator',
          suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminReferralCode - Create TALADMIN code',
        );
      }

      final codeData = codeDoc.data()!;
      
      // Get admin UID for validation
      final registryDoc = await _firestore
          .collection('user_registry')
          .doc(adminPhone)
          .get();
      final adminUid = registryDoc.data()!['uid'] as String;

      // Validate referral code properties
      final validations = <String, dynamic>{
        'ownerId': adminUid,
        'isActive': true,
        'code': adminReferralCode,
      };

      for (final entry in validations.entries) {
        if (codeData[entry.key] != entry.value) {
          return ValidationResult.fail(
            'TALADMIN referral code field mismatch: ${entry.key}',
            errorDetails: 'Expected: ${entry.value}, Got: ${codeData[entry.key]}',
            suspectedModule: 'BootstrapService/ReferralCodeGenerator',
            suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminReferralCode - Fix TALADMIN code fields',
          );
        }
      }

      debugPrint('âœ… TALADMIN referral code mapping verification passed');
      return ValidationResult.pass('TALADMIN referral code properly mapped');
      
    } catch (e) {
      return ValidationResult.fail(
        'TALADMIN referral code verification failed',
        errorDetails: e.toString(),
        suspectedModule: 'Firebase/ReferralCodeGenerator',
      );
    }
  }

  /// Verify admin access and functionality
  static Future<ValidationResult> _verifyAdminAccess() async {
    try {
      debugPrint('ðŸ” Verifying admin access and functionality...');
      
      // Get admin UID
      final registryDoc = await _firestore
          .collection('user_registry')
          .doc(adminPhone)
          .get();
      final adminUid = registryDoc.data()!['uid'] as String;

      // Test admin can be used for orphan assignment
      final userDoc = await _firestore
          .collection('users')
          .doc(adminUid)
          .get();
      
      if (!userDoc.exists) {
        return ValidationResult.fail(
          'Admin user not accessible',
          suspectedModule: 'BootstrapService',
        );
      }

      final userData = userDoc.data()!;
      
      // Verify admin has proper permissions
      if (userData['role'] != 'national_leadership') {
        return ValidationResult.fail(
          'Admin does not have proper role for orphan assignment',
          errorDetails: 'Role: ${userData['role']}, Expected: national_leadership',
          suspectedModule: 'BootstrapService',
          suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminUserProfile - Set admin role to national_leadership',
        );
      }

      // Verify admin can accept referrals (no usage limit)
      final referralCodeDoc = await _firestore
          .collection('referralCodes')
          .doc(adminReferralCode)
          .get();
      
      final codeData = referralCodeDoc.data()!;
      if (codeData['maxUsage'] != null && codeData['maxUsage'] < 999999) {
        return ValidationResult.fail(
          'Admin referral code has usage limit',
          errorDetails: 'maxUsage: ${codeData['maxUsage']}, should be unlimited',
          suspectedModule: 'BootstrapService/ReferralCodeGenerator',
          suggestedFix: 'lib/services/bootstrap_service.dart:_createAdminReferralCode - Remove usage limit for TALADMIN',
        );
      }

      debugPrint('âœ… Admin access verification passed');
      return ValidationResult.pass('Admin access and functionality verified');
      
    } catch (e) {
      return ValidationResult.fail(
        'Admin access verification failed',
        errorDetails: e.toString(),
        suspectedModule: 'Firebase/BootstrapService',
      );
    }
  }

  /// Create admin bootstrap if missing (fix implementation)
  static Future<ValidationResult> createAdminBootstrap() async {
    try {
      debugPrint('ðŸ”§ Creating admin bootstrap...');
      
      // Generate admin UID
      final adminUid = 'admin_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create user_registry entry
      await _firestore.collection('user_registry').doc(adminPhone).set({
        'uid': adminUid,
        'email': adminEmail,
        'phoneNumber': adminPhone,
        'role': 'national_leadership',
        'state': 'Telangana',
        'district': 'Hyderabad',
        'mandal': 'Admin',
        'village': 'Admin',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'referralCode': adminReferralCode,
        'directReferrals': 0,
        'teamSize': 0,
        'membershipPaid': true,
      });

      // Create users collection entry
      await _firestore.collection('users').doc(adminUid).set({
        'fullName': 'TALOWA Admin',
        'email': adminEmail,
        'emailAlias': adminEmail,
        'phoneNumber': adminPhone,
        'role': 'national_leadership',
        'status': 'active',
        'phoneVerified': true,
        'profileCompleted': true,
        'membershipPaid': true,
        'referralCode': adminReferralCode,
        'directReferrals': 0,
        'teamSize': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'language': 'en',
        'locale': 'en_US',
        'address': {
          'villageCity': 'Hyderabad',
          'mandal': 'Admin',
          'district': 'Hyderabad',
          'state': 'Telangana',
          'pincode': '500001',
        },
        'preferences': {
          'language': 'en',
          'notifications': {
            'push': true,
            'sms': true,
            'email': true,
          },
          'privacy': {
            'showLocation': false,
            'allowDirectContact': true,
          },
        },
      });

      // Create TALADMIN referral code
      await _firestore.collection('referralCodes').doc(adminReferralCode).set({
        'code': adminReferralCode,
        'ownerId': adminUid,
        'isActive': true,
        'usageCount': 0,
        'maxUsage': 999999, // Unlimited for admin
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsedAt': null,
      });

      debugPrint('âœ… Admin bootstrap created successfully');
      return ValidationResult.pass('Admin bootstrap created and configured');
      
    } catch (e) {
      debugPrint('âŒ Admin bootstrap creation failed: $e');
      return ValidationResult.fail(
        'Admin bootstrap creation failed',
        errorDetails: e.toString(),
        suspectedModule: 'AdminBootstrapValidator',
      );
    }
  }

  /// Get admin bootstrap status
  static Future<Map<String, dynamic>> getBootstrapStatus() async {
    try {
      final registryExists = await _firestore
          .collection('user_registry')
          .doc(adminPhone)
          .get()
          .then((doc) => doc.exists);

      final usersExists = registryExists ? await _firestore
          .collection('user_registry')
          .doc(adminPhone)
          .get()
          .then((doc) => doc.data()!['uid'])
          .then((uid) => _firestore.collection('users').doc(uid).get())
          .then((doc) => doc.exists) : false;

      final referralCodeExists = await _firestore
          .collection('referralCodes')
          .doc(adminReferralCode)
          .get()
          .then((doc) => doc.exists);

      return {
        'registryExists': registryExists,
        'usersExists': usersExists,
        'referralCodeExists': referralCodeExists,
        'fullyBootstrapped': registryExists && usersExists && referralCodeExists,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'fullyBootstrapped': false,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}

/// Main function for standalone testing
void main() async {
  print('ðŸ” TALOWA Admin Bootstrap Validator - Standalone Test');
  print('=' * 60);
  
  try {
    // Get current bootstrap status
    print('\nðŸ“Š Checking current bootstrap status...');
    final status = await AdminBootstrapValidator.getBootstrapStatus();
    print('Bootstrap Status: ${status['fullyBootstrapped'] ? 'COMPLETE' : 'INCOMPLETE'}');
    print('Registry Exists: ${status['registryExists']}');
    print('Users Exists: ${status['usersExists']}');
    print('Referral Code Exists: ${status['referralCodeExists']}');
    
    // Run comprehensive verification
    print('\nðŸ” Running comprehensive admin bootstrap verification...');
    final result = await AdminBootstrapValidator.verifyAdminBootstrap();
    
    print('\nðŸ“‹ VERIFICATION RESULT:');
    print('Status: ${result.passed ? 'PASS âœ…' : 'FAIL âŒ'}');
    print('Message: ${result.message}');
    
    if (!result.passed) {
      print('Error Details: ${result.errorDetails}');
      print('Suspected Module: ${result.suspectedModule}');
      print('Suggested Fix: ${result.suggestedFix}');
      
      // Attempt auto-fix if verification failed
      print('\nðŸ”§ Attempting to create admin bootstrap...');
      final createResult = await AdminBootstrapValidator.createAdminBootstrap();
      
      print('Auto-fix Result: ${createResult.passed ? 'SUCCESS âœ…' : 'FAILED âŒ'}');
      print('Message: ${createResult.message}');
      
      if (createResult.passed) {
        print('\nðŸ”„ Re-running verification after auto-fix...');
        final reVerifyResult = await AdminBootstrapValidator.verifyAdminBootstrap();
        print('Re-verification: ${reVerifyResult.passed ? 'PASS âœ…' : 'FAIL âŒ'}');
        print('Message: ${reVerifyResult.message}');
      }
    }
    
    print('\n${'=' * 60}');
    print('Admin Bootstrap Validation Complete');
    
  } catch (e) {
    print('âŒ Standalone test failed: $e');
  }
}
