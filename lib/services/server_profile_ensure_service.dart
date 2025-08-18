// Server Profile Ensure Service for TALOWA
// Ensures user profiles have all required server-side fields after registration

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'referral/referral_code_generator.dart';

class ServerProfileEnsureService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Ensure user profile has all required server-side fields
  /// This should be called after client-side registration
  static Future<Map<String, dynamic>> ensureUserProfile(String uid) async {
    try {
      // First try to call server function if available
      try {
        final result = await _functions.httpsCallable('ensureUserProfile').call({
          'uid': uid,
        });
        
        if (result.data['success'] == true) {
          return result.data;
        }
      } catch (e) {
        debugPrint('Server function not available, using client fallback: $e');
      }
      
      // Fallback to client-side ensure
      return await _clientSideEnsure(uid);
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
      throw Exception('Failed to ensure user profile: $e');
    }
  }
  
  /// Client-side fallback for ensuring user profile
  static Future<Map<String, dynamic>> _clientSideEnsure(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }
      
      final userData = userDoc.data()!;
      final updates = <String, dynamic>{};
      
      // Ensure referral code exists
      String referralCode = userData['referralCode'] as String? ?? '';
      if (referralCode.isEmpty || !referralCode.startsWith('TAL')) {
        referralCode = await ReferralCodeGenerator.ensureReferralCode(uid);
        updates['referralCode'] = referralCode;
      }
      
      // Ensure provisionalRef exists
      if (userData['provisionalRef'] == null) {
        updates['provisionalRef'] = 'TALADMIN';
        updates['assignedBySystem'] = true;
      }
      
      // Ensure status exists
      if (userData['status'] == null) {
        updates['status'] = 'pending_payment';
      }
      
      // Ensure membership fields exist
      if (userData['membershipPaid'] == null) {
        updates['membershipPaid'] = false;
      }
      
      // Ensure counters exist
      if (userData['directReferralCount'] == null) {
        updates['directReferralCount'] = 0;
      }
      
      if (userData['totalTeamSize'] == null) {
        updates['totalTeamSize'] = 0;
      }
      
      // Ensure role exists
      if (userData['role'] == null) {
        updates['role'] = 'member';
      }
      
      // Apply updates if any
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('users').doc(uid).update(updates);
        debugPrint('Applied server-side updates: ${updates.keys.toList()}');
      }
      
      return {
        'success': true,
        'referralCode': referralCode,
        'updates': updates.keys.toList(),
        'message': 'User profile ensured successfully',
      };
    } catch (e) {
      debugPrint('Client-side ensure failed: $e');
      throw Exception('Failed to ensure user profile: $e');
    }
  }
  
  /// Ensure referral code is immediately available after registration
  static Future<String> ensureReferralCodeImmediate(String uid) async {
    try {
      // Check if user already has a valid referral code
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final existingCode = userData['referralCode'] as String?;
        
        if (existingCode != null && existingCode.startsWith('TAL')) {
          return existingCode;
        }
      }
      
      // Generate and assign new referral code
      final referralCode = await ReferralCodeGenerator.ensureReferralCode(uid);
      
      debugPrint('Generated referral code for user $uid: $referralCode');
      return referralCode;
    } catch (e) {
      debugPrint('Error ensuring immediate referral code: $e');
      // Return placeholder but continue background generation
      _scheduleBackgroundEnsure(uid);
      return 'TAL---';
    }
  }
  
  /// Schedule background ensure for failed immediate attempts
  static void _scheduleBackgroundEnsure(String uid) {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await ensureUserProfile(uid);
        debugPrint('Background ensure completed for user $uid');
      } catch (e) {
        debugPrint('Background ensure failed for user $uid: $e');
      }
    });
  }
  
  /// Validate that user has all required server-side fields
  static Future<bool> validateUserProfile(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        return false;
      }
      
      final userData = userDoc.data()!;
      
      // Check required server-side fields
      final requiredFields = [
        'referralCode',
        'provisionalRef',
        'status',
        'membershipPaid',
        'directReferralCount',
        'totalTeamSize',
        'role',
      ];
      
      for (final field in requiredFields) {
        if (!userData.containsKey(field)) {
          debugPrint('Missing required field: $field');
          return false;
        }
      }
      
      // Validate referral code format
      final referralCode = userData['referralCode'] as String?;
      if (referralCode == null || !referralCode.startsWith('TAL')) {
        debugPrint('Invalid referral code format: $referralCode');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error validating user profile: $e');
      return false;
    }
  }
}
