// ⚠️ CRITICAL WARNING - AUTHENTICATION SYSTEM PROTECTION ⚠️
// This is the PRIMARY authentication service from Checkpoint 7
// DO NOT MODIFY without explicit user approval
// See: AUTHENTICATION_PROTECTION_STRATEGY.md
// Working commit: 3a00144 (Checkpoint 6 base)
// Last verified: September 3rd, 2025

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/address.dart' as address_model;
import 'referral/referral_code_generator.dart';
import 'auth_policy.dart';
import 'registration_state_service.dart';

/// Unified Authentication Service for TALOWA
/// Fixes all authentication issues with consistent logic
class UnifiedAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rate limiting storage
  static final Map<String, List<DateTime>> _loginAttempts = {};
  static const int maxAttemptsPerHour = 5;

  // Current user stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  /// Normalize phone number to E164 format
  static String _normalizePhoneNumber(String phoneNumber) {
    return normalizeE164(phoneNumber);
  }

  /// Hash PIN using SHA-256
  static String _hashPin(String pin) {
    return passwordFromPin(pin);
  }

  /// Check if phone number is already registered
  static Future<bool> isPhoneRegistered(String phoneNumber) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      final registrationStatus = await RegistrationStateService.checkRegistrationStatus(normalizedPhone);
      return registrationStatus.isAlreadyRegistered;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking phone registration: $e');
      }
      return false;
    }
  }

  /// Check rate limiting for login attempts
  static bool _canAttemptLogin(String phoneNumber) {
    final now = DateTime.now();
    final attempts = _loginAttempts[phoneNumber] ?? [];
    
    // Remove attempts older than 1 hour
    final recentAttempts = attempts.where(
      (attempt) => now.difference(attempt).inHours < 1
    ).toList();
    
    _loginAttempts[phoneNumber] = recentAttempts;
    
    return recentAttempts.length < maxAttemptsPerHour;
  }

  /// Record login attempt for rate limiting
  static void _recordLoginAttempt(String phoneNumber) {
    final attempts = _loginAttempts[phoneNumber] ?? [];
    attempts.add(DateTime.now());
    _loginAttempts[phoneNumber] = attempts;
  }

  /// Register new user with phone number and PIN
  static Future<AuthResult> registerUser({
    required String phoneNumber,
    required String pin,
    required String fullName,
    required address_model.Address address,
    String? referralCode,
  }) async {
    final startTime = DateTime.now();
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);

    try {
      // Check registration status using the new service
      final registrationStatus = await RegistrationStateService.checkRegistrationStatus(normalizedPhone);
      if (registrationStatus.isAlreadyRegistered) {
        return AuthResult(
          success: false,
          message: registrationStatus.message,
          errorCode: 'phone-already-exists',
        );
      }

      // Create alias email for Firebase Auth
      final email = aliasEmailForPhone(normalizedPhone);
      final hashedPin = _hashPin(pin);

      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: hashedPin,
      );

      if (userCredential.user == null) {
        return const AuthResult(
          success: false,
          message: 'Failed to create user account',
          errorCode: 'user-creation-failed',
        );
      }

      final user = userCredential.user!;

      // Generate referral code immediately to ensure consistency
      String userReferralCode;
      try {
        userReferralCode = await ReferralCodeGenerator.generateUniqueCode();
      } catch (e) {
        debugPrint('Failed to generate referral code: $e');
        // Use fallback code generation
        userReferralCode = 'TAL${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      }

      // Create user profile with referral code
      try {
        final userProfileData = {
          'fullName': fullName,
          'email': email,
          'phone': normalizedPhone,
          'address': address.toMap(),
          'profileCompleted': true,
          'phoneVerified': true,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'language': 'en',
          'locale': 'en_US',
          'referralCode': userReferralCode, // Generated immediately
          'membershipPaid': false, // Payment is optional - app is free for all users
          'status': 'active',
          'role': 'member',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'pinHash': hashedPin,
          'device': {
            'platform': kIsWeb ? 'web' : Platform.operatingSystem,
            'appVersion': '1.0.0',
          },
        };

        await _firestore.collection('users').doc(user.uid).set(userProfileData);
      } catch (e) {
        debugPrint('Failed to create user profile: $e');
        // Rollback Firebase Auth user
        try {
          await user.delete();
        } catch (deleteError) {
          debugPrint('Failed to rollback user creation: $deleteError');
        }
        return AuthResult(
          success: false,
          message: 'Failed to create user profile: ${e.toString()}',
          errorCode: 'profile-creation-failed',
        );
      }

      // Create user registry entry with same referral code
      try {
        await _firestore.collection('user_registry').doc(normalizedPhone).set({
          'uid': user.uid,
          'email': email,
          'phoneNumber': normalizedPhone,
          'role': 'member',
          'state': address.state,
          'district': address.district,
          'mandal': address.mandal,
          'village': address.villageCity,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'referralCode': userReferralCode, // Same code as users collection
          'directReferrals': 0,
          'teamSize': 0,
          'membershipPaid': false, // Payment is optional - app is free for all users
          'pinHash': hashedPin, // Store PIN hash for login verification
        });
      } catch (e) {
        debugPrint('Failed to create user registry: $e');
        // Don't rollback as profile is already created
        // This is non-critical for user functionality
      }

      // Get the created user profile
      final userProfile = await _getUserProfile(user.uid);
      if (userProfile == null) {
        return const AuthResult(
          success: false,
          message: 'Failed to retrieve created user profile',
          errorCode: 'profile-retrieval-failed',
        );
      }

      return AuthResult(
        success: true,
        message: 'Registration successful',
        user: userProfile,
      );
    } catch (e) {
      debugPrint('Registration error: $e');
      return AuthResult(
        success: false,
        message: 'Registration failed: ${e.toString()}',
        errorCode: 'registration-error',
      );
    }
  }

  /// Login user with phone number and PIN
  static Future<AuthResult> loginUser({
    required String phoneNumber,
    required String pin,
  }) async {
    final startTime = DateTime.now();
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);

    try {
      // Check rate limiting
      if (!_canAttemptLogin(normalizedPhone)) {
        return const AuthResult(
          success: false,
          message: 'Too many login attempts. Please try again later.',
          errorCode: 'rate-limit-exceeded',
        );
      }

      // Record login attempt
      _recordLoginAttempt(normalizedPhone);

      // Check if phone is registered
      final isRegistered = await isPhoneRegistered(normalizedPhone);
      if (!isRegistered) {
        return const AuthResult(
          success: false,
          message: 'Phone number not registered. Please register first.',
          errorCode: 'phone-not-found',
        );
      }

      // Get user registry to find UID
      final registryDoc = await _firestore
          .collection('user_registry')
          .doc(normalizedPhone)
          .get();

      if (!registryDoc.exists) {
        return const AuthResult(
          success: false,
          message: 'Phone number not registered. Please register first.',
          errorCode: 'phone-not-found',
        );
      }

      final registryData = registryDoc.data()!;
      final uid = registryData['uid'] as String;
      final storedPinHash = registryData['pinHash'] as String?;
      
      // Verify PIN hash from registry (no authentication needed)
      if (storedPinHash == null) {
        debugPrint('PIN hash not found in registry for: $normalizedPhone');
        return const AuthResult(
          success: false,
          message: 'Account setup incomplete. Please contact support.',
          errorCode: 'pin-hash-missing',
        );
      }

      final inputPinHash = _hashPin(pin);
      if (storedPinHash != inputPinHash) {
        return const AuthResult(
          success: false,
          message: 'Invalid PIN. Please check your PIN and try again.',
          errorCode: 'invalid-pin',
        );
      }

      // PIN is correct, now sign in with Firebase Auth
      final email = aliasEmailForPhone(normalizedPhone);
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: inputPinHash,
      );

      if (userCredential.user == null) {
        return const AuthResult(
          success: false,
          message: 'Authentication failed. Please try again.',
          errorCode: 'auth-failed',
        );
      }

      // Now that user is authenticated, get user profile
      final userProfile = await _getUserProfile(uid);
      if (userProfile == null) {
        return const AuthResult(
          success: false,
          message: 'User profile not found. Please contact support.',
          errorCode: 'profile-not-found',
        );
      }

      // Update last login timestamp
      try {
        await _firestore.collection('users').doc(uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('user_registry').doc(normalizedPhone).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Failed to update login timestamp: $e');
        // Non-critical error, continue with login
      }

      return AuthResult(
        success: true,
        message: 'Login successful',
        user: userProfile,
      );
    } catch (e) {
      debugPrint('Login error: $e');
      return AuthResult(
        success: false,
        message: 'Login failed: ${e.toString()}',
        errorCode: 'login-error',
      );
    }
  }

  /// Get user profile by UID
  static Future<UserModel?> _getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  /// Delete user account (for testing/cleanup)
  static Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      await _firestore.collection('user_registry').doc(uid).delete();
      debugPrint('User data deleted successfully');
    } catch (e) {
      debugPrint('Error deleting user data: $e');
    }
  }
}

/// Authentication result model
class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;
  final String? errorCode;

  const AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.errorCode,
  });
}
