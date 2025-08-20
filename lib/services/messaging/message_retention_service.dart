import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../auth_service.dart';

/// Service for managing message retention policies and automatic cleanup
class MessageRetentionService {
  static final MessageRetentionService _instance = MessageRetentionService._internal();
  factory MessageRetentionService() => _instance;
  MessageRetentionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Collections
  static const String _retentionPoliciesCollection = 'retention_policies';
  static const String _cleanupJobsCollection = 'cleanup_jobs';

  // Default retention periods (in days)
  static const Map<String, int> defaultRetentionPeriods = {
    'regular_messages': 365,      // 1 year
    'group_messages': 180,        // 6 months
    'anonymous_messages': 90,     // 3 months
    'system_messages': 30,        // 1 month
    'call_history': 180,          // 6 months
    'missed_calls': 30,           // 1 month
    'media_files': 90,            // 3 months
    'voice_messages': 60,         // 2 months
  };

  /// Set retention policy for user or group
  Future<void> setRetentionPolicy({
    required String entityId,
    required String entityType, // 'user', 'group', 'conversation'
    required Map<String, int> retentionPeriods,
    bool autoCleanup = true,
  }) async {
    try {
      await _firestore
          .collection(_retentionPoliciesCollection)
          .doc(entityId)
          .set({
        'entityId': entityId,
        'entityType': entityType,
        'retentionPeriods': retentionPeriods,
        'autoCleanup': autoCleanup,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Retention policy set for $entityType: $entityId');
    } catch (e) {
      debugPrint('Error setting retention policy: $e');
      rethrow;
    }
  }

  /// Get retention policy for entity
  Future<Map<String, dynamic>?> getRetentionPolicy(String entityId) async {
    try {
      final doc = await _firestore
          .collection(_retentionPoliciesCollection)
          .doc(entityId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      
      // Return default policy if none exists
      return {
        'entityId': entityId,
        'entityType': 'user',
        'retentionPeriods': defaultRetentionPeriods,
        'autoCleanup': true,
      };
    } catch (e) {
      debugPrint('Error getting retention policy: $e');
      return null;
    }
  }

  /// Clean up expired messages for a user
  Future<void> cleanupExpiredMessages(String userId) async {
    try {
      debugPrint('Starting message cleanup for user: $userId');

      final policy = await getRetentionPolicy(userId);
      if (policy == null || policy['autoCleanup'] != true) {
        debugPrint('Auto cleanup disabled for user: $userId');
        return;
      }

      final retentionPeriods = Map<String, int>.from(
        policy['retentionPeriods'] ?? defaultRetentionPeriods
      );

      final cleanupJobId = _generateCleanupJobId();
      await _createCleanupJob(cleanupJobId, userId, retentionPeriods);

      int totalCleaned = 0;

      // Clean up regular messages
      final regularCleaned = await _cleanupMessagesByType(
        userId, 
        'text', 
        retentionPeriods['regular_messages'] ?? 365
      );
      totalCleaned += regularCleaned;

      // Clean up system messages
      final systemCleaned = await _cleanupMessagesByType(
        userId, 
        'system', 
        retentionPeriods['system_messages'] ?? 30
      );
      totalCleaned += systemCleaned;

      // Clean up voice messages
      final voiceCleaned = await _cleanupMessagesByType(
        userId, 
        'voice', 
        retentionPeriods['voice_messages'] ?? 60
      );
      totalCleaned += voiceCleaned;

      // Clean up call history
      final callsCleaned = await _cleanupCallHistory(
        userId, 
        retentionPeriods['call_history'] ?? 180
      );
      totalCleaned += callsCleaned;

      // Clean up missed calls
      final missedCleaned = await _cleanupMissedCalls(
        userId, 
        retentionPeriods['missed_calls'] ?? 30
      );
      totalCleaned += missedCleaned;

      // Clean up media files
      await _cleanupExpiredMediaFiles(
        userId, 
        retentionPeriods['media_files'] ?? 90
      );

      await _updateCleanupJob(cleanupJobId, 'completed', totalCleaned);

      debugPrint('Message cleanup completed for user: $userId, cleaned: $totalCleaned items');
    } catch (e) {
      debugPrint('Error cleaning up expired messages: $e');
      rethrow;
    }
  }

  /// Clean up expired messages for all users (batch operation)
  Future<void> cleanupExpiredMessagesForAllUsers() async {
    try {
      debugPrint('Starting global message cleanup');

      // Get all users with auto cleanup enabled
      final policiesSnapshot = await _firestore
          .collection(_retentionPoliciesCollection)
          .where('autoCleanup', isEqualTo: true)
          .get();

      final userIds = policiesSnapshot.docs.map((doc) => doc.id).toList();

      // Also include users without explicit policies (use defaults)
      final usersSnapshot = await _firestore
          .collection('users')
          .limit(1000) // Process in batches
          .get();

      for (final userDoc in usersSnapshot.docs) {
        if (!userIds.contains(userDoc.id)) {
          userIds.add(userDoc.id);
        }
      }

      debugPrint('Processing cleanup for ${userIds.length} users');

      // Process users in batches to avoid timeout
      const batchSize = 10;
      for (int i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.skip(i).take(batchSize).toList();
        
        final futures = batch.map((userId) => cleanupExpiredMessages(userId));
        await Future.wait(futures, eagerError: false);
        
        // Small delay between batches
        await Future.delayed(const Duration(seconds: 1));
      }

      debugPrint('Global message cleanup completed');
    } catch (e) {
      debugPrint('Error in global message cleanup: $e');
      rethrow;
    }
  }

  /// Clean up expired group messages
  Future<void> cleanupExpiredGroupMessages(String groupId) async {
    try {
      debugPrint('Starting group message cleanup: $groupId');

      final policy = await getRetentionPolicy(groupId);
      final retentionDays = policy?['retentionPeriods']?['group_messages'] ?? 
                           defaultRetentionPeriods['group_messages']!;

      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      // Get expired messages in batches
      int totalCleaned = 0;
      bool hasMore = true;

      while (hasMore) {
        final snapshot = await _firestore
            .collection('messages')
            .where('groupId', isEqualTo: groupId)
            .where('sentAt', isLessThan: cutoffTimestamp)
            .limit(500)
            .get();

        if (snapshot.docs.isEmpty) {
          hasMore = false;
          break;
        }

        final batch = _firestore.batch();
        
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        totalCleaned += snapshot.docs.length;

        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint('Group message cleanup completed: $groupId, cleaned: $totalCleaned messages');
    } catch (e) {
      debugPrint('Error cleaning up group messages: $e');
      rethrow;
    }
  }

  /// Get cleanup statistics for user
  Future<Map<String, dynamic>> getCleanupStatistics(String userId) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final cleanupJobs = await _firestore
          .collection(_cleanupJobsCollection)
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('createdAt', descending: true)
          .get();

      int totalItemsCleaned = 0;
      int successfulJobs = 0;
      int failedJobs = 0;
      DateTime? lastCleanup;

      for (final doc in cleanupJobs.docs) {
        final data = doc.data();
        totalItemsCleaned += (data['itemsCleaned'] as int? ?? 0);
        
        if (data['status'] == 'completed') {
          successfulJobs++;
        } else if (data['status'] == 'failed') {
          failedJobs++;
        }

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && (lastCleanup == null || createdAt.isAfter(lastCleanup))) {
          lastCleanup = createdAt;
        }
      }

      return {
        'totalItemsCleaned': totalItemsCleaned,
        'successfulJobs': successfulJobs,
        'failedJobs': failedJobs,
        'lastCleanup': lastCleanup?.toIso8601String(),
        'totalJobs': cleanupJobs.docs.length,
      };
    } catch (e) {
      debugPrint('Error getting cleanup statistics: $e');
      return {};
    }
  }

  /// Schedule automatic cleanup
  Future<void> scheduleAutomaticCleanup({
    String userId = 'global',
    Duration interval = const Duration(days: 7),
  }) async {
    try {
      await _firestore.collection('scheduled_cleanups').doc(userId).set({
        'userId': userId,
        'interval': interval.inMilliseconds,
        'nextRun': Timestamp.fromDate(DateTime.now().add(interval)),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Automatic cleanup scheduled for: $userId');
    } catch (e) {
      debugPrint('Error scheduling automatic cleanup: $e');
      rethrow;
    }
  }

  // Private helper methods

  Future<int> _cleanupMessagesByType(String userId, String messageType, int retentionDays) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      // Get user's conversations
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .get();

      final conversationIds = conversationsSnapshot.docs.map((doc) => doc.id).toList();

      int totalCleaned = 0;

      // Clean messages from each conversation
      for (final conversationId in conversationIds) {
        bool hasMore = true;
        
        while (hasMore) {
          final snapshot = await _firestore
              .collection('messages')
              .where('conversationId', isEqualTo: conversationId)
              .where('messageType', isEqualTo: messageType)
              .where('sentAt', isLessThan: cutoffTimestamp)
              .limit(500)
              .get();

          if (snapshot.docs.isEmpty) {
            hasMore = false;
            break;
          }

          final batch = _firestore.batch();
          
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }

          await batch.commit();
          totalCleaned += snapshot.docs.length;

          // Small delay between batches
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      return totalCleaned;
    } catch (e) {
      debugPrint('Error cleaning up messages by type: $e');
      return 0;
    }
  }

  Future<int> _cleanupCallHistory(String userId, int retentionDays) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch;

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('call_history')
          .where('startTime', isLessThan: cutoffTimestamp)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error cleaning up call history: $e');
      return 0;
    }
  }

  Future<int> _cleanupMissedCalls(String userId, int retentionDays) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch;

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('missed_calls')
          .where('timestamp', isLessThan: cutoffTimestamp)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error cleaning up missed calls: $e');
      return 0;
    }
  }

  Future<void> _cleanupExpiredMediaFiles(String userId, int retentionDays) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      // Get expired media messages
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .get();

      final conversationIds = conversationsSnapshot.docs.map((doc) => doc.id).toList();

      for (final conversationId in conversationIds) {
        final mediaMessages = await _firestore
            .collection('messages')
            .where('conversationId', isEqualTo: conversationId)
            .where('messageType', whereIn: ['image', 'document', 'voice'])
            .where('sentAt', isLessThan: cutoffTimestamp)
            .get();

        // Mark media files for deletion (actual file deletion would be handled by cloud function)
        final batch = _firestore.batch();
        
        for (final doc in mediaMessages.docs) {
          final data = doc.data();
          final mediaUrls = data['mediaUrls'] as List<dynamic>?;
          
          if (mediaUrls != null && mediaUrls.isNotEmpty) {
            // Add to media cleanup queue
            batch.set(
              _firestore.collection('media_cleanup_queue').doc(),
              {
                'mediaUrls': mediaUrls,
                'messageId': doc.id,
                'userId': userId,
                'scheduledAt': FieldValue.serverTimestamp(),
                'status': 'pending',
              }
            );
          }
        }

        if (mediaMessages.docs.isNotEmpty) {
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up expired media files: $e');
    }
  }

  Future<void> _createCleanupJob(String jobId, String userId, Map<String, int> retentionPeriods) async {
    await _firestore.collection(_cleanupJobsCollection).doc(jobId).set({
      'userId': userId,
      'status': 'started',
      'retentionPeriods': retentionPeriods,
      'itemsCleaned': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateCleanupJob(String jobId, String status, int itemsCleaned) async {
    await _firestore.collection(_cleanupJobsCollection).doc(jobId).update({
      'status': status,
      'itemsCleaned': itemsCleaned,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  String _generateCleanupJobId() {
    return 'cleanup_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }
}