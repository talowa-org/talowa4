// Transparency Service for TALOWA Admin Actions
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TransparencyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log administrative action for transparency
  static Future<void> logAction({
    required String action,
    required String adminId,
    required String adminName,
    required String targetType, // 'user', 'message', 'conversation', 'report'
    required String targetId,
    String? targetName,
    Map<String, dynamic>? details,
    String? reason,
  }) async {
    try {
      await _firestore.collection('transparency_logs').add({
        'action': action,
        'adminId': adminId,
        'adminName': adminName,
        'targetType': targetType,
        'targetId': targetId,
        'targetName': targetName,
        'reason': reason,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': 'hidden_for_privacy', // In production, could log admin IP
        'userAgent': 'admin_dashboard',
      });

      debugPrint('Transparency log created: $action on $targetType $targetId');
    } catch (e) {
      debugPrint('Error logging transparency action: $e');
      // Don't throw error as this shouldn't block admin actions
    }
  }

  /// Get transparency logs with filtering
  static Stream<List<TransparencyLog>> getTransparencyLogs({
    String? adminId,
    String? action,
    String? targetType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) {
    Query query = _firestore.collection('transparency_logs');

    // Apply filters
    if (adminId != null) {
      query = query.where('adminId', isEqualTo: adminId);
    }
    if (action != null) {
      query = query.where('action', isEqualTo: action);
    }
    if (targetType != null) {
      query = query.where('targetType', isEqualTo: targetType);
    }
    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransparencyLog.fromFirestore(doc))
            .toList());
  }

  /// Get transparency statistics
  static Future<TransparencyStats> getTransparencyStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get all logs in date range
      final snapshot = await _firestore
          .collection('transparency_logs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      // Count actions by type
      final Map<String, int> actionCounts = {};
      final Map<String, int> adminCounts = {};
      final Map<String, int> targetTypeCounts = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final action = data['action'] as String? ?? 'unknown';
        final adminId = data['adminId'] as String? ?? 'unknown';
        final targetType = data['targetType'] as String? ?? 'unknown';

        actionCounts[action] = (actionCounts[action] ?? 0) + 1;
        adminCounts[adminId] = (adminCounts[adminId] ?? 0) + 1;
        targetTypeCounts[targetType] = (targetTypeCounts[targetType] ?? 0) + 1;
      }

      return TransparencyStats(
        totalActions: snapshot.size,
        actionCounts: actionCounts,
        adminCounts: adminCounts,
        targetTypeCounts: targetTypeCounts,
        dateRange: DateRange(start: start, end: end),
      );
    } catch (e) {
      debugPrint('Error getting transparency stats: $e');
      return TransparencyStats(
        totalActions: 0,
        actionCounts: {},
        adminCounts: {},
        targetTypeCounts: {},
        dateRange: DateRange(
          start: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
          end: endDate ?? DateTime.now(),
        ),
      );
    }
  }

  /// Export transparency logs for audit
  static Future<Map<String, dynamic>> exportTransparencyLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? adminId,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      Query query = _firestore.collection('transparency_logs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (adminId != null) {
        query = query.where('adminId', isEqualTo: adminId);
      }

      final snapshot = await query.orderBy('timestamp', descending: true).get();

      final logs = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();

      return {
        'exportDate': DateTime.now().toIso8601String(),
        'dateRange': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        'filters': {
          'adminId': adminId,
        },
        'totalLogs': logs.length,
        'logs': logs,
      };
    } catch (e) {
      debugPrint('Error exporting transparency logs: $e');
      throw Exception('Failed to export transparency logs: $e');
    }
  }

  /// Common transparency actions
  static const String ACTION_USER_WARNED = 'user_warned';
  static const String ACTION_USER_RESTRICTED = 'user_restricted';
  static const String ACTION_USER_BANNED = 'user_banned';
  static const String ACTION_MESSAGE_REMOVED = 'message_removed';
  static const String ACTION_CONVERSATION_MUTED = 'conversation_muted';
  static const String ACTION_REPORT_REVIEWED = 'report_reviewed';
  static const String ACTION_REPORT_DISMISSED = 'report_dismissed';
  static const String ACTION_DATA_EXPORTED = 'data_exported';
  static const String ACTION_SETTINGS_CHANGED = 'settings_changed';
}

/// Transparency log model
class TransparencyLog {
  final String id;
  final String action;
  final String adminId;
  final String adminName;
  final String targetType;
  final String targetId;
  final String? targetName;
  final String? reason;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  TransparencyLog({
    required this.id,
    required this.action,
    required this.adminId,
    required this.adminName,
    required this.targetType,
    required this.targetId,
    this.targetName,
    this.reason,
    required this.details,
    required this.timestamp,
  });

  factory TransparencyLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return TransparencyLog(
      id: doc.id,
      action: data['action'] ?? '',
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? 'Unknown Admin',
      targetType: data['targetType'] ?? '',
      targetId: data['targetId'] ?? '',
      targetName: data['targetName'],
      reason: data['reason'],
      details: Map<String, dynamic>.from(data['details'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get actionDisplayName {
    switch (action) {
      case TransparencyService.ACTION_USER_WARNED:
        return 'User Warning Issued';
      case TransparencyService.ACTION_USER_RESTRICTED:
        return 'User Restricted';
      case TransparencyService.ACTION_USER_BANNED:
        return 'User Banned';
      case TransparencyService.ACTION_MESSAGE_REMOVED:
        return 'Message Removed';
      case TransparencyService.ACTION_CONVERSATION_MUTED:
        return 'Conversation Muted';
      case TransparencyService.ACTION_REPORT_REVIEWED:
        return 'Report Reviewed';
      case TransparencyService.ACTION_REPORT_DISMISSED:
        return 'Report Dismissed';
      case TransparencyService.ACTION_DATA_EXPORTED:
        return 'Data Exported';
      case TransparencyService.ACTION_SETTINGS_CHANGED:
        return 'Settings Changed';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }
}

/// Transparency statistics model
class TransparencyStats {
  final int totalActions;
  final Map<String, int> actionCounts;
  final Map<String, int> adminCounts;
  final Map<String, int> targetTypeCounts;
  final DateRange dateRange;

  TransparencyStats({
    required this.totalActions,
    required this.actionCounts,
    required this.adminCounts,
    required this.targetTypeCounts,
    required this.dateRange,
  });
}

/// Date range model
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  Duration get duration => end.difference(start);
}
