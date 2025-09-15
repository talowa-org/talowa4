// Referral Chain Service for Talowa
// Implements BSS webapp referral chain logic in Flutter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import 'cloud_functions_service.dart';
import 'role_progression_service.dart';

class ReferralChainService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Process referral chain when a new user registers
  /// Now uses Cloud Functions for automatic processing
  static Future<void> processNewUserReferral({
    required String newUserId,
    required String? referralCode,
  }) async {
    try {
      debugPrint('ðŸ” Processing referral for new user: $newUserId');
      debugPrint('   Referral code: ${referralCode ?? "null"}');

      // Use Cloud Functions for referral processing and auto-promotion
      await CloudFunctionsService.processReferralAndPromote(newUserId);

    } catch (e) {
      debugPrint('âŒ Error processing referral chain: $e');
      // Don't throw - registration should succeed even if referral processing fails
    }
  }

  /// Update referral chain statistics
  /// Adapted from BSS referral chain traversal logic
  static Future<void> _updateReferralChain({
    required String newUserId,
    required String referralCode,
  }) async {
    debugPrint('ðŸ”— Updating referral chain for code: $referralCode');

    String? currentReferrerCode = referralCode;
    bool isDirectReferral = true;
    final WriteBatch batch = _firestore.batch();

    try {
      // Traverse up the referral chain
      while (currentReferrerCode != null && currentReferrerCode.isNotEmpty) {
        debugPrint('   Processing referrer code: $currentReferrerCode');

        // Find the referrer by referral code
        final referrerQuery = await _firestore
            .collection('users')
            .where('referralCode', isEqualTo: currentReferrerCode)
            .limit(1)
            .get();

        if (referrerQuery.docs.isEmpty) {
          debugPrint('âš ï¸ Referrer with code $currentReferrerCode not found. Stopping chain.');
          break;
        }

        final referrerDoc = referrerQuery.docs.first;
        final referrerData = referrerDoc.data();
        final referrerDocRef = referrerDoc.reference;

        debugPrint('   Found referrer: ${referrerData['fullName']} (${referrerDoc.id})');

        if (isDirectReferral) {
          // First person in chain gets both direct and team referral credit
          batch.update(referrerDocRef, {
            'directReferrals': FieldValue.increment(1),
            'teamReferrals': FieldValue.increment(1),
            'lastStatsUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint('   âœ… Credited direct referral to ${referrerData['fullName']}');
          isDirectReferral = false;
        } else {
          // Upline members only get team referral credit
          batch.update(referrerDocRef, {
            'teamReferrals': FieldValue.increment(1),
            'lastStatsUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint('   âœ… Credited team referral to ${referrerData['fullName']}');
        }

        // Stop if we reach admin (admin has no upline)
        if (currentReferrerCode == 'TALADMIN') {
          debugPrint('   ðŸ›‘ Reached admin. Stopping chain traversal.');
          break;
        }

        // Move to next person up the chain
        currentReferrerCode = referrerData['referredBy'] as String?;
      }

      // Commit all updates in a single batch
      await batch.commit();
      debugPrint('âœ… Successfully updated referral chain');

    } catch (e) {
      debugPrint('âŒ Error updating referral chain: $e');
      rethrow;
    }
  }

  /// Check and process role promotion for a user using new automated system
  /// This will be called by Cloud Functions when stats are updated
  static Future<void> checkRolePromotion(String userId) async {
    try {
      debugPrint('🔄 Checking role promotion for user: $userId');
      
      // Use the new automated real-time role progression service
      final promotionResult = await RoleProgressionService.checkAndUpdateRoleRealTime(userId);
      
      if (promotionResult['promoted'] == true) {
        final previousRole = promotionResult['previousRole'] as String;
        final currentRole = promotionResult['currentRole'] as String;
        final directReferrals = promotionResult['directReferrals'] as int;
        final teamSize = promotionResult['teamSize'] as int;
        
        debugPrint('🎉 User promoted from $previousRole to $currentRole');
        debugPrint('   Direct referrals: $directReferrals, Team size: $teamSize');
        
        // Additional notification can be sent here if needed
        // The RoleProgressionService already handles notifications
      } else {
        final currentRole = promotionResult['currentRole'] as String;
        final eligibleRole = promotionResult['eligibleRole'] as String;
        
        if (currentRole != eligibleRole) {
          debugPrint('ℹ️ User $userId eligible for $eligibleRole but validation failed');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Error checking role promotion: $e');
    }
  }



  /// Fix orphaned users (assign them to admin)
  /// Adapted from BSS fix-orphans functionality
  static Future<int> fixOrphanedUsers() async {
    try {
      debugPrint('ðŸ”§ Starting orphan user fix...');

      // Find users with no referrer
      final orphanQuery = await _firestore
          .collection('users')
          .where('referredBy', isNull: true)
          .get();

      if (orphanQuery.docs.isEmpty) {
        debugPrint('âœ… No orphaned users found');
        return 0;
      }

      final WriteBatch batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in orphanQuery.docs) {
        final userData = doc.data();
        
        // Skip admin users
        if (userData['role'] == 'Admin' || userData['referralCode'] == 'TALADMIN') {
          continue;
        }

        // Assign to admin
        batch.update(doc.reference, {
          'referredBy': 'TALADMIN',
          'lastStatsUpdate': FieldValue.serverTimestamp(),
        });
        
        updateCount++;
        debugPrint('   Assigning ${userData['fullName']} to admin');
      }

      if (updateCount > 0) {
        await batch.commit();
        debugPrint('âœ… Fixed $updateCount orphaned users');
      }

      return updateCount;

    } catch (e) {
      debugPrint('âŒ Error fixing orphaned users: $e');
      return 0;
    }
  }

  /// Get referral statistics for a user
  static Future<Map<String, dynamic>> getReferralStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'directReferrals': 0,
          'teamReferrals': 0,
          'currentRoleLevel': 1,
          'role': AppConstants.roleMember,
        };
      }

      final userData = userDoc.data()!;
      return {
        'directReferrals': userData['directReferrals'] ?? 0,
        'teamReferrals': userData['teamReferrals'] ?? 0,
        'currentRoleLevel': userData['currentRoleLevel'] ?? 1,
        'role': userData['role'] ?? AppConstants.roleMember,
        'referralCode': userData['referralCode'] ?? '',
        'referredBy': userData['referredBy'],
      };

    } catch (e) {
      debugPrint('❌ Error getting referral stats: $e');
      return {
        'directReferrals': 0,
        'teamReferrals': 0,
        'currentRoleLevel': 1,
        'role': AppConstants.roleMember,
      };
    }
  }

  /// Validate referral code exists and is active
  static Future<bool> validateReferralCode(String referralCode) async {
    try {
      if (referralCode.trim().isEmpty) return false;

      final query = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: referralCode.trim().toUpperCase())
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error validating referral code: $e');
      return false;
    }
  }
}
