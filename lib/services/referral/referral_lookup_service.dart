import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/referral/referral_models.dart';

/// Exception thrown when referral code validation fails
class InvalidReferralCodeException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const InvalidReferralCodeException(this.message, [this.code = 'INVALID_REFERRAL_CODE', this.context]);
  
  @override
  String toString() => 'InvalidReferralCodeException: $message';
}

/// Service for fast referral code lookup and validation
class ReferralLookupService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Validates if a referral code exists and is active
  static Future<bool> isValidReferralCode(String code) async {
    try {
      final lookup = await getReferralCodeLookup(code);
      return lookup != null && lookup.isActive && lookup.uid != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Gets referral code lookup data
  static Future<ReferralCodeLookup?> getReferralCodeLookup(String code) async {
    try {
      final doc = await _firestore
          .collection('referralCodes')
          .doc(code)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      return ReferralCodeLookup.fromFirestore(doc);
    } catch (e) {
      throw InvalidReferralCodeException(
        'Failed to lookup referral code $code: $e',
        'LOOKUP_FAILED',
        {'code': code, 'error': e.toString()}
      );
    }
  }
  
  /// Gets user ID associated with a referral code
  static Future<String?> getUserIdByReferralCode(String code) async {
    try {
      final lookup = await getReferralCodeLookup(code);
      return lookup?.uid;
    } catch (e) {
      return null;
    }
  }
  
  /// Validates referral code and returns user data
  static Future<Map<String, dynamic>?> validateReferralCode(String code) async {
    try {
      // First check if code format is valid
      if (!isValidCodeFormat(code)) {
        throw InvalidReferralCodeException(
          'Invalid referral code format: $code',
          'INVALID_FORMAT',
          {'code': code}
        );
      }
      
      // Get referral code lookup
      final lookup = await getReferralCodeLookup(code);
      if (lookup == null) {
        throw InvalidReferralCodeException(
          'Referral code not found: $code',
          'CODE_NOT_FOUND',
          {'code': code}
        );
      }
      
      if (!lookup.isActive) {
        throw InvalidReferralCodeException(
          'Referral code is inactive: $code',
          'CODE_INACTIVE',
          {'code': code}
        );
      }
      
      if (lookup.uid == null) {
        throw InvalidReferralCodeException(
          'Referral code not assigned to user: $code',
          'CODE_UNASSIGNED',
          {'code': code}
        );
      }
      
      // Get user data
      final userDoc = await _firestore
          .collection('users')
          .doc(lookup.uid!)
          .get();
      
      if (!userDoc.exists) {
        throw InvalidReferralCodeException(
          'User not found for referral code: $code',
          'USER_NOT_FOUND',
          {'code': code, 'uid': lookup.uid}
        );
      }
      
      final userData = userDoc.data()!;
      
      // Check if user is active
      if (userData['isActive'] != true) {
        throw InvalidReferralCodeException(
          'User account is inactive for referral code: $code',
          'USER_INACTIVE',
          {'code': code, 'uid': lookup.uid}
        );
      }
      
      return {
        'uid': lookup.uid,
        'referralCode': code,
        'userData': userData,
        'lookup': lookup,
      };
      
    } catch (e) {
      if (e is InvalidReferralCodeException) {
        rethrow;
      }
      throw InvalidReferralCodeException(
        'Failed to validate referral code $code: $e',
        'VALIDATION_FAILED',
        {'code': code, 'error': e.toString()}
      );
    }
  }
  
  /// Assigns a referral code to a user
  static Future<void> assignReferralCodeToUser(String code, String userId) async {
    try {
      await _firestore.collection('referralCodes').doc(code).update({
        'uid': userId,
        'assignedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw InvalidReferralCodeException(
        'Failed to assign referral code $code to user $userId: $e',
        'ASSIGNMENT_FAILED',
        {'code': code, 'userId': userId, 'error': e.toString()}
      );
    }
  }
  
  /// Increments click count for a referral code
  static Future<void> incrementClickCount(String code, {Map<String, dynamic>? metadata}) async {
    try {
      final batch = _firestore.batch();
      
      // Update referral code click count
      final codeRef = _firestore.collection('referralCodes').doc(code);
      batch.update(codeRef, {
        'clickCount': FieldValue.increment(1),
        'lastClickAt': FieldValue.serverTimestamp(),
      });
      
      // Log click event for analytics
      if (metadata != null) {
        final clickRef = _firestore.collection('referralClicks').doc();
        batch.set(clickRef, {
          'referralCode': code,
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': metadata,
        });
      }
      
      await batch.commit();
    } catch (e) {
      // Don't throw error for click tracking failures
      // Log error but continue with user flow
      print('Failed to increment click count for $code: $e');
    }
  }
  
  /// Increments conversion count for a referral code
  static Future<void> incrementConversionCount(String code) async {
    try {
      await _firestore.collection('referralCodes').doc(code).update({
        'conversionCount': FieldValue.increment(1),
        'lastConversionAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't throw error for conversion tracking failures
      print('Failed to increment conversion count for $code: $e');
    }
  }
  
  /// Deactivates a referral code
  static Future<void> deactivateReferralCode(String code, String reason) async {
    try {
      await _firestore.collection('referralCodes').doc(code).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'deactivationReason': reason,
      });
    } catch (e) {
      throw InvalidReferralCodeException(
        'Failed to deactivate referral code $code: $e',
        'DEACTIVATION_FAILED',
        {'code': code, 'reason': reason, 'error': e.toString()}
      );
    }
  }
  
  /// Gets referral statistics for a code
  static Future<Map<String, dynamic>> getReferralStatistics(String code) async {
    try {
      final lookup = await getReferralCodeLookup(code);
      if (lookup == null) {
        return {
          'exists': false,
          'clicks': 0,
          'conversions': 0,
          'conversionRate': 0.0,
        };
      }
      
      final conversionRate = lookup.clickCount > 0 
          ? lookup.conversionCount / lookup.clickCount 
          : 0.0;
      
      return {
        'exists': true,
        'clicks': lookup.clickCount,
        'conversions': lookup.conversionCount,
        'conversionRate': conversionRate,
        'isActive': lookup.isActive,
        'createdAt': lookup.createdAt,
        'userId': lookup.uid,
      };
    } catch (e) {
      throw InvalidReferralCodeException(
        'Failed to get statistics for referral code $code: $e',
        'STATISTICS_FAILED',
        {'code': code, 'error': e.toString()}
      );
    }
  }
  
  /// Validates referral code format
  static bool isValidCodeFormat(String code) {
    const prefix = 'TAL';
    const codeLength = 6;
    const allowedChars = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
    
    if (code.length != prefix.length + codeLength) {
      return false;
    }
    
    if (!code.startsWith(prefix)) {
      return false;
    }
    
    final codePart = code.substring(prefix.length);
    for (int i = 0; i < codePart.length; i++) {
      if (!allowedChars.contains(codePart[i])) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Batch validates multiple referral codes
  static Future<Map<String, bool>> batchValidateReferralCodes(List<String> codes) async {
    final results = <String, bool>{};
    
    try {
      final futures = codes.map((code) async {
        final isValid = await isValidReferralCode(code);
        return MapEntry(code, isValid);
      });
      
      final entries = await Future.wait(futures);
      for (final entry in entries) {
        results[entry.key] = entry.value;
      }
    } catch (e) {
      // Return false for all codes if batch validation fails
      for (final code in codes) {
        results[code] = false;
      }
    }
    
    return results;
  }
}
