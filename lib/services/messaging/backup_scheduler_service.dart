import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import 'data_backup_service.dart';
import 'message_retention_service.dart';

/// Service for scheduling and managing automated backups
class BackupSchedulerService {
  static final BackupSchedulerService _instance = BackupSchedulerService._internal();
  factory BackupSchedulerService() => _instance;
  BackupSchedulerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DataBackupService _backupService = DataBackupService();
  final MessageRetentionService _retentionService = MessageRetentionService();
  final AuthService _authService = AuthService();

  // Collections
  static const String _schedulesCollection = 'backup_schedules';
  static const String _scheduledJobsCollection = 'scheduled_backup_jobs';

  Timer? _schedulerTimer;
  bool _isRunning = false;

  /// Create backup schedule
  Future<String> createBackupSchedule({
    required String scheduleName,
    required Duration interval,
    required List<String> dataTypes,
    required Map<String, dynamic> backupConfig,
    bool isActive = true,
    DateTime? startTime,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final scheduleId = _generateScheduleId();
      final nextRun = startTime ?? DateTime.now().add(interval);

      await _firestore.collection(_schedulesCollection).doc(scheduleId).set({
        'scheduleId': scheduleId,
        'scheduleName': scheduleName,
        'userId': currentUserId,
        'interval': interval.inMilliseconds,
        'dataTypes': dataTypes,
        'backupConfig': backupConfig,
        'isActive': isActive,
        'nextRun': Timestamp.fromDate(nextRun),
        'lastRun': null,
        'runCount': 0,
        'successCount': 0,
        'failureCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Backup schedule created: $scheduleId');
      
      // Start scheduler if not already running
      if (!_isRunning) {
        startScheduler();
      }

      return scheduleId;
    } catch (e) {
      debugPrint('Error creating backup schedule: $e');
      rethrow;
    }
  }

  /// Update backup schedule
  Future<void> updateBackupSchedule({
    required String scheduleId,
    String? scheduleName,
    Duration? interval,
    List<String>? dataTypes,
    Map<String, dynamic>? backupConfig,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (scheduleName != null) updates['scheduleName'] = scheduleName;
      if (interval != null) updates['interval'] = interval.inMilliseconds;
      if (dataTypes != null) updates['dataTypes'] = dataTypes;
      if (backupConfig != null) updates['backupConfig'] = backupConfig;
      if (isActive != null) updates['isActive'] = isActive;

      // Update next run time if interval changed
      if (interval != null) {
        final scheduleDoc = await _firestore
            .collection(_schedulesCollection)
            .doc(scheduleId)
            .get();
        
        if (scheduleDoc.exists) {
          final lastRun = (scheduleDoc.data()!['lastRun'] as Timestamp?)?.toDate();
          final nextRun = (lastRun ?? DateTime.now()).add(interval);
          updates['nextRun'] = Timestamp.fromDate(nextRun);
        }
      }

      await _firestore
          .collection(_schedulesCollection)
          .doc(scheduleId)
          .update(updates);

      debugPrint('Backup schedule updated: $scheduleId');
    } catch (e) {
      debugPrint('Error updating backup schedule: $e');
      rethrow;
    }
  }

  /// Delete backup schedule
  Future<void> deleteBackupSchedule(String scheduleId) async {
    try {
      await _firestore
          .collection(_schedulesCollection)
          .doc(scheduleId)
          .delete();

      debugPrint('Backup schedule deleted: $scheduleId');
    } catch (e) {
      debugPrint('Error deleting backup schedule: $e');
      rethrow;
    }
  }

  /// Get user's backup schedules
  Future<List<Map<String, dynamic>>> getBackupSchedules() async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return [];

      final snapshot = await _firestore
          .collection(_schedulesCollection)
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'scheduleId': doc.id,
          'scheduleName': data['scheduleName'],
          'interval': Duration(milliseconds: data['interval']),
          'dataTypes': List<String>.from(data['dataTypes']),
          'isActive': data['isActive'],
          'nextRun': (data['nextRun'] as Timestamp?)?.toDate(),
          'lastRun': (data['lastRun'] as Timestamp?)?.toDate(),
          'runCount': data['runCount'],
          'successCount': data['successCount'],
          'failureCount': data['failureCount'],
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting backup schedules: $e');
      return [];
    }
  }

  /// Start the backup scheduler
  void startScheduler() {
    if (_isRunning) return;

    _isRunning = true;
    debugPrint('Starting backup scheduler');

    // Check for due backups every minute
    _schedulerTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndExecuteDueBackups();
    });
  }

  /// Stop the backup scheduler
  void stopScheduler() {
    if (!_isRunning) return;

    _isRunning = false;
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    
    debugPrint('Backup scheduler stopped');
  }

  /// Execute backup immediately for a schedule
  Future<String> executeBackupNow(String scheduleId) async {
    try {
      final scheduleDoc = await _firestore
          .collection(_schedulesCollection)
          .doc(scheduleId)
          .get();

      if (!scheduleDoc.exists) {
        throw Exception('Backup schedule not found: $scheduleId');
      }

      final scheduleData = scheduleDoc.data()!;
      
      // Verify user owns this schedule
      final currentUserId = await _authService.getCurrentUserId();
      if (scheduleData['userId'] != currentUserId) {
        throw Exception('Unauthorized access to backup schedule');
      }

      return await _executeScheduledBackup(scheduleId, scheduleData);
    } catch (e) {
      debugPrint('Error executing backup now: $e');
      rethrow;
    }
  }

  /// Get backup schedule statistics
  Future<Map<String, dynamic>> getScheduleStatistics(String scheduleId) async {
    try {
      final scheduleDoc = await _firestore
          .collection(_schedulesCollection)
          .doc(scheduleId)
          .get();

      if (!scheduleDoc.exists) {
        return {};
      }

      final data = scheduleDoc.data()!;
      
      // Get recent job history
      final jobsSnapshot = await _firestore
          .collection(_scheduledJobsCollection)
          .where('scheduleId', isEqualTo: scheduleId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final recentJobs = jobsSnapshot.docs.map((doc) {
        final jobData = doc.data();
        return {
          'jobId': doc.id,
          'status': jobData['status'],
          'createdAt': (jobData['createdAt'] as Timestamp?)?.toDate(),
          'completedAt': (jobData['completedAt'] as Timestamp?)?.toDate(),
          'backupSize': jobData['backupSize'],
          'error': jobData['error'],
        };
      }).toList();

      return {
        'scheduleId': scheduleId,
        'scheduleName': data['scheduleName'],
        'runCount': data['runCount'],
        'successCount': data['successCount'],
        'failureCount': data['failureCount'],
        'successRate': data['runCount'] > 0 
            ? (data['successCount'] / data['runCount'] * 100).round()
            : 0,
        'lastRun': (data['lastRun'] as Timestamp?)?.toDate(),
        'nextRun': (data['nextRun'] as Timestamp?)?.toDate(),
        'recentJobs': recentJobs,
      };
    } catch (e) {
      debugPrint('Error getting schedule statistics: $e');
      return {};
    }
  }

  /// Create default backup schedules for new users
  Future<void> createDefaultSchedules(String userId) async {
    try {
      // Daily backup for messages and conversations
      await _createDefaultSchedule(
        userId: userId,
        name: 'Daily Backup',
        interval: const Duration(days: 1),
        dataTypes: ['messages', 'conversations'],
        config: {
          'includeMessages': true,
          'includeConversations': true,
          'includeCallHistory': false,
          'retentionDays': 30,
        },
      );

      // Weekly backup for call history
      await _createDefaultSchedule(
        userId: userId,
        name: 'Weekly Call History Backup',
        interval: const Duration(days: 7),
        dataTypes: ['call_history'],
        config: {
          'includeMessages': false,
          'includeConversations': false,
          'includeCallHistory': true,
          'retentionDays': 90,
        },
      );

      debugPrint('Default backup schedules created for user: $userId');
    } catch (e) {
      debugPrint('Error creating default schedules: $e');
    }
  }

  /// Get global backup statistics (admin only)
  Future<Map<String, dynamic>> getGlobalBackupStatistics() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      const last7Days = Duration(days: 7);
      const last30Days = Duration(days: 30);

      // Get recent backup jobs
      final recentJobsSnapshot = await _firestore
          .collection(_scheduledJobsCollection)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();

      int totalJobs = recentJobsSnapshot.docs.length;
      int successfulJobs = 0;
      int failedJobs = 0;
      int totalBackupSize = 0;

      for (final doc in recentJobsSnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'completed') {
          successfulJobs++;
        } else if (data['status'] == 'failed') {
          failedJobs++;
        }
        totalBackupSize += (data['backupSize'] as int? ?? 0);
      }

      // Get active schedules count
      final activeSchedulesSnapshot = await _firestore
          .collection(_schedulesCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return {
        'totalActiveSchedules': activeSchedulesSnapshot.docs.length,
        'last24Hours': {
          'totalJobs': totalJobs,
          'successfulJobs': successfulJobs,
          'failedJobs': failedJobs,
          'successRate': totalJobs > 0 ? (successfulJobs / totalJobs * 100).round() : 0,
          'totalBackupSize': totalBackupSize,
        },
        'systemHealth': totalJobs > 0 && (successfulJobs / totalJobs) > 0.9 ? 'healthy' : 'warning',
        'timestamp': now.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting global backup statistics: $e');
      return {};
    }
  }

  // Private helper methods

  Future<void> _checkAndExecuteDueBackups() async {
    try {
      final now = Timestamp.now();
      
      // Get all active schedules that are due
      final dueSchedulesSnapshot = await _firestore
          .collection(_schedulesCollection)
          .where('isActive', isEqualTo: true)
          .where('nextRun', isLessThanOrEqualTo: now)
          .get();

      debugPrint('Found ${dueSchedulesSnapshot.docs.length} due backup schedules');

      // Execute each due backup
      for (final doc in dueSchedulesSnapshot.docs) {
        try {
          await _executeScheduledBackup(doc.id, doc.data());
        } catch (e) {
          debugPrint('Error executing scheduled backup ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking due backups: $e');
    }
  }

  Future<String> _executeScheduledBackup(String scheduleId, Map<String, dynamic> scheduleData) async {
    try {
      debugPrint('Executing scheduled backup: $scheduleId');

      final jobId = _generateJobId();
      
      // Create job record
      await _firestore.collection(_scheduledJobsCollection).doc(jobId).set({
        'jobId': jobId,
        'scheduleId': scheduleId,
        'userId': scheduleData['userId'],
        'status': 'started',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Execute backup
      final backupConfig = Map<String, dynamic>.from(scheduleData['backupConfig']);
      final backupId = await _backupService.createFullBackup(
        includeMessages: backupConfig['includeMessages'] ?? true,
        includeCallHistory: backupConfig['includeCallHistory'] ?? true,
        includeConversations: backupConfig['includeConversations'] ?? true,
        metadata: {
          'scheduledBackup': true,
          'scheduleId': scheduleId,
          'jobId': jobId,
        },
      );

      // Get backup size
      final backupDoc = await _firestore
          .collection('user_backups')
          .doc(backupId)
          .get();
      
      final backupSize = backupDoc.exists ? (backupDoc.data()!['size'] as int? ?? 0) : 0;

      // Update job record
      await _firestore.collection(_scheduledJobsCollection).doc(jobId).update({
        'status': 'completed',
        'backupId': backupId,
        'backupSize': backupSize,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update schedule record
      final interval = Duration(milliseconds: scheduleData['interval']);
      final nextRun = DateTime.now().add(interval);
      
      await _firestore.collection(_schedulesCollection).doc(scheduleId).update({
        'lastRun': FieldValue.serverTimestamp(),
        'nextRun': Timestamp.fromDate(nextRun),
        'runCount': FieldValue.increment(1),
        'successCount': FieldValue.increment(1),
      });

      debugPrint('Scheduled backup completed: $scheduleId -> $backupId');
      return backupId;
    } catch (e) {
      debugPrint('Error executing scheduled backup: $e');
      
      // Update job record with error
      final jobId = _generateJobId();
      await _firestore.collection(_scheduledJobsCollection).doc(jobId).update({
        'status': 'failed',
        'error': e.toString(),
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update schedule failure count
      await _firestore.collection(_schedulesCollection).doc(scheduleId).update({
        'runCount': FieldValue.increment(1),
        'failureCount': FieldValue.increment(1),
      });

      rethrow;
    }
  }

  Future<void> _createDefaultSchedule({
    required String userId,
    required String name,
    required Duration interval,
    required List<String> dataTypes,
    required Map<String, dynamic> config,
  }) async {
    final scheduleId = _generateScheduleId();
    final nextRun = DateTime.now().add(interval);

    await _firestore.collection(_schedulesCollection).doc(scheduleId).set({
      'scheduleId': scheduleId,
      'scheduleName': name,
      'userId': userId,
      'interval': interval.inMilliseconds,
      'dataTypes': dataTypes,
      'backupConfig': config,
      'isActive': true,
      'nextRun': Timestamp.fromDate(nextRun),
      'lastRun': null,
      'runCount': 0,
      'successCount': 0,
      'failureCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDefault': true,
    });
  }

  String _generateScheduleId() {
    return 'schedule_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateJobId() {
    return 'job_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }

  /// Dispose resources
  void dispose() {
    stopScheduler();
  }
}
