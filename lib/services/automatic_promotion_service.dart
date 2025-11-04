import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Automatic Role Promotion Service
/// Handles real-time role promotion when users reach 100% achievement threshold
class AutomaticPromotionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Role thresholds for automatic promotion
  static const List<Map<String, dynamic>> roleThresholds = [
    {"level": 9, "name": "State Coordinator", "direct": 1000, "team": 3000000},
    {"level": 8, "name": "Zonal Regional Coordinator", "direct": 500, "team": 1500000},
    {"level": 7, "name": "District Coordinator", "direct": 320, "team": 500000},
    {"level": 6, "name": "Constituency Coordinator", "direct": 160, "team": 50000},
    {"level": 5, "name": "Mandal Coordinator", "direct": 80, "team": 6000},
    {"level": 4, "name": "Area Coordinator", "direct": 40, "team": 700},
    {"level": 3, "name": "Team Leader", "direct": 20, "team": 100},
    {"level": 2, "name": "Volunteer", "direct": 10, "team": 10},
    {"level": 1, "name": "Member", "direct": 0, "team": 0},
  ];

  /// Listen to user's promotion progress in real-time
  static Stream<PromotionProgress> listenToPromotionProgress(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('User not found');
      }

      final userData = snapshot.data()!;
      return _calculatePromotionProgress(userData);
    });
  }

  /// Calculate promotion progress for a user
  static PromotionProgress _calculatePromotionProgress(Map<String, dynamic> userData) {
    final currentRoleLevel = userData['currentRoleLevel'] ?? 1;
    final directReferrals = userData['directReferrals'] ?? 0;
    final teamReferrals = userData['teamReferrals'] ?? userData['teamSize'] ?? 0;

    // Find current role
    final currentRole = roleThresholds.firstWhere(
      (role) => role['level'] == currentRoleLevel,
      orElse: () => roleThresholds.last,
    );

    // Find next role
    final nextRoleIndex = roleThresholds.indexWhere(
      (role) => role['level'] == currentRoleLevel + 1,
    );
    final nextRole = nextRoleIndex != -1 ? roleThresholds[nextRoleIndex] : null;

    double directProgress = 100.0;
    double teamProgress = 100.0;
    double overallProgress = 100.0;
    bool readyForPromotion = false;

    if (nextRole != null) {
      directProgress = ((directReferrals / nextRole['direct']) * 100).clamp(0.0, 100.0);
      teamProgress = ((teamReferrals / nextRole['team']) * 100).clamp(0.0, 100.0);
      overallProgress = [directProgress, teamProgress].reduce((a, b) => a < b ? a : b);
      readyForPromotion = directReferrals >= nextRole['direct'] && teamReferrals >= nextRole['team'];
    }

    return PromotionProgress(
      currentRole: RoleInfo.fromMap(currentRole),
      nextRole: nextRole != null ? RoleInfo.fromMap(nextRole) : null,
      directReferrals: directReferrals,
      teamReferrals: teamReferrals,
      directProgress: directProgress,
      teamProgress: teamProgress,
      overallProgress: overallProgress,
      readyForPromotion: readyForPromotion,
    );
  }

  /// Manually trigger promotion check
  static Future<bool> triggerPromotionCheck([String? userId]) async {
    try {
      final uid = userId ?? _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('triggerRolePromotionCheck');
      final result = await callable.call({'userId': uid});

      if (kDebugMode) {
        print('✅ Promotion check triggered: ${result.data}');
      }

      return result.data['success'] ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to trigger promotion check: $e');
      }
      return false;
    }
  }

  /// Listen to promotion notifications
  static Stream<List<PromotionNotification>> listenToPromotionNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: 'automatic_promotion')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PromotionNotification(
          id: doc.id,
          title: data['title'] ?? '',
          message: data['message'] ?? '',
          read: data['read'] ?? false,
          priority: data['priority'] ?? 'normal',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          data: data['data'] ?? {},
        );
      }).toList();
    });
  }

  /// Mark promotion notification as read
  static Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to mark notification as read: $e');
      }
    }
  }

  /// Check if user is ready for immediate promotion
  static Future<bool> isReadyForPromotion(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final progress = _calculatePromotionProgress(userDoc.data()!);
      return progress.readyForPromotion;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to check promotion readiness: $e');
      }
      return false;
    }
  }

  /// Get next role requirements
  static Map<String, dynamic>? getNextRoleRequirements(int currentLevel) {
    final nextRoleIndex = roleThresholds.indexWhere(
      (role) => role['level'] == currentLevel + 1,
    );
    return nextRoleIndex != -1 ? roleThresholds[nextRoleIndex] : null;
  }
}

/// Promotion Progress Model
class PromotionProgress {
  final RoleInfo currentRole;
  final RoleInfo? nextRole;
  final int directReferrals;
  final int teamReferrals;
  final double directProgress;
  final double teamProgress;
  final double overallProgress;
  final bool readyForPromotion;

  PromotionProgress({
    required this.currentRole,
    this.nextRole,
    required this.directReferrals,
    required this.teamReferrals,
    required this.directProgress,
    required this.teamProgress,
    required this.overallProgress,
    required this.readyForPromotion,
  });

  /// Check if user has achieved 100% progress
  bool get hasAchieved100Percent => overallProgress >= 100.0;

  /// Get progress percentage as string
  String get progressPercentage => '${overallProgress.toStringAsFixed(1)}%';
}

/// Role Information Model
class RoleInfo {
  final int level;
  final String name;
  final int directRequirement;
  final int teamRequirement;

  RoleInfo({
    required this.level,
    required this.name,
    required this.directRequirement,
    required this.teamRequirement,
  });

  factory RoleInfo.fromMap(Map<String, dynamic> map) {
    return RoleInfo(
      level: map['level'] ?? 1,
      name: map['name'] ?? 'Member',
      directRequirement: map['direct'] ?? 0,
      teamRequirement: map['team'] ?? 0,
    );
  }
}

/// Promotion Notification Model
class PromotionNotification {
  final String id;
  final String title;
  final String message;
  final bool read;
  final String priority;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  PromotionNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.read,
    required this.priority,
    required this.createdAt,
    required this.data,
  });

  /// Check if this is a high priority notification
  bool get isHighPriority => priority == 'high';

  /// Get formatted time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}