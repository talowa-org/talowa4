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
        
        if (isVerified && verifiedAt != null) {
          // Check if verification is still valid (24 hours)
          final verificationTime = verifiedAt.toDate();
          final now = DateTime.now();
          final hoursSinceVerification = now.difference(verificationTime).inHours;
          
          if (hoursSinceVerification < 24) {
            return RegistrationStatus(
              status: 'otp_verified',
              message: 'Phone number already verified. Proceeding to registration form.',
              canProceedToForm: true,
              uid: data['tempUid'] as String?,
            );
          } else {
            // Verification expired, need to verify again
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