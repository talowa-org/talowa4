// Test script to verify registration fixes
// Run this to test the complete registration flow

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/hybrid_auth_service.dart';
import 'lib/services/auth_service.dart';
import 'lib/services/database_service.dart';
import 'lib/models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  print('🚀 Starting Registration Fix Test...\n');

  await testRegistrationFlow();
}

Future<void> testRegistrationFlow() async {
  final testPhone = '9876543210';
  final testPin = '123456';
  final testName = 'Test User';

  print('📱 Testing registration for: +91$testPhone');

  try {
    // Test 1: Check if phone is already registered
    print('\n1️⃣ Checking if phone is already registered...');
    final isRegistered = await HybridAuthService.isMobileRegistered(testPhone);
    print(
      '   Result: ${isRegistered ? "Already registered" : "Not registered"}',
    );

    if (isRegistered) {
      print('   ⚠️  Phone already registered. Skipping registration test.');
      await testLoginFlow(testPhone, testPin);
      return;
    }

    // Test 2: Register with HybridAuthService
    print('\n2️⃣ Testing HybridAuthService registration...');
    final authResult = await HybridAuthService.registerWithMobileAndPin(
      mobileNumber: testPhone,
      pin: testPin,
    );

    print('   Success: ${authResult.success}');
    print('   Message: ${authResult.message}');

    if (!authResult.success) {
      print('   ❌ Registration failed: ${authResult.message}');
      return;
    }

    final userId = authResult.user?.uid;
    if (userId == null) {
      print('   ❌ No user ID returned');
      return;
    }

    print('   ✅ User created with ID: $userId');

    // Test 3: Verify user profile exists
    print('\n3️⃣ Checking user profile in Firestore...');
    final userProfile = await DatabaseService.getUserProfile(userId);

    if (userProfile != null) {
      print('   ✅ User profile found');
      print('   📧 Email: ${userProfile.email}');
      print('   📱 Phone: ${userProfile.phone}');
      print('   🔗 Referral Code: ${userProfile.referralCode}');
      print('   💰 Membership Paid: ${userProfile.membershipPaid}');
      print('   ✅ Status: ${userProfile.status}');
    } else {
      print('   ❌ User profile NOT found');
    }

    // Test 4: Verify user registry exists
    print('\n4️⃣ Checking user registry...');
    final registryExists = await DatabaseService.isPhoneRegistered(
      '+91$testPhone',
    );
    print('   Registry exists: ${registryExists ? "✅ YES" : "❌ NO"}');

    // Test 5: Verify referral code is working
    print('\n5️⃣ Testing referral code functionality...');
    if (userProfile?.referralCode != null) {
      // Try to find user by referral code
      final firestore = FirebaseFirestore.instance;
      final referralQuery = await firestore
          .collection('users')
          .where('referralCode', isEqualTo: userProfile!.referralCode)
          .limit(1)
          .get();

      if (referralQuery.docs.isNotEmpty) {
        print('   ✅ Referral code lookup successful');
        print('   🔗 Code: ${userProfile.referralCode}');
      } else {
        print('   ❌ Referral code lookup failed');
      }

      // Check referralCodes collection
      final codeDoc = await firestore
          .collection('referralCodes')
          .doc(userProfile.referralCode)
          .get();

      if (codeDoc.exists) {
        print('   ✅ Referral code document exists in referralCodes collection');
        print('   📊 Data: ${codeDoc.data()}');
      } else {
        print(
          '   ❌ Referral code document NOT found in referralCodes collection',
        );
      }
    }

    // Test 6: Test login with created account
    print('\n6️⃣ Testing login with created account...');
    await testLoginFlow(testPhone, testPin);

    print('\n🎉 Registration test completed successfully!');
  } catch (e, stackTrace) {
    print('\n❌ Registration test failed with error: $e');
    print('Stack trace: $stackTrace');
  }
}

Future<void> testLoginFlow(String phone, String pin) async {
  try {
    final loginResult = await HybridAuthService.signInWithMobileAndPin(
      mobileNumber: phone,
      pin: pin,
    );

    print('   Login Success: ${loginResult.success}');
    print('   Login Message: ${loginResult.message}');

    if (loginResult.success && loginResult.user != null) {
      print('   ✅ Login successful');
      print('   👤 User ID: ${loginResult.user!.uid}');
    } else {
      print('   ❌ Login failed');
    }
  } catch (e) {
    print('   ❌ Login error: $e');
  }
}
