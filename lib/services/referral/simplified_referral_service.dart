import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/referral/referral_models.dart';
import 'referral_code_generator.dart';
import 'referral_lookup_service.dart';
import 'referral_tracking_service.dart';
import 'referral_statistics_service.dart';
import 'role_progression_service.dart';

/// Exception thrown when simplified referral operations fail
class SimplifiedReferralException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const SimplifiedReferralException(this.message, [this.code = 'SIMPLIFIED_REFERRAL_FAILED', this.context]);
  
  @override
  String toString() => 'SimplifiedReferralException: $message';
}

/// Simplified one-step referral service for TALOWA
class SimplifiedReferralService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Complete referral setup for a new user (one-step process)
  static Future<Map<String, dynamic>> setupUserReferral({
    required String userId,
    required String fullName,
    required String email,
    String? referralCode,
  }) async {
    try {
      // Step 1: Generate unique referral code for new user
      final newUserReferralCode = await ReferralCodeGenerator.generateUniqueCode();
      await ReferralLookupService.assignReferralCodeToUser(newUserReferralCode, userId);
      
      // Step 2: Process referral if user was referred
      String? referrerUserId;
      List<String> referralChain = [];
      
      if (referralCode != null && referralCode.isNotEmpty) {
        final referrerData = await ReferralLookupService.validateReferralCode(referralCode);
        if (referrerData != null) {
          referrerUserId = referrerData['uid'] as String?;
          if (referrerUserId != null) {
            referralChain = await _buildReferralChain(referrerUserId);
            
            // Record referral relationship immediately
            await ReferralTrackingService.recordReferralRelationship(
              newUserId: userId,
              referralCode: referralCode,
            );
          }
        }
      }
      
      // Step 3: Update user document with referral info
      await _firestore.collection('users').doc(userId).update({
        'referralCode': newUserReferralCode,
        'referredBy': referralCode,
        'referralChain': referralChain,
        'referralStatus': 'active',
        'activeDirectReferrals': 0,
        'activeTeamSize': 0,
        'totalTeamSize': 0,
        'membershipPaid': false, // Payment is optional - app is free for all users
        'isActive': true,
        'currentRole': UserRole.member.toString(),
        'referralSetupCompletedAt': FieldValue.serverTimestamp(),
      });
      
      // Step 4: Update referrer statistics and check role progression
      if (referrerUserId != null) {
        await _updateReferrerStatistics(referrerUserId);
        await RoleProgressionService.checkAndUpdateRole(referrerUserId);
        
        // Update entire referral chain
        await _updateReferralChainStatistics(referralChain, userId);
      }
      
      return {
        'success': true,
        'referralCode': newUserReferralCode,
        'wasReferred': referrerUserId != null,
        'referrerUserId': referrerUserId,
        'referralChain': referralChain,
        'message': 'Referral system setup completed successfully',
      };
      
    } catch (e) {
      throw SimplifiedReferralException(
        'Failed to setup user referral: $e',
        'SETUP_FAILED',
        {'userId': userId, 'referralCode': referralCode}
      );
    }
  }
  
  /// Get complete referral status for a user
  static Future<Map<String, dynamic>> getUserReferralStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw SimplifiedReferralException(
          'User not found: $userId',
          'USER_NOT_FOUND',
          {'userId': userId}
        );
      }
      
      final userData = userDoc.data()!;
      
      // Get role progression status
      final roleStatus = await RoleProgressionService.getRoleProgressionStatus(userId);
      
      // Get referral statistics
      final stats = await ReferralStatisticsService.getStatisticsSummary(userId);
      
      return {
        'userId': userId,
        'referralCode': userData['referralCode'],
        'referredBy': userData['referredBy'],
        'referralStatus': userData['referralStatus'] ?? 'active',
        'currentRole': userData['currentRole'] ?? 'member',
        'activeDirectReferrals': userData['activeDirectReferrals'] ?? 0,
        'activeTeamSize': userData['activeTeamSize'] ?? 0,
        'totalTeamSize': userData['totalTeamSize'] ?? 0,
        'referralChain': userData['referralChain'] ?? [],
        'roleProgression': roleStatus,
        'statistics': stats,
        'isActive': userData['isActive'] ?? true,
        'membershipPaid': userData['membershipPaid'] ?? false, // Use actual payment status
      };
      
    } catch (e) {
      if (e is SimplifiedReferralException) {
        rethrow;
      }
      throw SimplifiedReferralException(
        'Failed to get user referral status: $e',
        'STATUS_RETRIEVAL_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Update referral statistics for a user and their chain
  static Future<void> updateUserReferralStatistics(String userId) async {
    try {
      // Update user's own statistics
      await ReferralStatisticsService.updateUserStatistics(userId);
      
      // Check and update role progression
      await RoleProgressionService.checkAndUpdateRole(userId);
      
      // Get user's referral chain and update their statistics too
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final referralChain = List<String>.from(userData['referralChain'] ?? []);
        
        for (final chainUserId in referralChain) {
          try {
            await ReferralStatisticsService.updateUserStatistics(chainUserId);
            await RoleProgressionService.checkAndUpdateRole(chainUserId);
          } catch (e) {
            print('Warning: Failed to update statistics for user $chainUserId: $e');
          }
        }
      }
      
    } catch (e) {
      throw SimplifiedReferralException(
        'Failed to update referral statistics: $e',
        'STATISTICS_UPDATE_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get referral leaderboard
  static Future<List<Map<String, dynamic>>> getReferralLeaderboard({
    int limit = 50,
    String orderBy = 'activeDirectReferrals',
  }) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .orderBy(orderBy, descending: true)
          .limit(limit)
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'fullName': data['fullName'] ?? 'Unknown',
          'currentRole': data['currentRole'] ?? 'member',
          'activeDirectReferrals': data['activeDirectReferrals'] ?? 0,
          'activeTeamSize': data['activeTeamSize'] ?? 0,
          'referralCode': data['referralCode'],
          'rolePromotedAt': data['rolePromotedAt'],
        };
      }).toList();
      
    } catch (e) {
      throw SimplifiedReferralException(
        'Failed to get referral leaderboard: $e',
        'LEADERBOARD_FAILED'
      );
    }
  }
  
  /// Validate and process a referral code
  static Future<Map<String, dynamic>> validateReferralCode(String referralCode) async {
    try {
      final validationResult = await ReferralLookupService.validateReferralCode(referralCode);
      
      if (validationResult == null) {
        return {
          'valid': false,
          'message': 'Invalid or inactive referral code',
        };
      }
      
      final referrerData = validationResult['userData'] as Map<String, dynamic>?;
      
      return {
        'valid': true,
        'referrerUserId': validationResult['uid'],
        'referrerName': referrerData?['fullName'] ?? 'Unknown',
        'referrerRole': referrerData?['currentRole'] ?? 'member',
        'message': 'Valid referral code',
      };
      
    } catch (e) {
      return {
        'valid': false,
        'message': 'Error validating referral code: $e',
      };
    }
  }
  
  /// Build referral chain for a user
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
  
  /// Update referrer statistics
  static Future<void> _updateReferrerStatistics(String referrerUserId) async {
    try {
      // Get all direct referrals
      final directReferralsQuery = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: referrerUserId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final activeDirectReferrals = directReferralsQuery.docs.length;
      
      // Get all team members (downline)
      final teamQuery = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: referrerUserId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final activeTeamSize = teamQuery.docs.length;
      
      // Update referrer document
      await _firestore.collection('users').doc(referrerUserId).update({
        'activeDirectReferrals': activeDirectReferrals,
        'activeTeamSize': activeTeamSize,
        'totalTeamSize': activeTeamSize,
        'lastStatsUpdate': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print('Warning: Failed to update referrer statistics: $e');
    }
  }
  
  /// Update statistics for entire referral chain
  static Future<void> _updateReferralChainStatistics(List<String> referralChain, String newUserId) async {
    for (final userId in referralChain) {
      try {
        await _updateReferrerStatistics(userId);
      } catch (e) {
        print('Warning: Failed to update statistics for user $userId: $e');
      }
    }
  }
  
  /// Get referral analytics
  static Future<Map<String, dynamic>> getReferralAnalytics() async {
    try {
      // Get total users
      final totalUsersQuery = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();
      
      final totalUsers = totalUsersQuery.docs.length;
      
      // Get users with referrals
      final usersWithReferralsQuery = await _firestore
          .collection('users')
          .where('activeDirectReferrals', isGreaterThan: 0)
          .get();
      
      final usersWithReferrals = usersWithReferralsQuery.docs.length;
      
      // Get role distribution
      final roleDistribution = <String, int>{};
      for (final doc in totalUsersQuery.docs) {
        final role = doc.data()['currentRole'] as String? ?? 'member';
        roleDistribution[role] = (roleDistribution[role] ?? 0) + 1;
      }
      
      return {
        'totalUsers': totalUsers,
        'usersWithReferrals': usersWithReferrals,
        'referralRate': totalUsers > 0 ? (usersWithReferrals / totalUsers * 100).round() : 0,
        'roleDistribution': roleDistribution,
        'calculatedAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      throw SimplifiedReferralException(
        'Failed to get referral analytics: $e',
        'ANALYTICS_FAILED'
      );
    }
  }
}