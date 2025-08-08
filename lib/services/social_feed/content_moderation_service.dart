// Content Moderation Service for TALOWA Social Feed
// Implements Task 12: Create content moderation tools

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/index.dart';

class ContentModerationService {
  static final ContentModerationService _instance = ContentModerationService._internal();
  factory ContentModerationService() => _instance;
  ContentModerationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Report a post for inappropriate content
  Future<String> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
    String? description,
    List<String>? evidenceUrls,
  }) async {
    try {
      final reportRef = await _firestore.collection('content_reports').add({
        'postId': postId,
        'reporterId': reporterId,
        'type': 'post',
        'reason': reason,
        'description': description,
        'evidenceUrls': evidenceUrls ?? [],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'resolution': null,
        'resolutionNotes': null,
      });

      // Update post with report flag
      await _firestore.collection('posts').doc(postId).update({
        'reportCount': FieldValue.increment(1),
        'hasReports': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log moderation action
      await _logModerationAction(
        action: 'report_created',
        targetType: 'post',
        targetId: postId,
        moderatorId: reporterId,
        details: {
          'reason': reason,
          'reportId': reportRef.id,
        },
      );

      return reportRef.id;
    } catch (e) {
      debugPrint('Error reporting post: $e');
      rethrow;
    }
  }

  // Report a comment for inappropriate content
  Future<String> reportComment({
    required String commentId,
    required String postId,
    required String reporterId,
    required String reason,
    String? description,
  }) async {
    try {
      final reportRef = await _firestore.collection('content_reports').add({
        'commentId': commentId,
        'postId': postId,
        'reporterId': reporterId,
        'type': 'comment',
        'reason': reason,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'resolution': null,
        'resolutionNotes': null,
      });

      // Update comment with report flag
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .update({
        'reportCount': FieldValue.increment(1),
        'hasReports': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logModerationAction(
        action: 'report_created',
        targetType: 'comment',
        targetId: commentId,
        moderatorId: reporterId,
        details: {
          'reason': reason,
          'reportId': reportRef.id,
          'postId': postId,
        },
      );

      return reportRef.id;
    } catch (e) {
      debugPrint('Error reporting comment: $e');
      rethrow;
    }
  }

  // Get pending reports for moderation
  Stream<List<ContentReport>> getPendingReports({
    String? type,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('content_reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ContentReport.fromFirestore(doc);
      }).toList();
    });
  }

  // Review and resolve a report
  Future<void> reviewReport({
    required String reportId,
    required String moderatorId,
    required String resolution,
    String? resolutionNotes,
    Map<String, dynamic>? actions,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reportRef = _firestore.collection('content_reports').doc(reportId);
        final reportDoc = await transaction.get(reportRef);

        if (!reportDoc.exists) {
          throw Exception('Report not found');
        }

        final reportData = reportDoc.data()!;
        final targetType = reportData['type'] as String;
        final targetId = reportData['postId'] ?? reportData['commentId'];

        // Update report status
        transaction.update(reportRef, {
          'status': 'resolved',
          'resolution': resolution,
          'resolutionNotes': resolutionNotes,
          'reviewedBy': moderatorId,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'actions': actions,
        });

        // Apply moderation actions if specified
        if (actions != null) {
          await _applyModerationActions(
            transaction: transaction,
            targetType: targetType,
            targetId: targetId,
            actions: actions,
            moderatorId: moderatorId,
          );
        }
      });

      await _logModerationAction(
        action: 'report_reviewed',
        targetType: 'report',
        targetId: reportId,
        moderatorId: moderatorId,
        details: {
          'resolution': resolution,
          'actions': actions,
        },
      );
    } catch (e) {
      debugPrint('Error reviewing report: $e');
      rethrow;
    }
  }

  // Apply moderation actions
  Future<void> _applyModerationActions({
    required Transaction transaction,
    required String targetType,
    required String targetId,
    required Map<String, dynamic> actions,
    required String moderatorId,
  }) async {
    if (targetType == 'post') {
      final postRef = _firestore.collection('posts').doc(targetId);
      
      if (actions['hide'] == true) {
        transaction.update(postRef, {
          'isHidden': true,
          'hiddenAt': FieldValue.serverTimestamp(),
          'hiddenBy': moderatorId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (actions['delete'] == true) {
        transaction.update(postRef, {
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': moderatorId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (actions['addWarning'] == true) {
        transaction.update(postRef, {
          'hasContentWarning': true,
          'contentWarning': actions['warningText'] ?? 'This content may be inappropriate',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } else if (targetType == 'comment') {
      // Handle comment moderation actions
      final postId = actions['postId'] as String;
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(targetId);
      
      if (actions['hide'] == true) {
        transaction.update(commentRef, {
          'isHidden': true,
          'hiddenAt': FieldValue.serverTimestamp(),
          'hiddenBy': moderatorId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (actions['delete'] == true) {
        transaction.update(commentRef, {
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': moderatorId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Apply user-level actions if specified
    if (actions['warnUser'] == true || actions['restrictUser'] == true || actions['banUser'] == true) {
      await _applyUserModerationActions(
        transaction: transaction,
        userId: actions['userId'] as String,
        actions: actions,
        moderatorId: moderatorId,
      );
    }
  }

  // Apply user-level moderation actions
  Future<void> _applyUserModerationActions({
    required Transaction transaction,
    required String userId,
    required Map<String, dynamic> actions,
    required String moderatorId,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    if (actions['warnUser'] == true) {
      transaction.update(userRef, {
        'warningCount': FieldValue.increment(1),
        'lastWarningAt': FieldValue.serverTimestamp(),
        'lastWarningReason': actions['warningReason'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    if (actions['restrictUser'] == true) {
      final restrictionEnd = DateTime.now().add(
        Duration(days: actions['restrictionDays'] as int? ?? 7),
      );
      
      transaction.update(userRef, {
        'isRestricted': true,
        'restrictionEnd': Timestamp.fromDate(restrictionEnd),
        'restrictionReason': actions['restrictionReason'],
        'restrictedBy': moderatorId,
        'restrictedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    if (actions['banUser'] == true) {
      transaction.update(userRef, {
        'isBanned': true,
        'banReason': actions['banReason'],
        'bannedBy': moderatorId,
        'bannedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get moderation statistics
  Future<ModerationStats> getModerationStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get reports count
      final reportsQuery = await _firestore
          .collection('content_reports')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final totalReports = reportsQuery.docs.length;
      final pendingReports = reportsQuery.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;
      final resolvedReports = reportsQuery.docs
          .where((doc) => doc.data()['status'] == 'resolved')
          .length;

      // Get moderation actions count
      final actionsQuery = await _firestore
          .collection('moderation_log')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final totalActions = actionsQuery.docs.length;
      final actionsByType = <String, int>{};
      
      for (final doc in actionsQuery.docs) {
        final action = doc.data()['action'] as String;
        actionsByType[action] = (actionsByType[action] ?? 0) + 1;
      }

      return ModerationStats(
        totalReports: totalReports,
        pendingReports: pendingReports,
        resolvedReports: resolvedReports,
        totalActions: totalActions,
        actionsByType: actionsByType,
        period: DateRange(start: start, end: end),
      );
    } catch (e) {
      debugPrint('Error getting moderation stats: $e');
      rethrow;
    }
  }

  // Get moderation history for a user
  Stream<List<ModerationAction>> getUserModerationHistory(String userId) {
    return _firestore
        .collection('moderation_log')
        .where('targetId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ModerationAction.fromFirestore(doc);
      }).toList();
    });
  }

  // Bulk moderation actions
  Future<void> bulkModerationAction({
    required List<String> targetIds,
    required String targetType,
    required String action,
    required String moderatorId,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final batch = _firestore.batch();
      
      for (final targetId in targetIds) {
        if (targetType == 'post') {
          final postRef = _firestore.collection('posts').doc(targetId);
          
          switch (action) {
            case 'hide':
              batch.update(postRef, {
                'isHidden': true,
                'hiddenAt': FieldValue.serverTimestamp(),
                'hiddenBy': moderatorId,
                'hiddenReason': reason,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              break;
            case 'delete':
              batch.update(postRef, {
                'isDeleted': true,
                'deletedAt': FieldValue.serverTimestamp(),
                'deletedBy': moderatorId,
                'deletionReason': reason,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              break;
            case 'approve':
              batch.update(postRef, {
                'isApproved': true,
                'approvedAt': FieldValue.serverTimestamp(),
                'approvedBy': moderatorId,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              break;
          }
        }
        
        // Log each action
        final logRef = _firestore.collection('moderation_log').doc();
        batch.set(logRef, {
          'action': 'bulk_$action',
          'targetType': targetType,
          'targetId': targetId,
          'moderatorId': moderatorId,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
          'details': {
            'bulkOperation': true,
            'totalTargets': targetIds.length,
            ...?additionalData,
          },
        });
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error performing bulk moderation action: $e');
      rethrow;
    }
  }

  // Log moderation actions for audit trail
  Future<void> _logModerationAction({
    required String action,
    required String targetType,
    required String targetId,
    required String moderatorId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _firestore.collection('moderation_log').add({
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'moderatorId': moderatorId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details ?? {},
      });
    } catch (e) {
      debugPrint('Error logging moderation action: $e');
    }
  }

  // Check if content needs pre-approval
  Future<bool> needsPreApproval(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final warningCount = userData['warningCount'] as int? ?? 0;
      final isRestricted = userData['isRestricted'] as bool? ?? false;
      
      // Require pre-approval for users with multiple warnings or restrictions
      return warningCount >= 3 || isRestricted;
    } catch (e) {
      debugPrint('Error checking pre-approval requirement: $e');
      return false;
    }
  }

  // Auto-moderate content using basic filters
  Future<ModerationResult> autoModerateContent(String content) async {
    try {
      // Basic inappropriate content detection
      final inappropriateWords = [
        // Add inappropriate words/phrases for your context
        'spam', 'scam', 'fake', 'fraud',
      ];
      
      final lowerContent = content.toLowerCase();
      final foundWords = inappropriateWords
          .where((word) => lowerContent.contains(word))
          .toList();
      
      if (foundWords.isNotEmpty) {
        return ModerationResult(
          needsReview: true,
          confidence: 0.8,
          reasons: ['Potentially inappropriate language detected'],
          suggestedActions: ['flag_for_review'],
          detectedWords: foundWords,
        );
      }
      
      // Check for excessive caps (potential spam)
      final capsCount = content.split('').where((char) => 
          char == char.toUpperCase() && char != char.toLowerCase()).length;
      final capsRatio = capsCount / content.length;
      
      if (capsRatio > 0.7 && content.length > 20) {
        return ModerationResult(
          needsReview: true,
          confidence: 0.6,
          reasons: ['Excessive use of capital letters'],
          suggestedActions: ['warn_user'],
        );
      }
      
      return ModerationResult(
        needsReview: false,
        confidence: 0.9,
        reasons: ['Content appears appropriate'],
        suggestedActions: [],
      );
    } catch (e) {
      debugPrint('Error in auto-moderation: $e');
      return ModerationResult(
        needsReview: true,
        confidence: 0.0,
        reasons: ['Error in auto-moderation'],
        suggestedActions: ['manual_review'],
      );
    }
  }
}

// Data models for moderation
class ContentReport {
  final String id;
  final String? postId;
  final String? commentId;
  final String reporterId;
  final String type;
  final String reason;
  final String? description;
  final List<String> evidenceUrls;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? resolution;
  final String? resolutionNotes;

  ContentReport({
    required this.id,
    this.postId,
    this.commentId,
    required this.reporterId,
    required this.type,
    required this.reason,
    this.description,
    required this.evidenceUrls,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.resolution,
    this.resolutionNotes,
  });

  factory ContentReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContentReport(
      id: doc.id,
      postId: data['postId'],
      commentId: data['commentId'],
      reporterId: data['reporterId'],
      type: data['type'],
      reason: data['reason'],
      description: data['description'],
      evidenceUrls: List<String>.from(data['evidenceUrls'] ?? []),
      status: data['status'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      reviewedBy: data['reviewedBy'],
      reviewedAt: data['reviewedAt'] != null 
          ? (data['reviewedAt'] as Timestamp).toDate() 
          : null,
      resolution: data['resolution'],
      resolutionNotes: data['resolutionNotes'],
    );
  }
}

class ModerationStats {
  final int totalReports;
  final int pendingReports;
  final int resolvedReports;
  final int totalActions;
  final Map<String, int> actionsByType;
  final DateRange period;

  ModerationStats({
    required this.totalReports,
    required this.pendingReports,
    required this.resolvedReports,
    required this.totalActions,
    required this.actionsByType,
    required this.period,
  });
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

class ModerationAction {
  final String id;
  final String action;
  final String targetType;
  final String targetId;
  final String moderatorId;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  ModerationAction({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.moderatorId,
    required this.timestamp,
    required this.details,
  });

  factory ModerationAction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ModerationAction(
      id: doc.id,
      action: data['action'],
      targetType: data['targetType'],
      targetId: data['targetId'],
      moderatorId: data['moderatorId'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      details: Map<String, dynamic>.from(data['details'] ?? {}),
    );
  }
}

class ModerationResult {
  final bool needsReview;
  final double confidence;
  final List<String> reasons;
  final List<String> suggestedActions;
  final List<String>? detectedWords;

  ModerationResult({
    required this.needsReview,
    required this.confidence,
    required this.reasons,
    required this.suggestedActions,
    this.detectedWords,
  });
}