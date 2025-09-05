// Admin Dashboard Service for TALOWA Messaging System
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/conversation_model.dart';
import '../messaging/content_moderation_service.dart';

class AdminDashboardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get dashboard overview data
  static Future<AdminDashboardData> getDashboardOverview() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      final last7Days = now.subtract(const Duration(days: 7));

      // Get various counts in parallel
      final futures = await Future.wait([
        _getActiveUsersCount(),
        _getMessagesCount(last24Hours),
        _getConversationsCount(),
        _getPendingReportsCount(),
        _getActiveActionsCount(),
        _getUrgentReviewsCount(),
      ]);

      final moderationStats = await ContentModerationService.getModerationStats();

      return AdminDashboardData(
        activeUsers: futures[0],
        messagesLast24h: futures[1],
        totalConversations: futures[2],
        pendingReports: futures[3],
        activeActions: futures[4],
        urgentReviews: futures[5],
        moderationStats: moderationStats,
        lastUpdated: now,
      );
    } catch (e) {
      debugPrint('Error getting dashboard overview: $e');
      throw Exception('Failed to load dashboard data: $e');
    }
  }

  /// Get active users count (users who sent messages in last 24h)
  static Future<int> _getActiveUsersCount() async {
    try {
      final last24Hours = DateTime.now().subtract(const Duration(hours: 24));
      final snapshot = await _firestore
          .collection('messages')
          .where('sentAt', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();

      // Count unique senders
      final uniqueSenders = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        uniqueSenders.add(data['senderId'] ?? '');
      }

      return uniqueSenders.length;
    } catch (e) {
      debugPrint('Error getting active users count: $e');
      return 0;
    }
  }

  /// Get messages count since given time
  static Future<int> _getMessagesCount(DateTime since) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('sentAt', isGreaterThan: Timestamp.fromDate(since))
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting messages count: $e');
      return 0;
    }
  }

  /// Get total conversations count
  static Future<int> _getConversationsCount() async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting conversations count: $e');
      return 0;
    }
  }

  /// Get pending reports count
  static Future<int> _getPendingReportsCount() async {
    try {
      final snapshot = await _firestore
          .collection('content_reports')
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting pending reports count: $e');
      return 0;
    }
  }

  /// Get active moderation actions count
  static Future<int> _getActiveActionsCount() async {
    try {
      final snapshot = await _firestore
          .collection('moderation_actions')
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting active actions count: $e');
      return 0;
    }
  }

  /// Get urgent reviews count
  static Future<int> _getUrgentReviewsCount() async {
    try {
      final snapshot = await _firestore
          .collection('urgent_reviews')
          .where('reviewed', isEqualTo: false)
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting urgent reviews count: $e');
      return 0;
    }
  }

  /// Get conversation monitoring data
  static Stream<List<ConversationMonitorData>> getConversationMonitoring({
    int limit = 20,
  }) {
    return _firestore
        .collection('conversations')
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final List<ConversationMonitorData> monitorData = [];

          for (final doc in snapshot.docs) {
            final conversation = ConversationModel.fromFirestore(doc);
            
            // Get recent message count
            final recentMessages = await _getRecentMessageCount(conversation.id);
            
            // Get report count for this conversation
            final reportCount = await _getConversationReportCount(conversation.id);

            monitorData.add(ConversationMonitorData(
              conversation: conversation,
              recentMessageCount: recentMessages,
              reportCount: reportCount,
              riskLevel: _calculateRiskLevel(recentMessages, reportCount),
            ));
          }

          return monitorData;
        });
  }

  /// Get recent message count for conversation
  static Future<int> _getRecentMessageCount(String conversationId) async {
    try {
      final last24Hours = DateTime.now().subtract(const Duration(hours: 24));
      final snapshot = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('sentAt', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  /// Get report count for conversation
  static Future<int> _getConversationReportCount(String conversationId) async {
    try {
      final snapshot = await _firestore
          .collection('content_reports')
          .where('conversationId', isEqualTo: conversationId)
          .where('status', whereIn: ['pending', 'reviewing'])
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  /// Calculate risk level for conversation
  static RiskLevel _calculateRiskLevel(int recentMessages, int reportCount) {
    if (reportCount >= 3) return RiskLevel.high;
    if (reportCount >= 1 || recentMessages > 100) return RiskLevel.medium;
    if (recentMessages > 50) return RiskLevel.low;
    return RiskLevel.none;
  }

  /// Get user activity monitoring data
  static Stream<List<UserActivityData>> getUserActivityMonitoring({
    int limit = 50,
  }) {
    return _firestore
        .collection('users')
        .where('status', isEqualTo: 'active')
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final List<UserActivityData> activityData = [];

          for (final doc in snapshot.docs) {
            final userData = doc.data();
            final userId = doc.id;
            
            // Get user's recent activity
            final messageCount = await _getUserMessageCount(userId);
            final reportCount = await _getUserReportCount(userId);
            final actionCount = await _getUserActionCount(userId);

            activityData.add(UserActivityData(
              userId: userId,
              userName: userData['name'] ?? 'Unknown',
              role: userData['role'] ?? 'member',
              messageCount: messageCount,
              reportCount: reportCount,
              actionCount: actionCount,
              lastActive: (userData['updatedAt'] as Timestamp?)?.toDate(),
              riskLevel: _calculateUserRiskLevel(messageCount, reportCount, actionCount),
            ));
          }

          return activityData;
        });
  }

  /// Get user message count in last 24h
  static Future<int> _getUserMessageCount(String userId) async {
    try {
      final last24Hours = DateTime.now().subtract(const Duration(hours: 24));
      final snapshot = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .where('sentAt', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  /// Get reports against user
  static Future<int> _getUserReportCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('content_reports')
          .where('reportedUserId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'reviewing'])
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  /// Get active actions against user
  static Future<int> _getUserActionCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('moderation_actions')
          .where('targetUserId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  /// Calculate user risk level
  static RiskLevel _calculateUserRiskLevel(int messageCount, int reportCount, int actionCount) {
    if (actionCount > 0 || reportCount >= 2) return RiskLevel.high;
    if (reportCount >= 1 || messageCount > 50) return RiskLevel.medium;
    if (messageCount > 20) return RiskLevel.low;
    return RiskLevel.none;
  }

  /// Search conversations by criteria
  static Future<List<ConversationModel>> searchConversations({
    String? searchTerm,
    ConversationType? type,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore.collection('conversations');

      if (type != null) {
        query = query.where('type', isEqualTo: type.value);
      }

      final snapshot = await query
          .orderBy('lastMessageAt', descending: true)
          .limit(limit)
          .get();

      List<ConversationModel> conversations = snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();

      // Filter by search term if provided
      if (searchTerm != null && searchTerm.isNotEmpty) {
        conversations = conversations.where((conv) =>
            conv.name.toLowerCase().contains(searchTerm.toLowerCase()) ||
            conv.lastMessage.toLowerCase().contains(searchTerm.toLowerCase())
        ).toList();
      }

      return conversations;
    } catch (e) {
      debugPrint('Error searching conversations: $e');
      return [];
    }
  }

  /// Export moderation data for compliance
  static Future<Map<String, dynamic>> exportModerationData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get reports in date range
      final reportsSnapshot = await _firestore
          .collection('content_reports')
          .where('reportedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('reportedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      // Get actions in date range
      final actionsSnapshot = await _firestore
          .collection('moderation_actions')
          .where('actionTaken', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('actionTaken', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      // Get transparency logs in date range
      final logsSnapshot = await _firestore
          .collection('transparency_logs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      return {
        'exportDate': DateTime.now().toIso8601String(),
        'dateRange': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        'reports': reportsSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
        'actions': actionsSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
        'transparencyLogs': logsSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
        'summary': {
          'totalReports': reportsSnapshot.size,
          'totalActions': actionsSnapshot.size,
          'totalLogs': logsSnapshot.size,
        },
      };
    } catch (e) {
      debugPrint('Error exporting moderation data: $e');
      throw Exception('Failed to export moderation data: $e');
    }
  }
}

/// Admin dashboard data model
class AdminDashboardData {
  final int activeUsers;
  final int messagesLast24h;
  final int totalConversations;
  final int pendingReports;
  final int activeActions;
  final int urgentReviews;
  final Map<String, dynamic> moderationStats;
  final DateTime lastUpdated;

  AdminDashboardData({
    required this.activeUsers,
    required this.messagesLast24h,
    required this.totalConversations,
    required this.pendingReports,
    required this.activeActions,
    required this.urgentReviews,
    required this.moderationStats,
    required this.lastUpdated,
  });
}

/// Conversation monitoring data
class ConversationMonitorData {
  final ConversationModel conversation;
  final int recentMessageCount;
  final int reportCount;
  final RiskLevel riskLevel;

  ConversationMonitorData({
    required this.conversation,
    required this.recentMessageCount,
    required this.reportCount,
    required this.riskLevel,
  });
}

/// User activity data
class UserActivityData {
  final String userId;
  final String userName;
  final String role;
  final int messageCount;
  final int reportCount;
  final int actionCount;
  final DateTime? lastActive;
  final RiskLevel riskLevel;

  UserActivityData({
    required this.userId,
    required this.userName,
    required this.role,
    required this.messageCount,
    required this.reportCount,
    required this.actionCount,
    this.lastActive,
    required this.riskLevel,
  });
}

/// Risk level enum
enum RiskLevel {
  none,
  low,
  medium,
  high,
}

extension RiskLevelExtension on RiskLevel {
  String get displayName {
    switch (this) {
      case RiskLevel.none:
        return 'No Risk';
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
    }
  }

  String get colorCode {
    switch (this) {
      case RiskLevel.none:
        return '#4CAF50'; // Green
      case RiskLevel.low:
        return '#FFC107'; // Amber
      case RiskLevel.medium:
        return '#FF9800'; // Orange
      case RiskLevel.high:
        return '#F44336'; // Red
    }
  }
}
