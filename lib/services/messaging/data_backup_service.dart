import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/voice_call.dart';
import '../auth_service.dart';
import 'call_history_service.dart';
import 'messaging_service.dart';

/// Service for backing up and recovering messaging and call data
class DataBackupService {
  static final DataBackupService _instance = DataBackupService._internal();
  factory DataBackupService() => _instance;
  DataBackupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final MessagingService _messagingService = MessagingService();
  final CallHistoryService _callHistoryService = CallHistoryService();

  // Collections
  static const String _backupsCollection = 'user_backups';
  static const String _backupJobsCollection = 'backup_jobs';

  /// Create a full backup of user's messaging and call data
  Future<String> createFullBackup({
    bool includeMessages = true,
    bool includeCallHistory = true,
    bool includeConversations = true,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final backupId = _generateBackupId();
      final timestamp = DateTime.now();

      debugPrint('Starting full backup for user: $currentUserId');

      // Create backup job record
      await _createBackupJob(backupId, currentUserId, {
        'includeMessages': includeMessages,
        'includeCallHistory': includeCallHistory,
        'includeConversations': includeConversations,
        'metadata': metadata ?? {},
      });

      final backupData = <String, dynamic>{
        'backupId': backupId,
        'userId': currentUserId,
        'timestamp': timestamp.toIso8601String(),
        'version': '1.0',
        'metadata': metadata ?? {},
      };

      // Backup conversations
      if (includeConversations) {
        debugPrint('Backing up conversations...');
        final conversations = await _backupConversations(currentUserId);
        backupData['conversations'] = conversations;
        await _updateBackupProgress(backupId, 'conversations_completed');
      }

      // Backup messages
      if (includeMessages) {
        debugPrint('Backing up messages...');
        final messages = await _backupMessages(currentUserId);
        backupData['messages'] = messages;
        await _updateBackupProgress(backupId, 'messages_completed');
      }

      // Backup call history
      if (includeCallHistory) {
        debugPrint('Backing up call history...');
        final callHistory = await _backupCallHistory(currentUserId);
        backupData['callHistory'] = callHistory;
        await _updateBackupProgress(backupId, 'call_history_completed');
      }

      // Save backup to Firestore
      await _firestore
          .collection(_backupsCollection)
          .doc(backupId)
          .set({
        'userId': currentUserId,
        'backupData': backupData,
        'createdAt': FieldValue.serverTimestamp(),
        'size': _calculateBackupSize(backupData),
        'status': 'completed',
        'expiresAt': Timestamp.fromDate(
          timestamp.add(const Duration(days: 90)), // 90-day retention
        ),
      });

      await _updateBackupProgress(backupId, 'completed');

      debugPrint('Full backup completed: $backupId');
      return backupId;
    } catch (e) {
      debugPrint('Error creating full backup: $e');
      rethrow;
    }
  }

  /// Export user data for download
  Future<Map<String, dynamic>> exportUserData({
    bool includeMessages = true,
    bool includeCallHistory = true,
    bool includeConversations = true,
    String format = 'json',
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('Exporting user data for: $currentUserId');

      final exportData = <String, dynamic>{
        'exportId': _generateBackupId(),
        'userId': currentUserId,
        'exportedAt': DateTime.now().toIso8601String(),
        'format': format,
        'dataTypes': {
          'messages': includeMessages,
          'callHistory': includeCallHistory,
          'conversations': includeConversations,
        },
      };

      // Export conversations
      if (includeConversations) {
        final conversations = await _exportConversations(currentUserId);
        exportData['conversations'] = conversations;
      }

      // Export messages
      if (includeMessages) {
        final messages = await _exportMessages(currentUserId);
        exportData['messages'] = messages;
      }

      // Export call history
      if (includeCallHistory) {
        final callHistory = await _exportCallHistory(currentUserId);
        exportData['callHistory'] = callHistory;
      }

      // Log export activity
      await _logExportActivity(currentUserId, exportData);

      debugPrint('User data export completed');
      return exportData;
    } catch (e) {
      debugPrint('Error exporting user data: $e');
      rethrow;
    }
  }

  /// Save exported data to local file
  Future<String> saveExportToFile(Map<String, dynamic> exportData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportId = exportData['exportId'] as String;
      final fileName = 'talowa_export_$exportId.json';
      final file = File('${directory.path}/$fileName');

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      await file.writeAsString(jsonString);

      debugPrint('Export saved to file: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error saving export to file: $e');
      rethrow;
    }
  }

  /// Get user's backup history
  Future<List<Map<String, dynamic>>> getBackupHistory({
    int limit = 20,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return [];

      final snapshot = await _firestore
          .collection(_backupsCollection)
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'backupId': doc.id,
          'createdAt': data['createdAt'],
          'size': data['size'],
          'status': data['status'],
          'expiresAt': data['expiresAt'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting backup history: $e');
      return [];
    }
  }

  /// Restore data from backup
  Future<void> restoreFromBackup(String backupId) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('Starting restore from backup: $backupId');

      // Get backup data
      final backupDoc = await _firestore
          .collection(_backupsCollection)
          .doc(backupId)
          .get();

      if (!backupDoc.exists) {
        throw Exception('Backup not found');
      }

      final backupData = backupDoc.data()!['backupData'] as Map<String, dynamic>;

      // Verify backup belongs to current user
      if (backupData['userId'] != currentUserId) {
        throw Exception('Unauthorized access to backup');
      }

      // Restore conversations
      if (backupData.containsKey('conversations')) {
        await _restoreConversations(backupData['conversations']);
      }

      // Restore messages
      if (backupData.containsKey('messages')) {
        await _restoreMessages(backupData['messages']);
      }

      // Restore call history
      if (backupData.containsKey('callHistory')) {
        await _restoreCallHistory(backupData['callHistory']);
      }

      debugPrint('Restore completed from backup: $backupId');
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      rethrow;
    }
  }

  /// Delete old backups based on retention policy
  Future<void> cleanupExpiredBackups() async {
    try {
      final now = Timestamp.now();
      
      final expiredBackups = await _firestore
          .collection(_backupsCollection)
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in expiredBackups.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      debugPrint('Cleaned up ${expiredBackups.docs.length} expired backups');
    } catch (e) {
      debugPrint('Error cleaning up expired backups: $e');
    }
  }

  /// Get backup storage usage for user
  Future<Map<String, dynamic>> getStorageUsage() async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return {};

      final snapshot = await _firestore
          .collection(_backupsCollection)
          .where('userId', isEqualTo: currentUserId)
          .get();

      int totalSize = 0;
      int backupCount = snapshot.docs.length;
      DateTime? oldestBackup;
      DateTime? newestBackup;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalSize += (data['size'] as int? ?? 0);
        
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          if (oldestBackup == null || createdAt.isBefore(oldestBackup)) {
            oldestBackup = createdAt;
          }
          if (newestBackup == null || createdAt.isAfter(newestBackup)) {
            newestBackup = createdAt;
          }
        }
      }

      return {
        'totalSize': totalSize,
        'backupCount': backupCount,
        'oldestBackup': oldestBackup?.toIso8601String(),
        'newestBackup': newestBackup?.toIso8601String(),
        'averageSize': backupCount > 0 ? (totalSize / backupCount).round() : 0,
      };
    } catch (e) {
      debugPrint('Error getting storage usage: $e');
      return {};
    }
  }

  // Private helper methods

  Future<List<Map<String, dynamic>>> _backupConversations(String userId) async {
    try {
      final conversations = <Map<String, dynamic>>[];
      
      final snapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .get();

      for (final doc in snapshot.docs) {
        conversations.add({
          'id': doc.id,
          'data': doc.data(),
        });
      }

      return conversations;
    } catch (e) {
      debugPrint('Error backing up conversations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _backupMessages(String userId) async {
    try {
      final messages = <Map<String, dynamic>>[];
      
      // Get user's conversations first
      final conversationSnapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .get();

      final conversationIds = conversationSnapshot.docs.map((doc) => doc.id).toList();

      // Backup messages from all conversations
      for (final conversationId in conversationIds) {
        final messageSnapshot = await _firestore
            .collection('messages')
            .where('conversationId', isEqualTo: conversationId)
            .get();

        for (final doc in messageSnapshot.docs) {
          messages.add({
            'id': doc.id,
            'data': doc.data(),
          });
        }
      }

      return messages;
    } catch (e) {
      debugPrint('Error backing up messages: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _backupCallHistory(String userId) async {
    try {
      final callHistory = <Map<String, dynamic>>[];
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('call_history')
          .get();

      for (final doc in snapshot.docs) {
        callHistory.add({
          'id': doc.id,
          'data': doc.data(),
        });
      }

      return callHistory;
    } catch (e) {
      debugPrint('Error backing up call history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _exportConversations(String userId) async {
    final conversations = await _backupConversations(userId);
    
    // Transform for export format
    return conversations.map((conv) {
      final data = conv['data'] as Map<String, dynamic>;
      return {
        'id': conv['id'],
        'name': data['name'],
        'type': data['type'],
        'createdAt': data['createdAt']?.toDate()?.toIso8601String(),
        'lastMessageAt': data['lastMessageAt']?.toDate()?.toIso8601String(),
        'participantCount': (data['participantIds'] as List?)?.length ?? 0,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _exportMessages(String userId) async {
    final messages = await _backupMessages(userId);
    
    // Transform for export format
    return messages.map((msg) {
      final data = msg['data'] as Map<String, dynamic>;
      return {
        'id': msg['id'],
        'conversationId': data['conversationId'],
        'content': data['content'],
        'messageType': data['messageType'],
        'sentAt': data['sentAt']?.toDate()?.toIso8601String(),
        'senderName': data['senderName'],
        'isDeleted': data['isDeleted'] ?? false,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _exportCallHistory(String userId) async {
    final callHistory = await _backupCallHistory(userId);
    
    // Transform for export format
    return callHistory.map((call) {
      final data = call['data'] as Map<String, dynamic>;
      return {
        'id': call['id'],
        'participantName': data['participantName'],
        'callType': data['callType'],
        'status': data['status'],
        'startTime': data['startTime'],
        'duration': data['duration'],
        'isIncoming': data['isIncoming'],
      };
    }).toList();
  }

  Future<void> _restoreConversations(List<dynamic> conversations) async {
    final batch = _firestore.batch();
    
    for (final conv in conversations) {
      final convData = conv as Map<String, dynamic>;
      final docRef = _firestore.collection('conversations').doc(convData['id']);
      batch.set(docRef, convData['data']);
    }
    
    await batch.commit();
  }

  Future<void> _restoreMessages(List<dynamic> messages) async {
    final batch = _firestore.batch();
    int batchCount = 0;
    
    for (final msg in messages) {
      final msgData = msg as Map<String, dynamic>;
      final docRef = _firestore.collection('messages').doc(msgData['id']);
      batch.set(docRef, msgData['data']);
      
      batchCount++;
      if (batchCount >= 500) { // Firestore batch limit
        await batch.commit();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      await batch.commit();
    }
  }

  Future<void> _restoreCallHistory(List<dynamic> callHistory) async {
    final currentUserId = await _authService.getCurrentUserId();
    if (currentUserId == null) return;

    final batch = _firestore.batch();
    
    for (final call in callHistory) {
      final callData = call as Map<String, dynamic>;
      final docRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('call_history')
          .doc(callData['id']);
      batch.set(docRef, callData['data']);
    }
    
    await batch.commit();
  }

  Future<void> _createBackupJob(String backupId, String userId, Map<String, dynamic> config) async {
    await _firestore.collection(_backupJobsCollection).doc(backupId).set({
      'userId': userId,
      'status': 'started',
      'config': config,
      'progress': 'initializing',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateBackupProgress(String backupId, String progress) async {
    await _firestore.collection(_backupJobsCollection).doc(backupId).update({
      'progress': progress,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _logExportActivity(String userId, Map<String, dynamic> exportData) async {
    await _firestore.collection('export_logs').add({
      'userId': userId,
      'exportId': exportData['exportId'],
      'dataTypes': exportData['dataTypes'],
      'timestamp': FieldValue.serverTimestamp(),
      'size': _calculateBackupSize(exportData),
    });
  }

  String _generateBackupId() {
    return 'backup_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }

  int _calculateBackupSize(Map<String, dynamic> data) {
    try {
      final jsonString = jsonEncode(data);
      return jsonString.length;
    } catch (e) {
      return 0;
    }
  }
}