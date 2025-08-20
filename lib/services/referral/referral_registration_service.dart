import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/referral/referral_models.dart';
import 'referral_code_generator.dart';
import 'referral_lookup_service.dart';
import 'referral_tracking_service.dart';
import 'referral_statistics_service.dart';
import 'role_progression_service.dart';

/// Exception thrown when registration fails
class RegistrationException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const RegistrationException(this.message, [this.code = 'REGISTRATION_FAILED', this.context]);
  
  @override
  String toString() => 'RegistrationException: $message';
}

/// Service for handling referral-aware user registration
class ReferralRegistrationService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Registers a new user with optional referral code
  static Future<UserRegistrationResult> registerUser({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    required Address address,
    String? referralCode,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Step 1: Validate referral code if provided
      String? referrerUserId;
      Map<String, dynamic>? referrerData;
      
      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          final validationResult = await ReferralLookupService.validateReferralCode(referralCode);
          if (validationResult != null) {
            referrerUserId = validationResult['uid'];
            referrerData = validationResult['userData'];
          }
        } catch (e) {
          throw RegistrationException(
            'Invalid referral code: $referralCode',
            'INVALID_REFERRAL_CODE',
            {'referralCode': referralCode, 'error': e.toString()}
          );
        }
      }
      
      // Step 2: Create Firebase Auth user
      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        throw RegistrationException(
          'Failed to create authentication account: $e',
          'AUTH_CREATION_FAILED',
          {'email': email, 'error': e.toString()}
        );
      }
      
      final userId = userCredential.user!.uid;
      
      // Step 3: Generate unique referral code for new user
      String newUserReferralCode;
      try {
        newUserReferralCode = await ReferralCodeGenerator.generateUniqueCode();
        await ReferralLookupService.assignReferralCodeToUser(newUserReferralCode, userId);
      } catch (e) {
        // Rollback auth user creation
        await userCredential.user!.delete();
        throw RegistrationException(
          'Failed to generate referral code: $e',
          'REFERRAL_CODE_GENERATION_FAILED',
          {'userId': userId, 'error': e.toString()}
        );
      }
      
      // Step 4: Build referral chain if user was referred
      List<String> referralChain = [];
      if (referrerUserId != null && referrerData != null) {
        referralChain = await _buildReferralChain(referrerUserId);
      }
      
      // Step 5: Create user document in Firestore
      final userData = {
        'id': userId,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'email': email,
        'role': 'member',
        'memberId': await _generateMemberId(),
        'referralCode': newUserReferralCode,
        'referredBy': referralCode,
        'referralChain': referralChain,
        'referralStatus': 'active', // Always active in simplified system
        'address': address.toMap(),
        'directReferrals': [],
        'activeDirectReferrals': 0,
        'totalTeamSize': 0,
        'activeTeamSize': 0,
        'membershipPaid': true, // Always true in simplified system
        'paymentTransactionId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'preferences': UserPreferences.defaultPreferences().toMap(),
        'isActive': true,
        'currentRole': UserRole.member.toString(),
        'previousRole': null,
        'rolePromotedAt': null,
        'achievements': [],
        'milestones': [],
        'referralRecordedAt': referralCode != null ? FieldValue.serverTimestamp() : null,
        ...?additionalData,
      };
      
      try {
        await _firestore.collection('users').doc(userId).set(userData);
      } catch (e) {
        // Rollback auth user and referral code
        await userCredential.user!.delete();
        await ReferralLookupService.deactivateReferralCode(newUserReferralCode, 'Registration failed');
        throw RegistrationException(
          'Failed to create user document: $e',
          'USER_DOCUMENT_CREATION_FAILED',
          {'userId': userId, 'error': e.toString()}
        );
      }
      
      // Step 6: Record referral relationship and update statistics immediately
      if (referralCode != null && referrerUserId != null) {
        try {
          await ReferralTrackingService.recordReferralRelationship(
            newUserId: userId,
            referralCode: referralCode,
          );
          
          // Immediately update referral statistics and check role progression
          await _updateReferralStatisticsAndRoles(referrerUserId, userId);
        } catch (e) {
          // Don't fail registration for referral tracking errors
          // Log error but continue
          print('Warning: Failed to record referral relationship: $e');
        }
      }
      
      // Step 7: Update Firebase Auth user profile
      try {
        await userCredential.user!.updateDisplayName(fullName);
      } catch (e) {
        // Non-critical error, continue
        print('Warning: Failed to update display name: $e');
      }
      
      return UserRegistrationResult(
        user: userCredential.user!,
        userModel: await _getUserModel(userId),
        referralCode: newUserReferralCode,
        wasReferred: referralCode != null,
        referrerUserId: referrerUserId,
      );
      
    } catch (e) {
      if (e is RegistrationException) {
        rethrow;
      }
      throw RegistrationException(
        'Unexpected registration error: $e',
        'UNEXPECTED_ERROR',
        {'error': e.toString()}
      );
    }
  }
  
  /// Builds referral chain for a user
  static Future<List<String>> _buildReferralChain(String referrerUserId) async {
    try {
      final referrerDoc = await _firestore.collection('users').doc(referrerUserId).get();
      if (!referrerDoc.exists) {
        return [referrerUserId];
      }
      
      final referrerData = referrerDoc.data()!;
      final existingChain = List<String>.from(referrerData['referralChain'] ?? []);
      
      // Add current referrer to the chain
      return [...existingChain, referrerUserId];
    } catch (e) {
      // Return minimal chain on error
      return [referrerUserId];
    }
  }
  
  /// Generates a unique member ID
  static Future<String> _generateMemberId() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp % 10000;
    return 'TAL${timestamp.toString().substring(8)}$random';
  }
  
  /// Gets user model from Firestore
  static Future<UserModel> _getUserModel(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return UserModel.fromFirestore(doc);
  }
  
  /// Update referral statistics and check role progression for referrer
  static Future<void> _updateReferralStatisticsAndRoles(String referrerUserId, String newUserId) async {
    try {
      // Update referrer's statistics
      await ReferralStatisticsService.updateUserStatistics(referrerUserId);
      
      // Check and update role progression
      await RoleProgressionService.checkAndUpdateRole(referrerUserId);
      
      // Update the entire referral chain statistics
      await _updateReferralChainStatistics(referrerUserId);
      
    } catch (e) {
      print('Warning: Failed to update referral statistics and roles: $e');
    }
  }
  
  /// Update statistics for the entire referral chain
  static Future<void> _updateReferralChainStatistics(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final referralChain = List<String>.from(userData['referralChain'] ?? []);
      
      // Update statistics for each user in the chain
      for (final chainUserId in referralChain) {
        try {
          // Update team size and other statistics
          await _updateUserTeamStatistics(chainUserId);
        } catch (e) {
          print('Warning: Failed to update statistics for user $chainUserId: $e');
        }
      }
    } catch (e) {
      print('Warning: Failed to update referral chain statistics: $e');
    }
  }
  
  /// Update team statistics for a specific user
  static Future<void> _updateUserTeamStatistics(String userId) async {
    try {
      // Get all users in this user's downline
      final downlineQuery = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final activeTeamSize = downlineQuery.docs.length;
      
      // Get direct referrals count
      final directReferralsQuery = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final activeDirectReferrals = directReferralsQuery.docs.length;
      
      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'activeTeamSize': activeTeamSize,
        'activeDirectReferrals': activeDirectReferrals,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print('Warning: Failed to update team statistics for user $userId: $e');
    }
  }
  
  /// Validates registration data
  static ValidationResult validateRegistrationData({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    String? referralCode,
  }) {
    final errors = <String>[];
    
    // Validate full name
    if (fullName.trim().isEmpty) {
      errors.add('Full name is required');
    } else if (fullName.trim().length < 2) {
      errors.add('Full name must be at least 2 characters');
    }
    
    // Validate phone number (Indian format)
    if (phoneNumber.trim().isEmpty) {
      errors.add('Phone number is required');
    } else {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      // Indian phone number: +91 followed by 10 digits starting with 6-9
      if (!RegExp(r'^(\+91)?[6-9]\d{9}$').hasMatch(cleanNumber)) {
        errors.add('Invalid phone number format');
      }
    }
    
    // Validate email
    if (email.trim().isEmpty) {
      errors.add('Email is required');
    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      errors.add('Invalid email format');
    }
    
    // Validate password
    if (password.isEmpty) {
      errors.add('Password is required');
    } else if (password.length < 6) {
      errors.add('Password must be at least 6 characters');
    }
    
    // Validate referral code format if provided
    if (referralCode != null && referralCode.isNotEmpty) {
      if (!ReferralLookupService.isValidCodeFormat(referralCode)) {
        errors.add('Invalid referral code format');
      }
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
  
  /// Checks if email is already registered
  static Future<bool> isEmailRegistered(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Checks if phone number is already registered
  static Future<bool> isPhoneRegistered(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Result of user registration
class UserRegistrationResult {
  final User user;
  final UserModel userModel;
  final String referralCode;
  final bool wasReferred;
  final String? referrerUserId;
  
  const UserRegistrationResult({
    required this.user,
    required this.userModel,
    required this.referralCode,
    required this.wasReferred,
    this.referrerUserId,
  });
}

/// Result of validation
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  
  const ValidationResult({
    required this.isValid,
    required this.errors,
  });
}
