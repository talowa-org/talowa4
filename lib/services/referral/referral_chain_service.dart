// Referral Chain Service for Talowa
// Implements BSS webapp referral chain logic in Flutter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import 'cloud_functions_service.dart';

class ReferralChainService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Process referral chain when a new user registers
  /// Now uses Cloud Functions for automatic processing
  static Future<void> processNewUserReferral({
    required String newUserId,
    required String? referralCode,
  }) async {
    try {
      debugPrint('🔍 Processing referral for new user: $newUserId');
      debugPrint('   Referral code: ${referralCode ?? "null"}');

      // Use Cloud Functions for referral processing and auto-promotion
      await CloudFunctionsService.processReferralAndPromote(newUserId);

    } catch (e) {
      debugPrint('❌ Error processing referral chain: $e');
      // Don't throw - registration should succeed even if referral processing fails
    }
  }

  /// Update referral chain statistics
  /// Adapted from BSS referral chain traversal logic
  static Future<void> _updateReferralChain({
    required String newUserId,
    required String referralCode,
  }) async {
    debugPrint('🔗 Updating referral chain for code: $referralCode');

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
          debugPrint('⚠️ Referrer with code $currentReferrerCode not found. Stopping chain.');
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
          debugPrint('   ✅ Credited direct referral to ${referrerData['fullName']}');
          isDirectReferral = false;
        } else {
          // Upline members only get team referral credit
          batch.update(referrerDocRef, {
            'teamReferrals': FieldValue.increment(1),
            'lastStatsUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint('   ✅ Credited team referral to ${referrerData['fullName']}');
        }

        // Stop if we reach admin (admin has no upline)
        if (currentReferrerCode == 'TALADMIN') {
          debugPrint('   🛑 Reached admin. Stopping chain traversal.');
          break;
        }

        // Move to next person up the chain
        currentReferrerCode = referrerData['referredBy'] as String?;
      }

      // Commit all updates in a single batch
      await batch.commit();
      debugPrint('✅ Successfully updated referral chain');

    } catch (e) {
      debugPrint('❌ Error updating referral chain: $e');
      throw e;
    }
  }

  /// Check and process role promotion for a user
  /// This will be called by Cloud Functions when stats are updated
  static Future<void> checkRolePromotion(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final currentRoleLevel = userData['currentRoleLevel'] as int? ?? 1;
      final directReferrals = userData['directReferrals'] as int? ?? 0;
      final teamReferrals = userData['teamReferrals'] as int? ?? 0;

      // Skip admin users
      if (currentRoleLevel == 0) return;

      // Determine the highest eligible role using Talowa's complete hierarchy
      int newRoleLevel = currentRoleLevel;
      String newRoleName = userData['role'] as String? ?? AppConstants.roleMember;

      // Define Talowa role thresholds (in descending order for highest eligible role)
      final roleThresholds = [
        {'level': 9, 'name': 'State Coordinator', 'direct': 1000, 'team': 3000000},
        {'level': 8, 'name': 'Zonal Coordinator', 'direct': 500, 'team': 1000000},
        {'level': 7, 'name': 'District Coordinator', 'direct': 320, 'team': 500000},
        {'level': 6, 'name': 'Constituency Coordinator', 'direct': 160, 'team': 50000},
        {'level': 5, 'name': 'Mandal Coordinator', 'direct': 80, 'team': 6000},
        {'level': 4, 'name': 'Area Coordinator', 'direct': 40, 'team': 700},
        {'level': 3, 'name': 'Team Leader', 'direct': 20, 'team': 100},
        {'level': 2, 'name': 'Active Member', 'direct': 10, 'team': 10},
        {'level': 1, 'name': 'Member', 'direct': 0, 'team': 0},
      ];

      // Find the highest eligible role
      for (final role in roleThresholds) {
        final directRequired = role['direct'] as int;
        final teamRequired = role['team'] as int;
        final roleLevel = role['level'] as int;
        
        final meetsDirect = directReferrals >= directRequired;
        final meetsTeam = teamReferrals >= teamRequired;

        if (meetsDirect && meetsTeam && roleLevel > currentRoleLevel) {
          newRoleLevel = roleLevel;
          newRoleName = role['name'] as String;
          break; // Found the highest eligible role
        }
      }

      // Update role if promotion is warranted
      if (newRoleLevel > currentRoleLevel) {
        await userDoc.reference.update({
          'role': newRoleName,
          'currentRoleLevel': newRoleLevel,
          'lastRoleUpdate': FieldValue.serverTimestamp(),
        });

        debugPrint('🎉 Promoted user ${userData['fullName']} to $newRoleName (level $newRoleLevel)');
        
        // TODO: Send promotion notification
        await _sendPromotionNotification(userId, newRoleName);
      }

    } catch (e) {
      debugPrint('❌ Error checking role promotion: $e');
    }
  }

  /// Send promotion notification (placeholder)
  static Future<void> _sendPromotionNotification(String userId, String newRole) async {
    try {
      // Add notification to user's notifications collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': 'promotion',
        'title': 'Congratulations! 🎉',
        'message': 'You have been promoted to $newRole!',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('📧 Promotion notification sent for $newRole');
    } catch (e) {
      debugPrint('⚠️ Failed to send promotion notification: $e');
    }
  }

  /// Fix orphaned users (assign them to admin)
  /// Adapted from BSS fix-orphans functionality
  static Future<int> fixOrphanedUsers() async {
    try {
      debugPrint('🔧 Starting orphan user fix...');

      // Find users with no referrer
      final orphanQuery = await _firestore
          .collection('users')
          .where('referredBy', isNull: true)
          .get();

      if (orphanQuery.docs.isEmpty) {
        debugPrint('✅ No orphaned users found');
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
        debugPrint('✅ Fixed $updateCount orphaned users');
      }

      return updateCount;

    } catch (e) {
      debugPrint('❌ Error fixing orphaned users: $e');
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