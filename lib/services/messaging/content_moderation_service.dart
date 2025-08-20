// Content Moderation Service for TALOWA Messaging System
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/content_report_model.dart';
import '../../models/messaging/moderation_action_model.dart';
import '../../models/messaging/message_model.dart';
import 'content_filter_service.dart';

class ContentModerationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Report inappropriate content
  static Future<String> reportContent({
    required String reporterId,
    required String reporterName,
    required String messageId,
    required String conversationId,
    required String reportedUserId,
    required String reportedUserName,
    required ReportType reportType,
    required String reason,
    String? description,
  }) async {
    try {
      final report = ContentReportModel(
        id: '', // Will be set by Firestore
        reporterId: reporterId,
        reporterName: reporterName,
        messageId: messageId,
        conversationId: conversationId,
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        reportType: reportType,
        reason: reason,
        description: description,
        status: ReportStatus.pending,
        reportedAt: DateTime.now(),
        metadata: {
          'reporterIP': 'hidden_for_privacy',
          'deviceInfo': 'mobile_app',
        },
      );

      final docRef = await _firestore
          .collection('content_reports')
          .add(report.toFirestore());

      // Auto-flag high-severity reports for immediate review
      if (reportType == ReportType.violence || reportType == ReportType.harassment) {
        await _flagForUrgentReview(docRef.id);
      }

      debugPrint('Content report created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error reporting content: $e');
      throw Exception('Failed to report content: $e');
    }
  }

  /// Get pending reports for admin review
  static Stream<List<ContentReportModel>> getPendingReports() {
    return _firestore
        .collection('content_reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContentReportModel.fromFirestore(doc))
            .toList());
  }

  /// Get all reports with filtering
  static Stream<List<ContentReportModel>> getReports({
    ReportStatus? status,
    ReportType? type,
    String? reportedUserId,
    int limit = 50,
  }) {
    Query query = _firestore.collection('content_reports');

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }
    if (type != null) {
      query = query.where('reportType', isEqualTo: type.value);
    }
    if (reportedUserId != null) {
      query = query.where('reportedUserId', isEqualTo: reportedUserId);
    }

    return query
        .orderBy('reportedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContentReportModel.fromFirestore(doc))
            .toList());
  }

  /// Review a content report
  static Future<void> reviewReport({
    required String reportId,
    required String reviewerId,
    required String reviewerName,
    required ReportStatus newStatus,
    String? reviewNotes,
    ModerationActionType? actionType,
    String? actionReason,
    Duration? actionDuration,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reportRef = _firestore.collection('content_reports').doc(reportId);
        final reportDoc = await transaction.get(reportRef);

        if (!reportDoc.exists) {
          throw Exception('Report not found');
        }

        final report = ContentReportModel.fromFirestore(reportDoc);

        // Update report status
        final updatedReport = report.copyWith(
          status: newStatus,
          reviewedAt: DateTime.now(),
          reviewedBy: reviewerId,
          reviewNotes: reviewNotes,
        );

        transaction.update(reportRef, updatedReport.toFirestore());

        // If resolved with action, create moderation action
        if (newStatus == ReportStatus.resolved && actionType != null) {
          await _createModerationAction(
            targetUserId: report.reportedUserId,
            targetUserName: report.reportedUserName,
            moderatorId: reviewerId,
            moderatorName: reviewerName,
            actionType: actionType,
            reason: actionReason ?? 'Content violation',
            duration: actionDuration,
            relatedReportId: reportId,
            relatedMessageId: report.messageId,
            transaction: transaction,
          );
        }
      });

      // Log transparency action
      await _logTransparencyAction(
        action: 'report_reviewed',
        moderatorId: reviewerId,
        targetId: reportId,
        details: {
          'newStatus': newStatus.value,
          'actionType': actionType?.value,
          'reviewNotes': reviewNotes,
        },
      );

      debugPrint('Report reviewed: $reportId');
    } catch (e) {
      debugPrint('Error reviewing report: $e');
      throw Exception('Failed to review report: $e');
    }
  }

  /// Create moderation action
  static Future<String> _createModerationAction({
    required String targetUserId,
    required String targetUserName,
    required String moderatorId,
    required String moderatorName,
    required ModerationActionType actionType,
    required String reason,
    Duration? duration,
    String? relatedReportId,
    String? relatedMessageId,
    Transaction? transaction,
  }) async {
    final action = ModerationActionModel(
      id: '', // Will be set by Firestore
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      moderatorId: moderatorId,
      moderatorName: moderatorName,
      actionType: actionType,
      reason: reason,
      actionTaken: DateTime.now(),
      expiresAt: duration != null ? DateTime.now().add(duration) : null,
      isActive: true,
      relatedReportId: relatedReportId,
      relatedMessageId: relatedMessageId,
      metadata: {
        'duration': duration?.inMinutes,
        'automated': false,
      },
    );

    if (transaction != null) {
      final docRef = _firestore.collection('moderation_actions').doc();
      transaction.set(docRef, action.toFirestore());
      return docRef.id;
    } else {
      final docRef = await _firestore
          .collection('moderation_actions')
          .add(action.toFirestore());
      return docRef.id;
    }
  }

  /// Get active moderation actions for user
  static Future<List<ModerationActionModel>> getUserModerationActions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('moderation_actions')
          .where('targetUserId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('actionTaken', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ModerationActionModel.fromFirestore(doc))
          .where((action) => !action.isExpired) // Filter out expired actions
          .toList();
    } catch (e) {
      debugPrint('Error getting user moderation actions: $e');
      return [];
    }
  }

  /// Check if user can send messages
  static Future<bool> canUserSendMessages(String userId) async {
    try {
      final actions = await getUserModerationActions(userId);
      
      // Check for permanent ban
      final hasPermanentBan = actions.any(
        (action) => action.actionType == ModerationActionType.permanentBan,
      );
      if (hasPermanentBan) return false;

      // Check for active temporary restrictions
      final hasActiveRestriction = actions.any(
        (action) => action.actionType == ModerationActionType.temporaryRestriction && 
                   !action.isExpired,
      );
      if (hasActiveRestriction) return false;

      // Check content filter blocking
      if (ContentFilterService.isUserBlocked(userId)) return false;

      return true;
    } catch (e) {
      debugPrint('Error checking user message permissions: $e');
      return true; // Default to allow if error occurs
    }
  }

  /// Remove message (soft delete)
  static Future<void> removeMessage(String messageId, String moderatorId, String reason) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final messageRef = _firestore.collection('messages').doc(messageId);
        final messageDoc = await transaction.get(messageRef);

        if (!messageDoc.exists) {
          throw Exception('Message not found');
        }

        // Soft delete the message
        transaction.update(messageRef, {
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': moderatorId,
          'deletionReason': reason,
          'content': '[Message removed by moderator]',
        });
      });

      // Log transparency action
      await _logTransparencyAction(
        action: 'message_removed',
        moderatorId: moderatorId,
        targetId: messageId,
        details: {'reason': reason},
      );

      debugPrint('Message removed: $messageId');
    } catch (e) {
      debugPrint('Error removing message: $e');
      throw Exception('Failed to remove message: $e');
    }
  }

  /// Flag report for urgent review
  static Future<void> _flagForUrgentReview(String reportId) async {
    try {
      await _firestore.collection('urgent_reviews').add({
        'reportId': reportId,
        'flaggedAt': FieldValue.serverTimestamp(),
        'priority': 'high',
        'reviewed': false,
      });
    } catch (e) {
      debugPrint('Error flagging for urgent review: $e');
    }
  }

  /// Log transparency action
  static Future<void> _logTransparencyAction({
    required String action,
    required String moderatorId,
    required String targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _firestore.collection('transparency_logs').add({
        'action': action,
        'moderatorId': moderatorId,
        'targetId': targetId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details ?? {},
      });
    } catch (e) {
      debugPrint('Error logging transparency action: $e');
    }
  }

  /// Get transparency logs
  static Stream<List<Map<String, dynamic>>> getTransparencyLogs({
    String? moderatorId,
    String? action,
    int limit = 100,
  }) {
    Query query = _firestore.collection('transparency_logs');

    if (moderatorId != null) {
      query = query.where('moderatorId', isEqualTo: moderatorId);
    }
    if (action != null) {
      query = query.where('action', isEqualTo: action);
    }

    return query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList());
  }

  /// Get moderation statistics
  static Future<Map<String, dynamic>> getModerationStats() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      final last7Days = now.subtract(const Duration(days: 7));

      // Get report counts
      final reportsLast24h = await _firestore
          .collection('content_reports')
          .where('reportedAt', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();

      final reportsLast7d = await _firestore
          .collection('content_reports')
          .where('reportedAt', isGreaterThan: Timestamp.fromDate(last7Days))
          .get();

      final pendingReports = await _firestore
          .collection('content_reports')
          .where('status', isEqualTo: 'pending')
          .get();

      // Get action counts
      final actionsLast24h = await _firestore
          .collection('moderation_actions')
          .where('actionTaken', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();

      return {
        'reportsLast24Hours': reportsLast24h.size,
        'reportsLast7Days': reportsLast7d.size,
        'pendingReports': pendingReports.size,
        'actionsLast24Hours': actionsLast24h.size,
        'lastUpdated': now.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting moderation stats: $e');
      return {
        'error': 'Failed to load statistics',
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }
}