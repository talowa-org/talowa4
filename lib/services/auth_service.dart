

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'referral_code_cache_service.dart';
import 'server_profile_ensure_service.dart';

// Helper to sanitize user profile writes
Map<String, dynamic> ProfileWritePolicy(Map<String, dynamic> input) {
  final allowed = [
    'fullName','email','emailAlias','phone','language','locale','bio','address',
    'profileCompleted','phoneVerified','lastLoginAt','device'
  ];
  return Map.fromEntries(input.entries.where((e) => allowed.contains(e.key)));
}


class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Rate limiting storage
  static final Map<String, List<DateTime>> _loginAttempts = {};
  static const int maxAttemptsPerHour = 5;

  // Current user stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  /// Register new user with phone number and PIN
  static Future<AuthResult> registerUser({
    required String phoneNumber,
    required String pin,
    required String fullName,
    required Address address,
    String? referralCode,
  }) async {
    final startTime = DateTime.now();
    
    try {
      // Normalize phone number
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      // Check if phone is already registered
      final isRegistered = await DatabaseService.isPhoneRegistered(normalizedPhone);
      if (isRegistered) {
        return AuthResult(
          success: false,
          message: 'Phone number already registered',
          errorCode: 'phone-already-exists',
        );
      }

      // Create fake email for Firebase Auth
      final email = '$normalizedPhone@talowa.app';
      
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _hashPin(pin),
      );

      if (userCredential.user == null) {
        return AuthResult(
          success: false,
          message: 'Failed to create user account',
          errorCode: 'user-creation-failed',
        );
      }

      final user = userCredential.user!;

      // Create client-safe user profile with only allowed fields
      await _createClientUserProfile(
        uid: user.uid,
        fullName: fullName,
        email: email,
        phone: normalizedPhone,
        address: address,
      );

      // Create user registry entry
      await DatabaseService.createUserRegistry(
        phoneNumber: normalizedPhone,
        uid: user.uid,
        email: email,
        role: AppConstants.roleMember,
        state: address.state,
        district: address.district,
        mandal: address.mandal,
        village: address.villageCity,
      );

      // Get the created user profile
      final userProfile = await DatabaseService.getUserProfile(user.uid);
      if (userProfile == null) {
        throw Exception('Failed to retrieve created user profile');
      }

      // Ensure server-side profile fields are populated BEFORE cache initialization
      String referralCode = 'TAL---';
      try {
        final ensureResult = await ServerProfileEnsureService.ensureUserProfile(user.uid);
        referralCode = ensureResult['referralCode'] ?? 'TAL---';
        debugPrint('Server-side profile ensure completed, referralCode: $referralCode');
      } catch (e) {
        debugPrint('Server-side profile ensure failed (non-blocking): $e');
      }

      // Initialize referral code cache with the generated code
      await ReferralCodeCacheService.initializeWithCode(user.uid, referralCode);

      // Log performance
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('User registration completed in ${duration}ms');

      debugPrint('Registration successful for $normalizedPhone');

      return AuthResult(
        success: true,
        message: 'Registration successful',
        user: userProfile,
      );

    } catch (e) {
      debugPrint('Registration error: $e');
      
      // Log error
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('User registration failed in ${duration}ms: $e');

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
    
    try {
      // Normalize phone number
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      // Check rate limiting
      if (!_canAttemptLogin(normalizedPhone)) {
        return AuthResult(
          success: false,
          message: 'Too many login attempts. Please try again later.',
          errorCode: 'rate-limit-exceeded',
        );
      }

      // Record login attempt
      _recordLoginAttempt(normalizedPhone);

      // Check if phone is registered
      final isRegistered = await DatabaseService.isPhoneRegistered(normalizedPhone);
      if (!isRegistered) {
        return AuthResult(
          success: false,
          message: 'Phone number not registered',
          errorCode: 'phone-not-found',
        );
      }

      // Create fake email for Firebase Auth
      final email = '$normalizedPhone@talowa.app';
      
      // Sign in with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: _hashPin(pin),
      );

      if (userCredential.user == null) {
        return AuthResult(
          success: false,
          message: 'Invalid credentials',
          errorCode: 'invalid-credentials',
        );
      }

      // Get user profile
      final userProfile = await DatabaseService.getUserProfile(userCredential.user!.uid);
      if (userProfile == null) {
        return AuthResult(
          success: false,
          message: 'User profile not found',
          errorCode: 'profile-not-found',
        );
      }

      // Update last login time with only allowed fields
      await _updateLoginTimestamp(userCredential.user!.uid);

      // Initialize referral code cache for immediate availability
      ReferralCodeCacheService.initialize(userCredential.user!.uid);

      // Clear rate limiting on successful login
      _clearLoginAttempts(normalizedPhone);

      // Log performance
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('User login completed in ${duration}ms');

      debugPrint('Login successful for $normalizedPhone');

      return AuthResult(
        success: true,
        message: 'Login successful',
        user: userProfile,
      );

    } catch (e) {
      debugPrint('Login error: $e');
      
      // Log error
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('User login failed in ${duration}ms: $e');

      return AuthResult(
        success: false,
        message: 'Login failed: ${e.toString()}',
        errorCode: 'login-error',
      );
    }
  }

  /// Logout current user
  static Future<void> logout() async {
    try {
      await _auth.signOut();
      debugPrint('User logged out successfully');
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  /// Change user PIN
  static Future<AuthResult> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'User not authenticated',
          errorCode: 'user-not-authenticated',
        );
      }

      // Verify current PIN by attempting to reauthenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _hashPin(currentPin),
      );

      await user.reauthenticateWithCredential(credential);

      // Update password with new PIN
      await user.updatePassword(_hashPin(newPin));

      return AuthResult(
        success: true,
        message: 'PIN changed successfully',
      );

    } catch (e) {
      debugPrint('Change PIN error: $e');
      return AuthResult(
        success: false,
        message: 'Failed to change PIN: ${e.toString()}',
        errorCode: 'pin-change-error',
      );
    }
  }

  /// Reset PIN (requires phone verification)
  static Future<AuthResult> resetPin({
    required String phoneNumber,
    required String newPin,
  }) async {
    try {
      // This would typically involve SMS verification
      // For now, we'll implement a basic reset
      
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      final email = '$normalizedPhone@talowa.app';
      
      // Send password reset email (this won't actually send an email)
      await _auth.sendPasswordResetEmail(email: email);
      
      return AuthResult(
        success: true,
        message: 'PIN reset instructions sent',
      );

    } catch (e) {
      debugPrint('Reset PIN error: $e');
      return AuthResult(
        success: false,
        message: 'Failed to reset PIN: ${e.toString()}',
        errorCode: 'pin-reset-error',
      );
    }
  }

  // Private helper methods
  static String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String normalized = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle different formats
    if (normalized.startsWith('91') && normalized.length == 12) {
      // Remove country code
      normalized = normalized.substring(2);
    } else if (normalized.startsWith('+91')) {
      normalized = normalized.substring(3);
    }
    
    // Ensure it's a 10-digit number
    if (normalized.length == 10 && normalized.startsWith(RegExp(r'[6-9]'))) {
      return '+91$normalized';
    }
    
    throw Exception('Invalid phone number format');
  }

  static String _hashPin(String pin) {
    // Simple PIN hashing - in production, use proper hashing
    return 'talowa_${pin}_secure';
  }



  static bool _canAttemptLogin(String phoneNumber) {
    final attempts = _loginAttempts[phoneNumber] ?? [];
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    
    // Remove attempts older than 1 hour
    attempts.removeWhere((attempt) => attempt.isBefore(oneHourAgo));
    
    return attempts.length < maxAttemptsPerHour;
  }

  static void _recordLoginAttempt(String phoneNumber) {
    _loginAttempts[phoneNumber] ??= [];
    _loginAttempts[phoneNumber]!.add(DateTime.now());
  }

  static void _clearLoginAttempts(String phoneNumber) {
    _loginAttempts.remove(phoneNumber);
  }

  /// Create client-safe user profile with only allowed fields
  static Future<void> _createClientUserProfile({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    required Address address,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final rawUserData = {
        'fullName': fullName,
        'email': email,
        'emailAlias': email,
        'phone': phone,
        'address': address.toMap(),
        'profileCompleted': true,
        'phoneVerified': true,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'language': 'en',
        'locale': 'en_US',
        'device': {
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          'appVersion': '1.0.0',
        },
      };
      final userData = ProfileWritePolicy(rawUserData);
      debugPrint('Creating user profile with payload: ${userData.keys.toList()}');
      await firestore.collection('users').doc(uid).set(userData);
      debugPrint('User profile created successfully');
    } catch (e) {
      debugPrint('Failed to create user profile: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Update login timestamp with only allowed fields (non-blocking)
  static Future<void> _updateLoginTimestamp(String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Only send allowed fields to avoid permission errors
      final updateData = {
        'lastLoginAt': FieldValue.serverTimestamp(),
        'device': {
          'platform': kIsWeb ? 'web' : 'mobile',
          'appVersion': '1.0.0', // TODO: Get from package info
        },
      };

      debugPrint('Updating login timestamp with payload: ${updateData.keys.toList()}');

      await firestore.collection('users').doc(uid).update(updateData);
      debugPrint('Login timestamp updated successfully');
    } catch (e) {
      // Non-blocking: log error but don't fail login
      debugPrint('Failed to update login timestamp (non-blocking): $e');
    }
  }
}

class AuthResult {
  final bool success;
  final String message;
  final String? errorCode;
  final UserModel? user;

  AuthResult({
    required this.success,
    required this.message,
    this.errorCode,
    this.user,
  });
}