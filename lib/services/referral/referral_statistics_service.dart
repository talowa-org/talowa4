import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'referral_chain_service.dart';

/// Exception thrown when referral statistics operations fail
class ReferralStatisticsException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const ReferralStatisticsException(this.message, [this.code = 'REFERRAL_STATISTICS_FAILED', this.context]);
  
  @override
  String toString() => 'ReferralStatisticsException: $message';
}

/// Service for managing referral statistics and analytics
class ReferralStatisticsService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Update all statistics for a user
  static Future<Map<String, dynamic>> updateUserStatistics(String userId) async {
    try {
      final stats = await ReferralChainService.getReferralStats(userId);
      
      // Calculate additional stats by querying Firestore directly
      final directReferralsQuery = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: stats['referralCode'])
          .get();
      
      final teamSizeQuery = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .get();
      
      final actualDirectReferrals = directReferralsQuery.docs.length;
      final actualTeamSize = teamSizeQuery.docs.length;
      
      // Update user document with latest statistics
      await _firestore.collection('users').doc(userId).update({
        'directReferrals': actualDirectReferrals,
        'teamSize': actualTeamSize,
        'teamReferrals': actualTeamSize, // Keep both for compatibility
        'lastStatsUpdate': FieldValue.serverTimestamp(),
      });
      
      final updatedStats = {
        'directReferrals': actualDirectReferrals,
        'teamSize': actualTeamSize,
        'teamReferrals': actualTeamSize,
        'currentRole': stats['role'],
        'calculatedAt': DateTime.now().toIso8601String(),
      };
      
      // Record statistics history
      await _recordStatisticsHistory(userId, updatedStats);
      
      return updatedStats;
    } catch (e) {
      throw ReferralStatisticsException(
        'Failed to update user statistics: $e',
        'STATS_UPDATE_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Record statistics in history collection for tracking changes
  static Future<void> _recordStatisticsHistory(String userId, Map<String, dynamic> stats) async {
    try {
      await _firestore.collection('referralStatisticsHistory').add({
        'userId': userId,
        'directReferrals': stats['directReferrals'],
        'teamSize': stats['teamSize'],
        'teamReferrals': stats['teamReferrals'],
        'timestamp': FieldValue.serverTimestamp(),
        'calculatedAt': stats['calculatedAt'],
      });
    } catch (e) {
      // Don't fail the main operation for history recording
      debugPrint('Warning: Failed to record statistics history: $e');
    }
  }
  
  /// Get user statistics with historical data
  static Future<Map<String, dynamic>> getUserStatistics(String userId, {bool includeHistory = false}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw ReferralStatisticsException(
          'User not found: $userId',
          'USER_NOT_FOUND',
          {'userId': userId}
        );
      }
      
      final userData = userDoc.data()!;
      final stats = {
        'userId': userId,
        'directReferrals': userData['directReferrals'] ?? 0,
        'teamSize': userData['teamSize'] ?? 0,
        'teamReferrals': userData['teamReferrals'] ?? userData['teamSize'] ?? 0,
        'lastStatsUpdate': userData['lastStatsUpdate'],
        'currentRole': userData['role'] ?? 'member',
        'membershipPaid': userData['membershipPaid'] ?? false,
        'referralCode': userData['referralCode'] ?? '',
      };
      
      if (includeHistory) {
        stats['history'] = await _getStatisticsHistory(userId);
      }
      
      return stats;
    } catch (e) {
      if (e is ReferralStatisticsException) {
        rethrow;
      }
      
      throw ReferralStatisticsException(
        'Failed to get user statistics: $e',
        'STATS_RETRIEVAL_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get statistics history for a user
  static Future<List<Map<String, dynamic>>> _getStatisticsHistory(String userId, {int limit = 30}) async {
    try {
      final query = await _firestore
          .collection('referralStatisticsHistory')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return []; // Return empty list if history retrieval fails
    }
  }
  
  /// Calculate statistics for pending vs active referrals
  static Future<Map<String, dynamic>> calculatePendingVsActiveStats(String userId) async {
    try {
      // Get user's referral code first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw ReferralStatisticsException('User not found', 'USER_NOT_FOUND');
      }
      
      final referralCode = userDoc.data()!['referralCode'] as String? ?? '';
      
      // Get direct referrals
      final directReferralsQuery = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: referralCode)
          .get();
      
      final directReferrals = directReferralsQuery.docs.map((doc) => doc.data()).toList();
      
      // In free app model, all users are active - no payment restrictions
      final totalReferrals = directReferrals.length;
      final active = totalReferrals; // All referrals are active
      final pending = 0; // No pending users in free app model
      
      // Get team size
      final teamSizeQuery = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .get();
      
      final teamSize = teamSizeQuery.docs.length;
      // In free app model, all team members are active
      final activeTeamSize = teamSize; // All team members are active
      final pendingTeamSize = teamSize - activeTeamSize;
      
      return {
        'directReferrals': {
          'total': directReferrals.length,
          'active': active,
          'pending': pending,
          'activationRate': directReferrals.isNotEmpty ? (active / directReferrals.length * 100).round() : 0,
        },
        'teamSize': {
          'total': teamSize,
          'active': activeTeamSize,
          'pending': pendingTeamSize,
          'activationRate': teamSize > 0 ? (activeTeamSize / teamSize * 100).round() : 0,
        },
        'calculatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw ReferralStatisticsException(
        'Failed to calculate pending vs active stats: $e',
        'PENDING_ACTIVE_CALCULATION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get team growth statistics
  static Future<Map<String, dynamic>> getTeamGrowthStatistics(String userId, {int days = 30}) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));
      
      // Get historical data
      final historyQuery = await _firestore
          .collection('referralStatisticsHistory')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('timestamp')
          .get();
      
      final history = historyQuery.docs.map((doc) => doc.data()).toList();
      
      // Calculate growth metrics
      final currentStats = await getUserStatistics(userId);
      final initialStats = history.isNotEmpty ? history.first : currentStats;
      
      final directGrowth = (currentStats['directReferrals'] as int) - (initialStats['directReferrals'] as int? ?? 0);
      final teamGrowth = (currentStats['teamSize'] as int) - (initialStats['teamSize'] as int? ?? 0);
      
      return {
        'period': '$days days',
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'growth': {
          'directReferrals': directGrowth,
          'teamSize': teamGrowth,
        },
        'current': {
          'directReferrals': currentStats['directReferrals'],
          'teamSize': currentStats['teamSize'],
        },
        'dataPoints': history.length,
        'calculatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw ReferralStatisticsException(
        'Failed to get team growth statistics: $e',
        'GROWTH_STATS_FAILED',
        {'userId': userId, 'days': days}
      );
    }
  }
  
  /// Get leaderboard statistics
  static Future<List<Map<String, dynamic>>> getLeaderboardStatistics({
    String sortBy = 'activeTeamSize',
    int limit = 50,
    String? roleFilter,
  }) async {
    try {
      Query query = _firestore.collection('users');
      
      // Apply role filter if specified
      if (roleFilter != null) {
        query = query.where('currentRole', isEqualTo: roleFilter);
      }
      
      // Free app model: Include all active users in leaderboard
      // No payment restrictions - all users can appear on leaderboard
      
      // Sort by specified field (ensure field exists)
      final validSortFields = ['directReferrals', 'teamSize', 'teamReferrals'];
      final actualSortBy = validSortFields.contains(sortBy) ? sortBy : 'teamSize';
      query = query.orderBy(actualSortBy, descending: true).limit(limit);
      
      final results = await query.get();
      
      return results.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'userId': doc.id,
          'fullName': data['fullName'],
          'currentRole': data['role'] ?? 'member',
          'directReferrals': data['directReferrals'] ?? 0,
          'teamSize': data['teamSize'] ?? 0,
          'teamReferrals': data['teamReferrals'] ?? data['teamSize'] ?? 0,
          'lastStatsUpdate': data['lastStatsUpdate'],
        };
      }).toList();
    } catch (e) {
      throw ReferralStatisticsException(
        'Failed to get leaderboard statistics: $e',
        'LEADERBOARD_FAILED',
        {'sortBy': sortBy, 'limit': limit, 'roleFilter': roleFilter}
      );
    }
  }
  
  /// Get global referral statistics
  static Future<Map<String, dynamic>> getGlobalStatistics() async {
    try {
      // Get total users
      final totalUsersQuery = await _firestore.collection('users').get();
      final totalUsers = totalUsersQuery.docs.length;
      
      // Free app model: Count all users as supporters (no payment distinction)
      // In free app model, all users are equal - payment only provides supporter badge
      final paidUsers = totalUsers; // All users are considered supporters in free model
      
      // Calculate total referrals
      int totalReferrals = 0;
      int totalTeamSize = 0;
      
      for (final doc in totalUsersQuery.docs) {
        final data = doc.data();
        totalReferrals += (data['directReferrals'] as int? ?? 0);
        totalTeamSize += (data['teamSize'] as int? ?? 0);
      }
      
      // Calculate role distribution
      final roleDistribution = <String, int>{};
      for (final doc in totalUsersQuery.docs) {
        final data = doc.data();
        final role = data['role'] as String? ?? 'member';
        roleDistribution[role] = (roleDistribution[role] ?? 0) + 1;
      }
      
      return {
        'totalUsers': totalUsers,
        'paidUsers': paidUsers,
        'pendingUsers': totalUsers - paidUsers,
        'conversionRate': totalUsers > 0 ? (paidUsers / totalUsers * 100).round() : 0,
        'totalReferrals': totalReferrals,
        'totalTeamSize': totalTeamSize,
        'averageReferralsPerUser': paidUsers > 0 ? (totalReferrals / paidUsers).round() : 0,
        'roleDistribution': roleDistribution,
        'calculatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw ReferralStatisticsException(
        'Failed to get global statistics: $e',
        'GLOBAL_STATS_FAILED'
      );
    }
  }
  
  /// Batch update statistics for multiple users efficiently
  static Future<void> batchUpdateStatistics(List<String> userIds, {int batchSize = 10}) async {
    try {
      // Process in batches to avoid overwhelming Firestore
      for (int i = 0; i < userIds.length; i += batchSize) {
        final batchUserIds = userIds.skip(i).take(batchSize).toList();
        
        // Update each user's statistics
        for (final userId in batchUserIds) {
          try {
            await updateUserStatistics(userId);
          } catch (e) {
            debugPrint('Warning: Failed to update stats for user $userId: $e');
          }
        }
        
        // Small delay between batches to avoid rate limiting
        if (i + batchSize < userIds.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      throw ReferralStatisticsException(
        'Failed to batch update statistics: $e',
        'BATCH_UPDATE_FAILED',
        {'userIds': userIds, 'batchSize': batchSize}
      );
    }
  }
  
  /// Get statistics summary for dashboard
  static Future<Map<String, dynamic>> getStatisticsSummary(String userId) async {
    try {
      final userStats = await getUserStatistics(userId);
      final pendingActiveStats = await calculatePendingVsActiveStats(userId);
      final growthStats = await getTeamGrowthStatistics(userId, days: 7);
      
      return {
        'user': userStats,
        'pendingVsActive': pendingActiveStats,
        'weeklyGrowth': growthStats,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw ReferralStatisticsException(
        'Failed to get statistics summary: $e',
        'SUMMARY_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Check if statistics need updating
  static Future<bool> needsStatisticsUpdate(String userId, {Duration maxAge = const Duration(hours: 1)}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return true;
      
      final userData = userDoc.data()!;
      final lastUpdate = userData['lastStatsUpdate'] as Timestamp?;
      
      if (lastUpdate == null) return true;
      
      final lastUpdateTime = lastUpdate.toDate();
      final now = DateTime.now();
      
      return now.difference(lastUpdateTime) > maxAge;
    } catch (e) {
      return true; // If we can't determine, assume update is needed
    }
  }
}
