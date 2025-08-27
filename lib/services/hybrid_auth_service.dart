import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'referral/referral_code_generator.dart';

/// Hybrid Authentication Service
/// Uses Firebase Email/Password authentication with mobile number as email
/// Format: +919876543210@talowa.app with 6-digit PIN as password
class HybridAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Convert phone number to fake email format
  static String phoneToEmail(String phoneNumber) {
    // Clean phone number and ensure it starts with +91
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanPhone.startsWith('+91')) {
      cleanPhone = '+91$cleanPhone';
    }
    return '$cleanPhone@talowa.app';
  }

  /// Extract phone number from fake email
  static String emailToPhone(String email) {
    return email.split('@')[0];
  }

  /// Sign in with mobile number and PIN
  static Future<AuthResult> signInWithMobileAndPin({
    required String mobileNumber,
    required String pin,
  }) async {
    try {
      // First, find user by phone number in user_registry
      final phoneQuery = await _firestore
          .collection('user_registry')
          .doc(mobileNumber)
          .get();

      if (!phoneQuery.exists) {
        return AuthResult(
          success: false,
          message: 'Phone number not registered. Please register first.',
        );
      }

      final uid = phoneQuery.data()!['uid'] as String;

      // Get user profile to check PIN hash
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        return AuthResult(
          success: false,
          message: 'User profile not found. Please contact support.',
        );
      }

      final userData = userDoc.data()!;
      final storedPinHash = userData['pinHash'] as String?;
      final inputPinHash = _hashPin(pin);

      if (storedPinHash != inputPinHash) {
        return AuthResult(
          success: false,
          message: 'Invalid PIN. Please check your PIN and try again.',
        );
      }

      // PIN is correct, now sign in the user (they should already be signed in from registration)
      final currentUser = _auth.currentUser;
      if (currentUser?.uid == uid) {
        // User is already signed in
        return AuthResult(
          success: true,
          user: currentUser,
          isNewUser: false,
          message: 'Login successful',
          phoneNumber: mobileNumber,
        );
      }

      // If user is not signed in, we need to sign them in
      // For phone auth users, we'll use a custom token approach
      return AuthResult(
        success: false,
        message: 'Please restart the app and try logging in again.',
      );
    } catch (e) {
      debugPrint('Login error: $e');
      return AuthResult(
        success: false,
        message: 'Login failed. Please try again.',
      );
    }
  }

  /// Register new user with complete form data (after OTP verification)
  /// This method now creates BOTH user profile AND user_registry
  static Future<AuthResult> registerWithCompleteData({
    required String mobileNumber,
    required String pin,
    required String fullName,
    required String state,
    required String district,
    required String mandal,
    required String village,
    String? referralCode,
  }) async {
    try {
      final fakeEmail = phoneToEmail(mobileNumber);

      // Check if already registered
      final isRegistered = await isMobileRegistered(mobileNumber);
      if (isRegistered) {
        return AuthResult(
          success: false,
          message:
              'This mobile number is already registered. Please login instead.',
          errorCode: 'phone-already-exists',
        );
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: _hashPin(pin),
      );

      if (credential.user != null) {
        final user = credential.user!;

        try {
          // Generate single referral code for both profile and registry
          String referralCode;
          try {
            referralCode = await ReferralCodeGenerator.generateUniqueCode();
            debugPrint(
              'Generated referralCode for user ${user.uid}: $referralCode',
            );
          } catch (e) {
            debugPrint('Failed to generate referralCode: $e');
            throw Exception('Failed to generate referralCode: $e');
          }

          // Create user profile with complete data
          await _createCompleteUserProfile(
            uid: user.uid,
            phoneNumber: mobileNumber,
            email: fakeEmail,
            fullName: fullName,
            state: state,
            district: district,
            mandal: mandal,
            village: village,
            referralCode: referralCode,
          );

          // Create user registry entry with same referral code
          await _createUserRegistry(
            uid: user.uid,
            phoneNumber: mobileNumber,
            email: fakeEmail,
            referralCode: referralCode,
          );

          return AuthResult(
            success: true,
            user: user,
            isNewUser: true,
            message: 'Account created successfully',
            phoneNumber: emailToPhone(fakeEmail),
          );
        } catch (e) {
          // Rollback Firebase Auth user if profile/registry creation fails
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
      }

      return AuthResult(success: false, message: 'Account creation failed');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  /// Register new user with mobile number and PIN with complete profile data
  static Future<AuthResult> registerWithMobileAndPin({
    required String mobileNumber,
    required String pin,
    String? fullName,
    String? email,
    String? bio,
    Map<String, dynamic>? address,
  }) async {
    try {
      final fakeEmail = email ?? phoneToEmail(mobileNumber);
      debugPrint('Creating Firebase user with email: $fakeEmail');

      // Create Firebase user with email/password
      final credential = await _auth.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: _hashPin(pin),
      );

      if (credential.user != null) {
        final user = credential.user!;

        try {
          // Generate single referral code for both profile and registry
          String referralCode;
          try {
            referralCode = await ReferralCodeGenerator.generateUniqueCode();
            debugPrint(
              'Generated referralCode for user ${user.uid}: $referralCode',
            );
          } catch (e) {
            debugPrint('Failed to generate referralCode: $e');
            throw Exception('Failed to generate referralCode: $e');
          }

          // Create user profile with collected data
          await _createUserProfileWithData(
            uid: user.uid,
            phoneNumber: mobileNumber,
            email: fakeEmail,
            referralCode: referralCode,
            fullName: fullName ?? '',
            bio: bio,
            address: address,
          );

          // Create user registry entry with same referral code
          await _createUserRegistry(
            uid: user.uid,
            phoneNumber: mobileNumber,
            email: fakeEmail,
            referralCode: referralCode,
          );

          return AuthResult(
            success: true,
            user: user,
            message: 'Registration successful',
          );
        } catch (e) {
          // Clean up Firebase user if profile creation fails
          await user.delete();
          rethrow;
        }
      } else {
        return AuthResult(
          success: false,
          message: 'Failed to create user account',
        );
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      return AuthResult(
        success: false,
        message: 'Registration failed: ${e.toString()}',
      );
    }
  }

  /// Mock phone verification for registration (no actual OTP sent)
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    // For web and to avoid reCAPTCHA issues, we'll simulate OTP sending
    // In a real implementation, you could integrate with SMS services like Twilio

    if (kIsWeb) {
      // On web, simulate OTP sending without Firebase phone auth
      await Future.delayed(const Duration(seconds: 1));
      codeSent('mock_verification_id', null);
    } else {
      // On mobile, you could still use Firebase phone auth or other SMS services
      // For now, we'll also simulate it to avoid any reCAPTCHA issues
      await Future.delayed(const Duration(seconds: 1));
      codeSent('mock_verification_id', null);
    }
  }

  /// Update user's PIN
  static Future<AuthResult> updatePin(String newPin) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(success: false, message: 'User not authenticated');
      }

      await user.updatePassword(_hashPin(newPin));

      return AuthResult(success: true, message: 'PIN updated successfully');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult(success: false, message: 'PIN update failed');
    }
  }

  /// Check if mobile number is already registered
  static Future<bool> isMobileRegistered(String mobileNumber) async {
    try {
      final fakeEmail = phoneToEmail(mobileNumber);

      // Try to sign in with a dummy password to check if user exists
      // This is a workaround since fetchSignInMethodsForEmail is deprecated
      try {
        await _auth.signInWithEmailAndPassword(
          email: fakeEmail,
          password: 'dummy_password_check',
        );
        // If we reach here, user exists but password was wrong
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          return false;
        } else if (e.code == 'wrong-password') {
          return true;
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error checking mobile registration: $e');
      return false;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Check if user profile exists in Firestore
  static Future<bool> _checkUserExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      return false;
    }
  }

  /// Create complete user profile in Firestore with all registration data
  static Future<void> _createCompleteUserProfile({
    required String uid,
    required String phoneNumber,
    required String email,
    required String fullName,
    required String state,
    required String district,
    required String mandal,
    required String village,
    required String referralCode,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Create complete user profile data
      final userData = {
        'fullName': fullName,
        'email': email,
        'phone': phoneNumber,
        'referralCode': referralCode,
        'membershipPaid': true, // Set to true by default for simplified flow
        'status': 'active',
        'role': 'member',
        'profileCompleted': true, // Profile is now complete
        'phoneVerified': true,
        // Location data
        'address': {
          'state': state,
          'district': district,
          'mandal': mandal,
          'village': village,
        },
        'state': state,
        'district': district,
        'mandal': mandal,
        'village': village,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'directReferrals': 0,
        'totalTeamSize': 0,
      };

      await firestore.collection('users').doc(uid).set(userData);
      debugPrint('Complete user profile created successfully for $uid');
    } catch (e) {
      debugPrint('Failed to create complete user profile: $e');
      throw Exception('Failed to create complete user profile: $e');
    }
  }

  /// Create user profile with flexible data (for integrated registration)
  static Future<void> _createUserProfileWithData({
    required String uid,
    required String phoneNumber,
    required String email,
    required String referralCode,
    String? fullName,
    String? bio,
    Map<String, dynamic>? address,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Create user profile data with all available information
      final userData = {
        'fullName': fullName ?? '',
        'email': email,
        'phone': phoneNumber,
        'referralCode': referralCode,
        'membershipPaid': true, // Set to true by default for simplified flow
        'status': 'active',
        'role': 'member',
        'profileCompleted':
            fullName?.isNotEmpty == true, // Complete if name provided
        'phoneVerified': true,
        'bio': bio ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'directReferrals': 0,
        'totalTeamSize': 0,
        'directReferralCount': 0,
        'paidAt': FieldValue.serverTimestamp(),
        'paymentRef': 'payment_${DateTime.now().millisecondsSinceEpoch}',
        'assignedBySystem': false,
        'provisionalRef': null,
        'referredBy': null,
        'referralChain': [],
      };

      // Add address data if provided
      if (address != null) {
        userData['address'] = address;
        // Also add individual location fields for compatibility
        if (address['state'] != null) userData['state'] = address['state'];
        if (address['district'] != null) {
          userData['district'] = address['district'];
        }
        if (address['mandal'] != null) userData['mandal'] = address['mandal'];
        if (address['village'] != null) {
          userData['village'] = address['village'];
        }
      }

      await firestore.collection('users').doc(uid).set(userData);
      debugPrint(
        'User profile created successfully for $uid with data: ${userData.keys.toList()}',
      );
    } catch (e) {
      debugPrint('Failed to create user profile: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Create user profile in Firestore with referral code (legacy method)
  static Future<void> _createUserProfile({
    required String uid,
    required String phoneNumber,
    required String email,
    required String referralCode,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Create user profile data
      final userData = {
        'fullName': '', // Will be filled in profile completion
        'email': email,
        'phone': phoneNumber,
        'referralCode': referralCode,
        'membershipPaid': true, // Set to true by default for simplified flow
        'status': 'active',
        'role': 'member',
        'profileCompleted':
            false, // Will be set to true after profile completion
        'phoneVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'directReferrals': 0,
        'totalTeamSize': 0,
      };

      await firestore.collection('users').doc(uid).set(userData);
      debugPrint('User profile created successfully for $uid');
    } catch (e) {
      debugPrint('Failed to create user profile: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Create user registry entry for quick phone number lookups
  static Future<void> _createUserRegistry({
    required String uid,
    required String phoneNumber,
    required String email,
    required String referralCode,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('user_registry').doc(phoneNumber).set({
        'uid': uid,
        'email': email,
        'phoneNumber': phoneNumber,
        'role': 'member',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'referralCode': referralCode,
        'directReferrals': 0,
        'teamSize': 0,
        'membershipPaid': true, // Set to true by default
      });

      debugPrint('User registry created successfully for $phoneNumber');
    } catch (e) {
      debugPrint('Failed to create user registry: $e');
      throw Exception('Failed to create user registry: $e');
    }
  }

  /// Get user-friendly error messages
  static String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this mobile number.';
      case 'wrong-password':
        return 'Incorrect PIN. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this mobile number.';
      case 'weak-password':
        return 'PIN must be exactly 6 digits.';
      case 'invalid-email':
        return 'Invalid mobile number format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This authentication method is not enabled.';
      case 'invalid-phone-number':
        return 'Please enter a valid phone number.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-verification-id':
        return 'Verification session expired. Please try again.';
      case 'phone-verification-failed':
        return 'Phone verification is not available on this platform.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  /// Hash PIN for consistent authentication
  static String _hashPin(String pin) {
    // Use same hashing as AuthService for consistency
    return 'talowa_${pin}_secure';
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final bool isNewUser;
  final String message;
  final String? phoneNumber;
  final String? errorCode;

  AuthResult({
    required this.success,
    this.user,
    this.isNewUser = false,
    required this.message,
    this.phoneNumber,
    this.errorCode,
  });
}
