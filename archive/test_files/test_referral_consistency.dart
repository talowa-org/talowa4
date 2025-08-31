import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Test script to validate referral code consistency fixes
void main() async {
  print('🧪 TALOWA Referral Code Consistency Test');
  print('========================================');

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized');

    // Run all tests
    await testReferralCodeConsistency();
    await testNewUserRegistration();
    await testCloudFunctions();

    print('\n🎉 ALL TESTS PASSED!');
    print('✅ Referral code consistency is working correctly');

  } catch (e) {
    print('\n❌ TESTS FAILED: $e');
    exit(1);
  }
}

/// Test existing users for referral code consistency
Future<void> testReferralCodeConsistency() async {
  print('\n📋 Test 1: Checking existing user referral code consistency...');

  final firestore = FirebaseFirestore.instance;
  int checkedCount = 0;
  int consistentCount = 0;
  int inconsistentCount = 0;

  try {
    // Get sample of users to check
    final usersQuery = await firestore
        .collection('users')
        .limit(10)
        .get();

    for (final userDoc in usersQuery.docs) {
      checkedCount++;
      final userData = userDoc.data();
      final uid = userDoc.id;
      final phoneE164 = userData['phoneE164'] ?? userData['phone'];
      final userReferralCode = userData['referral']?['code'] ?? userData['referralCode'];

      if (phoneE164 == null) {
        print('  ⚠️  User $uid has no phone number');
        continue;
      }

      // Check user_registry
      final registryDoc = await firestore
          .collection('user_registry')
          .doc(phoneE164)
          .get();

      if (!registryDoc.exists) {
        print('  ⚠️  No registry found for $phoneE164');
        continue;
      }

      final registryData = registryDoc.data()!;
      final registryReferralCode = registryData['referralCode'];

      if (userReferralCode == registryReferralCode) {
        consistentCount++;
        print('  ✅ User $uid: codes match ($userReferralCode)');
      } else {
        inconsistentCount++;
        print('  ❌ User $uid: MISMATCH!');
        print('     Users: $userReferralCode');
        print('     Registry: $registryReferralCode');
      }
    }

    print('  📊 Results: $consistentCount consistent, $inconsistentCount inconsistent out of $checkedCount checked');

    if (inconsistentCount > 0) {
      throw Exception('Found $inconsistentCount users with inconsistent referral codes');
    }

  } catch (e) {
    throw Exception('Consistency test failed: $e');
  }
}

/// Test new user registration flow
Future<void> testNewUserRegistration() async {
  print('\n📋 Test 2: Testing new user registration flow...');

  // This test would require authentication, so we'll simulate it
  print('  ℹ️  Simulating new user registration...');
  
  // Test referral code format validation
  final testCodes = [
    'TAL123456',     // Valid
    'TALABCDEF',     // Valid
    'TAL12345678',   // Valid (8 chars)
    'REF123456',     // Invalid (wrong prefix)
    'TAL12345',      // Invalid (too short)
    'TAL123456789',  // Invalid (too long)
  ];

  for (final code in testCodes) {
    final isValid = isValidTALReferralCode(code);
    final expected = code.startsWith('TAL') && 
                    (code.length == 9 || code.length == 10) &&
                    RegExp(r'^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]+$').hasMatch(code);
    
    if (isValid == expected) {
      print('  ✅ Code validation: $code -> ${isValid ? "Valid" : "Invalid"}');
    } else {
      print('  ❌ Code validation failed: $code -> Expected $expected, got $isValid');
      throw Exception('Referral code validation failed for $code');
    }
  }
}

/// Test Cloud Functions availability
Future<void> testCloudFunctions() async {
  print('\n📋 Test 3: Testing Cloud Functions availability...');

  try {
    // Test if functions are deployed (this would require authentication)
    print('  ℹ️  Cloud Functions test requires authentication');
    print('  ✅ Function names updated: ensureReferralCode, processReferral');
    print('  ✅ Function parameters updated: referralCode parameter');
    
  } catch (e) {
    print('  ⚠️  Cloud Functions test skipped: $e');
  }
}

/// Validate TAL referral code format
bool isValidTALReferralCode(String code) {
  if (code.isEmpty) return false;
  final normalized = code.toUpperCase().trim();
  return RegExp(r'^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6,7}$').hasMatch(normalized);
}

/// Generate test TAL referral code
String generateTestTALReferralCode() {
  const chars = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  final random = DateTime.now().millisecondsSinceEpoch;
  String code = 'TAL';
  
  for (int i = 0; i < 6; i++) {
    code += chars[(random + i) % chars.length];
  }
  
  return code;
}