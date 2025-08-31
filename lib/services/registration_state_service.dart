import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_policy.dart';

/// Service to manage registration state and prevent duplicate registrations
class RegistrationStateService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check the registration status of a phone number
  /// Returns: 'not_started', 'otp_verified', 'completed', 'already_registered'
  static Future<RegistrationStatus> checkRegistrationStatus(String phoneNumber) async {
    try {
      final normalizedPhone = normalizeE164(phoneNumber);
      
      // First check if user is already fully registered
      final registryDoc = await _firestore
          .collection('user_registry')
          .doc(normalizedPhone)
          .get();
      
      if (registryDoc.exists) {
        final data = registryDoc.data()!;
        final isActive = data['isActive'] as bool? ?? false;
        if (isActive) {
          return RegistrationStatus(
            status: 'already_registered',
            message: 'This mobile number is already registered. Please login instead.',
            canProceedToForm: false,
            uid: data['uid'] as String?,
          );
        }
      }

      // Check if phone is verified but registration not completed
      final verificationDoc = await _firestore
          .collection('phone_verifications')
          .doc(normalizedPhone)
          .get();
      
      if (verificationDoc.exists) {
        final data = verificationDoc.data()!;
        final isVerified = data['verified'] as bool? ?? false;
        final verifiedAt = data['verifiedAt'] as Timestamp?;
        final tempUid = data['tempUid'] as String?;
        
        if (isVerified && verifiedAt != null) {
          // Check if verification is still valid (24 hours)
          final verificationTime = verifiedAt.toDate();
          final now = DateTime.now();
          final hoursSinceVerification = now.difference(verificationTime).inHours;
          
          if (hoursSinceVerification < 24) {
            // 🔧 CRITICAL FIX: Validate that the Firebase Auth user still exists
            if (tempUid != null) {
              final isValidUser = await _validateFirebaseAuthUser(tempUid);
              if (isValidUser) {
                // User is currently authenticated and matches
                return RegistrationStatus(
                  status: 'otp_verified',
                  message: 'Phone number already verified. Proceeding to registration form.',
                  canProceedToForm: true,
                  uid: tempUid,
                );
              } else {
                // User is not authenticated or was deleted from Firebase Auth
                debugPrint('🧹 Firebase Auth user deleted/invalid, cleaning up phone verification for: $normalizedPhone');
                await _firestore
                    .collection('phone_verifications')
                    .doc(normalizedPhone)
                    .delete();
                debugPrint('✅ Cleaned up orphaned phone verification');
              }
            } else {
              // No tempUid stored, clean up invalid verification
              debugPrint('🧹 No tempUid in verification record, cleaning up');
              await _firestore
                  .collection('phone_verifications')
                  .doc(normalizedPhone)
                  .delete();
            }
          } else {
            // Verification expired, need to verify again
            debugPrint('⏰ Phone verification expired, cleaning up');
            await _firestore
                .collection('phone_verifications')
                .doc(normalizedPhone)
                .delete();
          }
        }
      }

      return const RegistrationStatus(
        status: 'not_started',
        message: 'Ready to start registration process.',
        canProceedToForm: false,
      );
    } catch (e) {
      debugPrint('Error checking registration status: $e');
      return const RegistrationStatus(
        status: 'error',
        message: 'Unable to check registration status. Please try again.',
        canProceedToForm: false,
      );
    }
  }

  /// Mark phone number as verified after OTP verification
  static Future<bool> markPhoneAsVerified(String phoneNumber, String tempUid) async {
    try {
      final normalizedPhone = normalizeE164(phoneNumber);
      
      await _firestore
          .collection('phone_verifications')
          .doc(normalizedPhone)
          .set({
        'phoneNumber': normalizedPhone,
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'tempUid': tempUid,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });
      
      return true;
    } catch (e) {
      debugPrint('Error marking phone as verified: $e');
      return false;
    }
  }

  /// Clear phone verification after successful registration
  static Future<void> clearPhoneVerification(String phoneNumber) async {
    try {
      final normalizedPhone = normalizeE164(phoneNumber);
      await _firestore
          .collection('phone_verifications')
          .doc(normalizedPhone)
          .delete();
    } catch (e) {
      debugPrint('Error clearing phone verification: $e');
    }
  }

  /// Check if current Firebase Auth user matches the phone number
  static Future<bool> isCurrentUserVerifiedForPhone(String phoneNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final normalizedPhone = normalizeE164(phoneNumber);
      final verificationDoc = await _firestore
          .collection('phone_verifications')
          .doc(normalizedPhone)
          .get();
      
      if (verificationDoc.exists) {
        final data = verificationDoc.data()!;
        final tempUid = data['tempUid'] as String?;
        return tempUid == user.uid;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking current user verification: $e');
      return false;
    }
  }

  /// Validate if a Firebase Auth user exists and is accessible
  static Future<bool> _validateFirebaseAuthUser(String uid) async {
    try {
      final currentUser = _auth.currentUser;
      
      // Check if current user matches the expected UID
      if (currentUser != null && currentUser.uid == uid) {
        return true;
      }
      
      // If no current user or UID mismatch, the user was likely deleted
      return false;
    } catch (e) {
      debugPrint('Error validating Firebase Auth user: $e');
      return false;
    }
  }

  /// Clean up orphaned phone verifications (when Firebase Auth users are deleted)
  static Future<void> cleanupOrphanedVerifications() async {
    try {
      final verificationsQuery = await _firestore
          .collection('phone_verifications')
          .get();
      
      final batch = _firestore.batch();
      int cleanedCount = 0;
      
      for (final doc in verificationsQuery.docs) {
        final data = doc.data();
        final tempUid = data['tempUid'] as String?;
        
        if (tempUid != null) {
          final isValidUser = await _validateFirebaseAuthUser(tempUid);
          if (!isValidUser) {
            // Firebase Auth user doesn't exist, clean up verification
            batch.delete(doc.reference);
            cleanedCount++;
            debugPrint('🧹 Cleaning up orphaned verification for phone: ${doc.id}');
          }
        } else {
          // No tempUid, invalid verification
          batch.delete(doc.reference);
          cleanedCount++;
        }
      }
      
      if (cleanedCount > 0) {
        await batch.commit();
        debugPrint('✅ Cleaned up $cleanedCount orphaned phone verifications');
      }
    } catch (e) {
      debugPrint('Error cleaning up orphaned verifications: $e');
    }
  }

  /// Clean up expired phone verifications (maintenance function)
  static Future<void> cleanupExpiredVerifications() async {
    try {
      final now = Timestamp.now();
      final expiredQuery = await _firestore
          .collection('phone_verifications')
          .where('expiresAt', isLessThan: now)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in expiredQuery.docs) {
        batch.delete(doc.reference);
      }
      
      if (expiredQuery.docs.isNotEmpty) {
        await batch.commit();
        debugPrint('Cleaned up ${expiredQuery.docs.length} expired phone verifications');
      }
    } catch (e) {
      debugPrint('Error cleaning up expired verifications: $e');
    }
  }
}

/// Registration status model
class RegistrationStatus {
  final String status; // 'not_started', 'otp_verified', 'completed', 'already_registered', 'error'
  final String message;
  final bool canProceedToForm;
  final String? uid;

  const RegistrationStatus({
    required this.status,
    required this.message,
    required this.canProceedToForm,
    this.uid,
  });

  bool get isAlreadyRegistered => status == 'already_registered';
  bool get isOtpVerified => status == 'otp_verified';
  bool get needsOtpVerification => status == 'not_started';
  bool get hasError => status == 'error';
}