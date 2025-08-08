import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Scalable Authentication Service for Millions of Users
/// Optimized for performance, caching, and efficient database operations
class ScalableAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Caching for performance optimization
  static final Map<String, UserData> _userCache = {};
  static final Map<String, bool> _registrationCache = {};
  static final Map<String, List<DateTime>> _rateLimitAttempts = {};

  /// Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Normalize phone number to standard format
  static String normalizePhone(String phone) {
    // Remove all non-digits
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle different formats
    if (digits.length == 10) {
      return '+91$digits'; // Indian number
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    } else if (digits.length == 13 && digits.startsWith('+91')) {
      return digits;
    }
    
    throw Exception('Invalid phone number format: $phone');
  }

  /// Convert phone number to fake email format
  static String phoneToEmail(String phoneNumber) {
    String normalizedPhone = normalizePhone(phoneNumber);
    return '$normalizedPhone@talowa.app';
  }

  /// Extract phone number from fake email
  static String emailToPhone(String email) {
    return email.split('@')[0];
  }

  /// Rate limiting for login attempts
  static bool canAttemptLogin(String phoneNumber) {
    String key = 'login_$phoneNumber';
    DateTime now = DateTime.now();
    
    _rateLimitAttempts[key] ??= [];
    
    // Remove attempts older than 1 hour
    _rateLimitAttempts[key]!.removeWhere((time) => 
      now.difference(time).inHours > 1
    );
    
    // Allow max 5 attempts per hour
    if (_rateLimitAttempts[key]!.length >= 5) {
      return false;
    }
    
    _rateLimitAttempts[key]!.add(now);
    return true;
  }

  /// Optimized mobile registration check with caching
  static Future<bool> isMobileRegistered(String mobileNumber) async {
    try {
      String normalizedPhone = normalizePhone(mobileNumber);
      String cacheKey = 'reg_$normalizedPhone';
      
      // Check cache first
      if (_registrationCache.containsKey(cacheKey)) {
        return _registrationCache[cacheKey]!;
      }
      
      // Query user registry collection (lightweight)
      final query = await _firestore
          .collection('user_registry')
          .where('phoneNumber', isEqualTo: normalizedPhone)
          .limit(1)
          .get();
      
      bool exists = query.docs.isNotEmpty;
      
      // Cache result for 1 hour
      _registrationCache[cacheKey] = exists;
      Timer(const Duration(hours: 1), () {
        _registrationCache.remove(cacheKey);
      });
      
      return exists;
    } catch (e) {
      debugPrint('Error checking mobile registration: $e');
      return false;
    }
  }

  /// Sign in with mobile number and PIN
  static Future<AuthResult> signInWithMobileAndPin({
    required String mobileNumber,
    required String pin,
  }) async {
    try {
      String normalizedPhone = normalizePhone(mobileNumber);
      
      // Rate limiting check
      if (!canAttemptLogin(normalizedPhone)) {
        return AuthResult(
          success: false,
          message: 'Too many login attempts. Please try again after 1 hour.',
        );
      }
      
      final fakeEmail = phoneToEmail(normalizedPhone);
      
      // Track login attempt
      AuthAnalytics.trackLoginAttempt('attempt', normalizedPhone);
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: pin,
      );

      if (credential.user != null) {
        // Load user data efficiently
        final userData = await _loadUserData(credential.user!.uid);
        
        // Track successful login
        AuthAnalytics.trackLoginAttempt('success', normalizedPhone);
        
        return AuthResult(
          success: true,
          user: credential.user,
          userData: userData,
          isNewUser: false,
          message: 'Login successful',
          phoneNumber: normalizedPhone,
        );
      }

      return AuthResult(
        success: false,
        message: 'Login failed',
      );
    } on FirebaseAuthException catch (e) {
      AuthAnalytics.trackLoginAttempt('failure', mobileNumber);
      return AuthResult(
        success: false,
        message: _getAuthErrorMessage(e),
      );
    } catch (e) {
      AuthAnalytics.trackLoginAttempt('error', mobileNumber);
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  /// Register new user with mobile number and PIN
  static Future<AuthResult> registerWithMobileAndPin({
    required String mobileNumber,
    required String pin,
  }) async {
    try {
      String normalizedPhone = normalizePhone(mobileNumber);
      final fakeEmail = phoneToEmail(normalizedPhone);
      
      // Check if already registered
      if (await isMobileRegistered(normalizedPhone)) {
        return AuthResult(
          success: false,
          message: 'This mobile number is already registered.',
        );
      }
      
      // Create Firebase user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: pin,
      );

      if (credential.user != null) {
        // Create user registry entry
        await _createUserRegistry(credential.user!, normalizedPhone);
        
        // Track registration
        AuthAnalytics.trackRegistration(normalizedPhone);
        
        return AuthResult(
          success: true,
          user: credential.user,
          isNewUser: true,
          message: 'Account created successfully',
          phoneNumber: normalizedPhone,
        );
      }

      return AuthResult(
        success: false,
        message: 'Account creation failed',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getAuthErrorMessage(e),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Registration failed: ${e.toString()}',
      );
    }
  }

  /// Create user registry entry for fast lookups
  static Future<void> _createUserRegistry(User user, String phoneNumber) async {
    try {
      await _firestore.collection('user_registry').doc(phoneNumber).set({
        'uid': user.uid,
        'email': user.email,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating user registry: $e');
    }
  }

  /// Load user data with caching
  static Future<UserData?> _loadUserData(String uid) async {
    try {
      // Check cache first
      if (_userCache.containsKey(uid)) {
        return _userCache[uid];
      }
      
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (doc.exists) {
        final userData = UserData.fromFirestore(doc);
        
        // Cache for 30 minutes
        _userCache[uid] = userData;
        Timer(const Duration(minutes: 30), () {
          _userCache.remove(uid);
        });
        
        return userData;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error loading user data: $e');
      return null;
    }
  }

  /// Update user's PIN
  static Future<AuthResult> updatePin(String newPin) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'User not authenticated',
        );
      }

      await user.updatePassword(newPin);
      
      return AuthResult(
        success: true,
        message: 'PIN updated successfully',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getAuthErrorMessage(e),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'PIN update failed',
      );
    }
  }

  /// Sign out and clear cache
  static Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      _userCache.remove(user.uid);
    }
    await _auth.signOut();
  }

  /// Clear all caches (for memory management)
  static void clearCaches() {
    _userCache.clear();
    _registrationCache.clear();
    _rateLimitAttempts.clear();
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
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}

/// Analytics for monitoring authentication performance
class AuthAnalytics {
  static void trackLoginAttempt(String result, String phoneNumber) {
    // In production, integrate with Firebase Analytics or other service
    debugPrint('Login $result for $phoneNumber at ${DateTime.now()}');
    
    // Track metrics:
    // - Success/failure rates
    // - Response times
    // - Geographic distribution
    // - Peak usage times
  }
  
  static void trackRegistration(String phoneNumber) {
    debugPrint('Registration for $phoneNumber at ${DateTime.now()}');
    
    // Track metrics:
    // - Registration rates by location
    // - Growth patterns
    // - Referral effectiveness
  }
}

/// Enhanced AuthResult with user data
class AuthResult {
  final bool success;
  final User? user;
  final UserData? userData;
  final bool isNewUser;
  final String message;
  final String? phoneNumber;

  AuthResult({
    required this.success,
    this.user,
    this.userData,
    this.isNewUser = false,
    required this.message,
    this.phoneNumber,
  });
}

/// User data model for caching
class UserData {
  final String uid;
  final String phoneNumber;
  final String? fullName;
  final String role;
  final Map<String, dynamic> profile;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  UserData({
    required this.uid,
    required this.phoneNumber,
    this.fullName,
    required this.role,
    required this.profile,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserData(
      uid: doc.id,
      phoneNumber: data['phone'] ?? '',
      fullName: data['fullName'],
      role: data['role'] ?? 'Member',
      profile: data,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}