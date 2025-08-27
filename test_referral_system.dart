import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/referral/cloud_referral_service.dart';

/// Comprehensive test suite for the robust referral system
/// Run this to validate all referral functionality
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 TALOWA Referral System Test Suite');
  print('=====================================');
  
  await runReferralTests();
}

Future<void> runReferralTests() async {
  try {
    // Test 1: Referral Code Format Validation
    await testReferralCodeFormat();
    
    // Test 2: Referral Code Generation (requires auth)
    // await testReferralCodeGeneration();
    
    // Test 3: Referral Code Application (requires auth)
    // await testReferralCodeApplication();
    
    // Test 4: Referral Statistics (requires auth)
    // await testReferralStatistics();
    
    // Test 5: Link Generation
    await testLinkGeneration();
    
    print('\n✅ All tests completed successfully!');
    
  } catch (e, stackTrace) {
    print('\n❌ Test suite failed: $e');
    print('Stack trace: $stackTrace');
  }
}

Future<void> testReferralCodeFormat() async {
  print('\n📋 Test 1: Referral Code Format Validation');
  print('------------------------------------------');
  
  final testCases = [
    // Valid codes (7-8 chars)
    {'code': 'TAL1234567', 'expected': true, 'description': 'Valid 7-char code'},
    {'code': 'TAL12345678', 'expected': true, 'description': 'Valid 8-char code'},
    {'code': 'TALABCDEFG', 'expected': true, 'description': 'Valid with letters'},
    {'code': 'TAL2A3B4C5', 'expected': true, 'description': 'Valid mixed case'},
    {'code': 'tal1234567', 'expected': true, 'description': 'Valid lowercase (normalized)'},
    
    // Invalid codes
    {'code': '', 'expected': false, 'description': 'Empty string'},
    {'code': 'TAL123456', 'expected': false, 'description': 'Too short (6 chars)'},
    {'code': 'TAL123456789', 'expected': false, 'description': 'Too long (9 chars)'},
    {'code': 'ABC1234567', 'expected': false, 'description': 'Wrong prefix'},
    {'code': 'TAL123456O', 'expected': false, 'description': 'Contains ambiguous O'},
    {'code': 'TAL123456I', 'expected': false, 'description': 'Contains ambiguous I'},
    {'code': 'TAL123456L', 'expected': false, 'description': 'Contains ambiguous L'},
    {'code': 'TAL1234561', 'expected': false, 'description': 'Contains ambiguous 1'},
    {'code': 'TAL1234560', 'expected': false, 'description': 'Contains ambiguous 0'},
  ];
  
  int passed = 0;
  int failed = 0;
  
  for (final testCase in testCases) {
    final code = testCase['code'] as String;
    final expected = testCase['expected'] as bool;
    final description = testCase['description'] as String;
    
    final result = CloudReferralService.isValidCodeFormat(code);
    
    if (result == expected) {
      print('  ✅ $description: "$code" -> $result');
      passed++;
    } else {
      print('  ❌ $description: "$code" -> $result (expected $expected)');
      failed++;
    }
  }
  
  print('\nFormat validation results: $passed passed, $failed failed');
  
  if (failed > 0) {
    throw Exception('Referral code format validation failed');
  }
}

Future<void> testReferralCodeGeneration() async {
  print('\n🔧 Test 2: Referral Code Generation');
  print('-----------------------------------');
  
  // This test requires authentication
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('  ⚠️  Skipping - requires authentication');
    return;
  }
  
  try {
    print('  📝 Generating referral code...');
    final code = await CloudReferralService.reserveReferralCode();
    
    print('  ✅ Generated code: $code');
    
    // Validate format
    if (!CloudReferralService.isValidCodeFormat(code)) {
      throw Exception('Generated code has invalid format: $code');
    }
    
    // Test idempotency - should return same code
    print('  🔄 Testing idempotency...');
    final code2 = await CloudReferralService.reserveReferralCode();
    
    if (code != code2) {
      throw Exception('Code generation not idempotent: $code != $code2');
    }
    
    print('  ✅ Idempotency test passed');
    
  } catch (e) {
    print('  ❌ Code generation failed: $e');
    rethrow;
  }
}

Future<void> testReferralCodeApplication() async {
  print('\n🎯 Test 3: Referral Code Application');
  print('------------------------------------');
  
  // This test requires authentication and a valid referral code
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('  ⚠️  Skipping - requires authentication');
    return;
  }
  
  // Test with invalid codes first
  final invalidCodes = ['INVALID', 'TAL12345', 'NONEXISTENT'];
  
  for (final invalidCode in invalidCodes) {
    try {
      print('  🚫 Testing invalid code: $invalidCode');
      await CloudReferralService.applyReferralCode(invalidCode);
      print('  ❌ Should have failed for invalid code: $invalidCode');
    } catch (e) {
      print('  ✅ Correctly rejected invalid code: $invalidCode');
    }
  }
  
  // Test self-referral prevention would require creating a code first
  print('  ⚠️  Self-referral test requires manual setup');
}

Future<void> testReferralStatistics() async {
  print('\n📊 Test 4: Referral Statistics');
  print('------------------------------');
  
  // This test requires authentication
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('  ⚠️  Skipping - requires authentication');
    return;
  }
  
  try {
    print('  📈 Fetching referral statistics...');
    final stats = await CloudReferralService.getMyReferralStats();
    
    print('  ✅ Stats retrieved successfully');
    print('     Code: ${stats.code ?? "None"}');
    print('     Direct referrals: ${stats.directCount}');
    print('     Recent referrals: ${stats.recentReferrals.length}');
    
    // Validate data structure
    if (stats.directCount < 0) {
      throw Exception('Invalid direct count: ${stats.directCount}');
    }
    
    if (stats.recentReferrals.length > 20) {
      throw Exception('Too many recent referrals: ${stats.recentReferrals.length}');
    }
    
    print('  ✅ Statistics validation passed');
    
  } catch (e) {
    print('  ❌ Statistics test failed: $e');
    rethrow;
  }
}

Future<void> testLinkGeneration() async {
  print('\n🔗 Test 5: Link Generation');
  print('--------------------------');
  
  final testCode = 'TAL1234567';
  
  // Test regular link
  final regularLink = CloudReferralService.generateReferralLink(testCode);
  print('  📎 Regular link: $regularLink');
  
  if (!regularLink.contains('talowa.web.app')) {
    throw Exception('Invalid regular link domain');
  }
  
  if (!regularLink.contains('ref=$testCode')) {
    throw Exception('Regular link missing referral code parameter');
  }
  
  // Test short link
  final shortLink = CloudReferralService.generateShortReferralLink(testCode);
  print('  📎 Short link: $shortLink');
  
  if (!shortLink.contains('talowa.web.app')) {
    throw Exception('Invalid short link domain');
  }
  
  print('  ✅ Link generation tests passed');
}

/// Manual test scenarios for comprehensive validation
void printManualTestScenarios() {
  print('\n🧪 Manual Test Scenarios');
  print('========================');
  
  print('\n1. Registration Flow Tests:');
  print('   a. Register without referral code');
  print('   b. Register with valid referral code');
  print('   c. Register with invalid referral code');
  print('   d. Register with own referral code (should be blocked)');
  
  print('\n2. Referral Dashboard Tests:');
  print('   a. View dashboard without referral code');
  print('   b. Generate referral code');
  print('   c. Copy referral code');
  print('   d. Share referral link');
  print('   e. View referral statistics');
  
  print('\n3. Deep Link Tests:');
  print('   a. Open https://talowa.web.app/?ref=TAL123456');
  print('   b. Verify code auto-fills in registration');
  print('   c. Complete registration with deep link code');
  
  print('\n4. Fraud Prevention Tests:');
  print('   a. Try to use own referral code');
  print('   b. Try to apply referral code twice');
  print('   c. Try to use inactive referral code');
  
  print('\n5. Edge Case Tests:');
  print('   a. Network failure during code generation');
  print('   b. Network failure during code application');
  print('   c. Concurrent code generation attempts');
  print('   d. Invalid authentication token');
  
  print('\n6. Performance Tests:');
  print('   a. Generate 100 referral codes (collision detection)');
  print('   b. Apply referral codes with high concurrency');
  print('   c. Load referral statistics with many referrals');
}

/// Firestore data validation
Future<void> validateFirestoreData() async {
  print('\n🗄️  Firestore Data Validation');
  print('=============================');
  
  final db = FirebaseFirestore.instance;
  
  try {
    // Check referralCodes collection structure
    print('  📋 Checking referralCodes collection...');
    final codesQuery = await db.collection('referralCodes').limit(1).get();
    
    if (codesQuery.docs.isNotEmpty) {
      final codeDoc = codesQuery.docs.first;
      final data = codeDoc.data();
      
      final requiredFields = ['uid', 'reservedAt', 'active'];
      for (final field in requiredFields) {
        if (!data.containsKey(field)) {
          throw Exception('Missing required field in referralCodes: $field');
        }
      }
      print('  ✅ referralCodes structure valid');
    } else {
      print('  ⚠️  No referral codes found');
    }
    
    // Check users collection referral fields
    print('  👤 Checking users collection referral fields...');
    final usersQuery = await db.collection('users').limit(1).get();
    
    if (usersQuery.docs.isNotEmpty) {
      final userDoc = usersQuery.docs.first;
      final data = userDoc.data();
      
      if (data.containsKey('referral')) {
        final referralData = data['referral'] as Map<String, dynamic>;
        print('  ✅ User referral fields found: ${referralData.keys}');
      } else {
        print('  ⚠️  No referral fields in user document');
      }
    } else {
      print('  ⚠️  No users found');
    }
    
    print('  ✅ Firestore data validation completed');
    
  } catch (e) {
    print('  ❌ Firestore validation failed: $e');
    rethrow;
  }
}