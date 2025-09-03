// Enhanced Admin Dashboard Service - Advanced analytics and insights
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminDashboardEnhancedService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get comprehensive dashboard statistics
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Run all queries in parallel for better performance
      final futures = await Future.wait([
        _getUserStats(),
        _getReferralStats(),
        _getGrowthStats(),
        _getActiveEvents(),
        _getFraudDetectionStats(),
        _getSystemHealth(),
      ]);

      return {
        'userStats': futures[0],
        'referralStats': futures[1],
        'growthStats': futures[2],
        'activeEvents': futures[3],
        'fraudDetection': futures[4],
        'systemHealth': futures[5],
        'lastUpdated': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      throw Exception('Failed to load dashboard stats: ${e.toString()}');
    }
  }

  /// Get user statistics
  static Future<Map<String, dynamic>> _getUserStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final users = usersSnapshot.docs.map((doc) => doc.data()).toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thisWeek = now.subtract(const Duration(days: 7));
      final thisMonth = DateTime(now.year, now.month, 1);

      int totalUsers = users.length;
      int activeUsers = 0;
      int newUsersToday = 0;
      int newUsersThisWeek = 0;
      int newUsersThisMonth = 0;
      int bannedUsers = 0;

      for (final user in users) {
        // Count active users (logged in within last 30 days)
        final lastLogin = user['lastLogin'] as Timestamp?;
        if (lastLogin != null && 
            lastLogin.toDate().isAfter(now.subtract(const Duration(days: 30)))) {
          activeUsers++;
        }

        // Count new users
        final createdAt = user['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final createdDate = createdAt.toDate();
          if (createdDate.isAfter(today)) {
            newUsersToday++;
          }
          if (createdDate.isAfter(thisWeek)) {
            newUsersThisWeek++;
          }
          if (createdDate.isAfter(thisMonth)) {
            newUsersThisMonth++;
          }
        }

        // Count banned users
        if (user['status'] == 'banned') {
          bannedUsers++;
        }
      }

      return {
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'newUsersToday': newUsersToday,
        'newUsersThisWeek': newUsersThisWeek,
        'newUsersThisMonth': newUsersThisMonth,
        'bannedUsers': bannedUsers,
        'activeUserPercentage': totalUsers > 0 ? (activeUsers / totalUsers * 100).round() : 0,
      };

    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return {};
    }
  }

  /// Get referral system statistics
  static Future<Map<String, dynamic>> _getReferralStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final users = usersSnapshot.docs.map((doc) => doc.data()).toList();

      int totalReferrals = 0;
      int directReferrals = 0;
      int teamReferrals = 0;
      double averageTeamSize = 0;
      int topPerformers = 0;
      List<Map<String, dynamic>> referralFunnel = [];

      // Referral performance tiers
      Map<String, int> performanceTiers = {
        '0 referrals': 0,
        '1-5 referrals': 0,
        '6-20 referrals': 0,
        '21-50 referrals': 0,
        '50+ referrals': 0,
      };

      for (final user in users) {
        final referralStats = user['referralStats'] as Map<String, dynamic>?;
        if (referralStats != null) {
          final direct = referralStats['directReferrals'] as int? ?? 0;
          final team = referralStats['teamSize'] as int? ?? 0;

          directReferrals += direct;
          teamReferrals += team;

          // Categorize performance
          if (direct == 0) {
            performanceTiers['0 referrals'] = performanceTiers['0 referrals']! + 1;
          } else if (direct <= 5) {
            performanceTiers['1-5 referrals'] = performanceTiers['1-5 referrals']! + 1;
          } else if (direct <= 20) {
            performanceTiers['6-20 referrals'] = performanceTiers['6-20 referrals']! + 1;
          } else if (direct <= 50) {
            performanceTiers['21-50 referrals'] = performanceTiers['21-50 referrals']! + 1;
          } else {
            performanceTiers['50+ referrals'] = performanceTiers['50+ referrals']! + 1;
            topPerformers++;
          }
        }
      }

      totalReferrals = directReferrals;
      averageTeamSize = users.isNotEmpty ? teamReferrals / users.length : 0;

      // Create referral funnel data
      referralFunnel = performanceTiers.entries.map((entry) => {
        'tier': entry.key,
        'count': entry.value,
        'percentage': users.isNotEmpty ? (entry.value / users.length * 100).round() : 0,
      }).toList();

      return {
        'totalReferrals': totalReferrals,
        'directReferrals': directReferrals,
        'teamReferrals': teamReferrals,
        'averageTeamSize': averageTeamSize.round(),
        'topPerformers': topPerformers,
        'referralFunnel': referralFunnel,
        'conversionRate': users.isNotEmpty ? (directReferrals / users.length * 100).round() : 0,
      };

    } catch (e) {
      debugPrint('Error getting referral stats: $e');
      return {};
    }
  }

  /// Get growth statistics and trends
  static Future<Map<String, dynamic>> _getGrowthStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final users = usersSnapshot.docs.map((doc) => doc.data()).toList();

      // Calculate growth over last 30 days
      final now = DateTime.now();
      List<Map<String, dynamic>> dailyGrowth = [];
      
      for (int i = 29; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        int newUsers = 0;
        int newReferrals = 0;

        for (final user in users) {
          final createdAt = user['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final createdDate = createdAt.toDate();
            if (createdDate.isAfter(dayStart) && createdDate.isBefore(dayEnd)) {
              newUsers++;
            }
          }

          // Count referrals made on this day
          final referralStats = user['referralStats'] as Map<String, dynamic>?;
          if (referralStats != null) {
            final lastReferralDate = referralStats['lastReferralDate'] as Timestamp?;
            if (lastReferralDate != null) {
              final referralDate = lastReferralDate.toDate();
              if (referralDate.isAfter(dayStart) && referralDate.isBefore(dayEnd)) {
                newReferrals++;
              }
            }
          }
        }

        dailyGrowth.add({
          'date': dayStart.toIso8601String().split('T')[0],
          'newUsers': newUsers,
          'newReferrals': newReferrals,
        });
      }

      // Calculate growth rate
      final last7Days = dailyGrowth.skip(dailyGrowth.length - 7).fold<int>(0, (sum, day) => sum + (day['newUsers'] as int));
      final previous7Days = dailyGrowth.skip(15).take(7).fold<int>(0, (sum, day) => sum + (day['newUsers'] as int));
      final growthRate = previous7Days > 0 ? ((last7Days - previous7Days) / previous7Days * 100).round() : 0;

      return {
        'dailyGrowth': dailyGrowth,
        'weeklyGrowthRate': growthRate,
        'totalGrowthLast30Days': dailyGrowth.fold<int>(0, (sum, day) => sum + (day['newUsers'] as int)),
        'averageDailyGrowth': (dailyGrowth.fold<int>(0, (sum, day) => sum + (day['newUsers'] as int)) / 30).round(),
      };

    } catch (e) {
      debugPrint('Error getting growth stats: $e');
      return {};
    }
  }

  /// Get real-time active events
  static Future<List<Map<String, dynamic>>> _getActiveEvents() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));

      // Get recent registrations
      final recentRegistrations = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last24Hours))
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      // Get recent referrals (from transparency logs if available)
      final recentActions = await _firestore
          .collection('transparency_logs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(last24Hours))
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      List<Map<String, dynamic>> events = [];

      // Add registration events
      for (final doc in recentRegistrations.docs) {
        final user = doc.data();
        events.add({
          'type': 'registration',
          'message': 'New user registered: ${user['phoneNumber'] ?? 'Unknown'}',
          'timestamp': user['createdAt'],
          'severity': 'info',
        });
      }

      // Add admin action events
      for (final doc in recentActions.docs) {
        final action = doc.data();
        events.add({
          'type': 'admin_action',
          'message': 'Admin action: ${action['action'] ?? 'Unknown'}',
          'timestamp': action['timestamp'],
          'severity': _getActionSeverity(action['action'] as String?),
        });
      }

      // Sort by timestamp
      events.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bTime = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      return events.take(15).toList();

    } catch (e) {
      debugPrint('Error getting active events: $e');
      return [];
    }
  }

  /// Get fraud detection statistics
  static Future<Map<String, dynamic>> _getFraudDetectionStats() async {
    try {
      // Get flagged activities
      final flaggedSnapshot = await _firestore
          .collection('flagged_activities')
          .where('flaggedAt', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))))
          .get();

      final flaggedActivities = flaggedSnapshot.docs.map((doc) => doc.data()).toList();

      Map<String, int> flagTypes = {};
      int resolvedFlags = 0;
      int pendingFlags = 0;

      for (final activity in flaggedActivities) {
        final type = activity['type'] as String? ?? 'unknown';
        flagTypes[type] = (flagTypes[type] ?? 0) + 1;

        if (activity['resolved'] == true) {
          resolvedFlags++;
        } else {
          pendingFlags++;
        }
      }

      return {
        'totalFlags': flaggedActivities.length,
        'pendingFlags': pendingFlags,
        'resolvedFlags': resolvedFlags,
        'flagTypes': flagTypes,
        'riskScore': _calculateRiskScore(flaggedActivities.length, pendingFlags),
      };

    } catch (e) {
      debugPrint('Error getting fraud detection stats: $e');
      return {};
    }
  }

  /// Get system health metrics
  static Future<Map<String, dynamic>> _getSystemHealth() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));

      // Check for recent errors (if error logging is implemented)
      int errorCount = 0;
      int warningCount = 0;

      // Check database performance (simple metrics)
      final startTime = DateTime.now();
      await _firestore.collection('users').limit(1).get();
      final dbResponseTime = DateTime.now().difference(startTime).inMilliseconds;

      // Check for system alerts
      final alertsSnapshot = await _firestore
          .collection('admin_alerts')
          .where('sentAt', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();

      return {
        'status': 'healthy', // This would be determined by actual health checks
        'dbResponseTime': dbResponseTime,
        'errorCount24h': errorCount,
        'warningCount24h': warningCount,
        'alertCount24h': alertsSnapshot.docs.length,
        'uptime': '99.9%', // This would come from actual monitoring
        'lastHealthCheck': now.toIso8601String(),
      };

    } catch (e) {
      debugPrint('Error getting system health: $e');
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  /// Get predictive insights
  static Future<Map<String, dynamic>> getPredictiveInsights() async {
    try {
      final stats = await getDashboardStats();
      final userStats = stats['userStats'] as Map<String, dynamic>? ?? {};
      final growthStats = stats['growthStats'] as Map<String, dynamic>? ?? {};
      final referralStats = stats['referralStats'] as Map<String, dynamic>? ?? {};

      // Simple predictive calculations
      final currentGrowthRate = growthStats['weeklyGrowthRate'] as int? ?? 0;
      final totalUsers = userStats['totalUsers'] as int? ?? 0;
      final averageDailyGrowth = growthStats['averageDailyGrowth'] as int? ?? 0;

      // Predict user growth for next 30 days
      final predictedGrowth = averageDailyGrowth * 30;
      final predictedTotalUsers = totalUsers + predictedGrowth;

      // Identify trends
      List<String> trends = [];
      if (currentGrowthRate > 10) {
        trends.add('High growth rate detected');
      } else if (currentGrowthRate < -10) {
        trends.add('Declining growth rate - attention needed');
      }

      final conversionRate = referralStats['conversionRate'] as int? ?? 0;
      if (conversionRate < 20) {
        trends.add('Low referral conversion rate');
      } else if (conversionRate > 50) {
        trends.add('Excellent referral performance');
      }

      return {
        'predictedGrowth30Days': predictedGrowth,
        'predictedTotalUsers': predictedTotalUsers,
        'growthTrend': currentGrowthRate > 0 ? 'positive' : 'negative',
        'trends': trends,
        'recommendations': _generateRecommendations(stats),
      };

    } catch (e) {
      debugPrint('Error getting predictive insights: $e');
      return {};
    }
  }

  // Helper methods
  static String _getActionSeverity(String? action) {
    if (action == null) return 'info';
    
    if (action.contains('ban') || action.contains('delete')) {
      return 'high';
    } else if (action.contains('flag') || action.contains('moderate')) {
      return 'medium';
    } else {
      return 'info';
    }
  }

  static int _calculateRiskScore(int totalFlags, int pendingFlags) {
    if (totalFlags == 0) return 0;
    
    final riskScore = (pendingFlags / totalFlags * 100).round();
    return riskScore.clamp(0, 100);
  }

  static List<String> _generateRecommendations(Map<String, dynamic> stats) {
    List<String> recommendations = [];
    
    final userStats = stats['userStats'] as Map<String, dynamic>? ?? {};
    final referralStats = stats['referralStats'] as Map<String, dynamic>? ?? {};
    final fraudStats = stats['fraudDetection'] as Map<String, dynamic>? ?? {};

    // User engagement recommendations
    final activePercentage = userStats['activeUserPercentage'] as int? ?? 0;
    if (activePercentage < 30) {
      recommendations.add('Consider implementing user engagement campaigns');
    }

    // Referral system recommendations
    final conversionRate = referralStats['conversionRate'] as int? ?? 0;
    if (conversionRate < 25) {
      recommendations.add('Improve referral incentives to boost conversion');
    }

    // Security recommendations
    final pendingFlags = fraudStats['pendingFlags'] as int? ?? 0;
    if (pendingFlags > 10) {
      recommendations.add('Review and resolve pending fraud flags');
    }

    return recommendations;
  }
}