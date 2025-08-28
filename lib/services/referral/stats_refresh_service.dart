import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'cloud_functions_service.dart';

/// Service to handle automatic stats refresh and role promotions
class StatsRefreshService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Refresh stats for a user and check for promotions
  static Future<Map<String, dynamic>?> refreshUserStats(String userId) async {
    try {
      // Get current user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data()!;
      
      // Check for auto-promotion using Cloud Functions
      final promotionResult = await CloudFunctionsService.autoPromoteUser(userId);
      
      // Get updated user data after potential promotion
      final updatedUserDoc = await _firestore.collection('users').doc(userId).get();
      final updatedUserData = updatedUserDoc.data()!;

      final stats = {
        'directReferrals': updatedUserData['directReferrals'] ?? 0,
        'teamReferrals': updatedUserData['teamReferrals'] ?? 0,
        'teamSize': updatedUserData['teamSize'] ?? updatedUserData['teamReferrals'] ?? 0,
        'currentRole': updatedUserData['role'] ?? 'Member',
        'currentRoleLevel': updatedUserData['currentRoleLevel'] ?? 1,
        'referralCode': updatedUserData['referralCode'] ?? '',
        'membershipPaid': updatedUserData['membershipPaid'] ?? false,
        'lastStatsUpdate': updatedUserData['lastStatsUpdate'],
        'promotionResult': promotionResult,
      };

      return stats;

    } catch (e) {
      debugPrint('❌ Error refreshing user stats: $e');
      return null;
    }
  }

  /// Force refresh stats by recalculating from referral relationships
  static Future<Map<String, dynamic>?> forceRefreshStats(String userId) async {
    try {
      // Get user's referral code
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final referralCode = userData['referralCode'] as String?;
      
      if (referralCode == null || referralCode.isEmpty) {
        return null;
      }

      // Count direct referrals
      final directReferralsQuery = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: referralCode)
          .get();
      
      final directCount = directReferralsQuery.docs.length;

      // Count team size (all users in referral chain)
      final teamQuery = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .get();
      
      final teamCount = teamQuery.docs.length;

      // Update user document with recalculated stats
      await userDoc.reference.update({
        'directReferrals': directCount,
        'teamReferrals': teamCount,
        'teamSize': teamCount,
        'lastStatsUpdate': FieldValue.serverTimestamp(),
      });

      // Check for promotion after stats update
      final promotionResult = await CloudFunctionsService.autoPromoteUser(userId);

      // Get final updated data
      final finalUserDoc = await _firestore.collection('users').doc(userId).get();
      final finalUserData = finalUserDoc.data()!;

      final stats = {
        'directReferrals': finalUserData['directReferrals'] ?? 0,
        'teamReferrals': finalUserData['teamReferrals'] ?? 0,
        'teamSize': finalUserData['teamSize'] ?? finalUserData['teamReferrals'] ?? 0,
        'currentRole': finalUserData['role'] ?? 'Member',
        'currentRoleLevel': finalUserData['currentRoleLevel'] ?? 1,
        'referralCode': finalUserData['referralCode'] ?? '',
        'membershipPaid': finalUserData['membershipPaid'] ?? false,
        'lastStatsUpdate': finalUserData['lastStatsUpdate'],
        'promotionResult': promotionResult,
        'recalculated': true,
      };

      return stats;

    } catch (e) {
      debugPrint('❌ Error force refreshing stats: $e');
      return null;
    }
  }

  /// Check if stats need updating (based on last update time)
  static Future<bool> needsStatsUpdate(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final lastUpdate = userData['lastStatsUpdate'] as Timestamp?;
      
      if (lastUpdate == null) return true;

      // Check if last update was more than 5 minutes ago
      final now = DateTime.now();
      final lastUpdateTime = lastUpdate.toDate();
      final difference = now.difference(lastUpdateTime);

      return difference.inMinutes > 5;

    } catch (e) {
      debugPrint('❌ Error checking stats update need: $e');
      return true; // Default to needing update on error
    }
  }

  /// Batch refresh stats for multiple users
  static Future<void> batchRefreshStats(List<String> userIds) async {
    try {
      for (final userId in userIds) {
        try {
          await refreshUserStats(userId);
          // Small delay to avoid overwhelming the system
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          // Continue with other users
        }
      }

    } catch (e) {
      debugPrint('❌ Error in batch refresh: $e');
    }
  }
}