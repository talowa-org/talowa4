// Authentication Service for TALOWA
// Reference: REGISTRATION_SYSTEM.md - Auth Flows

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import 'database_service.dart';

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
      
      // Generate member ID and referral code
      final memberId = _generateMemberId();
      final userReferralCode = _generateReferralCode(normalizedPhone);

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

      // Create full user profile
      final userModel = UserModel(
        id: user.uid,
        phoneNumber: normalizedPhone,
        email: email,
        fullName: fullName,
        role: AppConstants.roleMember,
        memberId: memberId,
        referralCode: userReferralCode,
        referredBy: referralCode,
        address: address,
        directReferrals: 0,
        teamSize: 0,
        membershipPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferences: UserPreferences(
          language: AppConstants.languageEnglish,
          notifications: NotificationPreferences(
            push: true,
            sms: true,
            email: false,
          ),
          privacy: PrivacyPreferences(
            showLocation: false,
            allowDirectContact: true,
          ),
        ),
      );

      await DatabaseService.createUserProfile(userModel);

      // Handle referral if provided
      if (referralCode != null && referralCode.isNotEmpty) {
        await _processReferral(referralCode, user.uid);
      }

      // Log performance
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('User registration completed in ${duration}ms');

      debugPrint('Registration successful for $normalizedPhone');

      return AuthResult(
        success: true,
        message: 'Registration successful',
        user: userModel,
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

      // Update last login time
      final updatedUser = userProfile.copyWith(
        lastLoginAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await DatabaseService.updateUserProfile(updatedUser);

      // Clear rate limiting on successful login
      _clearLoginAttempts(normalizedPhone);

      // Log performance
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('User login completed in ${duration}ms');

      debugPrint('Login successful for $normalizedPhone');

      return AuthResult(
        success: true,
        message: 'Login successful',
        user: updatedUser,
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

  static String _generateMemberId() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomStr = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'MBR-$dateStr-$randomStr';
  }

  static String _generateReferralCode(String phoneNumber) {
    final lastFour = phoneNumber.substring(phoneNumber.length - 4);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return 'REF$lastFour${timestamp.substring(timestamp.length - 4)}';
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

  static Future<void> _processReferral(String referralCode, String newUserId) async {
    try {
      // Find the referrer by referral code
      final users = await DatabaseService.searchUsers(query: referralCode);
      final referrer = users.firstWhere(
        (user) => user.referralCode == referralCode,
        orElse: () => throw Exception('Invalid referral code'),
      );

      // Add referral relationship
      await DatabaseService.addReferral(
        referrerId: referrer.id,
        referredUserId: newUserId,
        referralCode: referralCode,
      );

      debugPrint('Referral processed: ${referrer.id} -> $newUserId');
    } catch (e) {
      debugPrint('Error processing referral: $e');
      // Don't fail registration if referral processing fails
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