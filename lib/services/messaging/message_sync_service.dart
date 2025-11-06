// Message Sync Service for TALOWA
// Implements Task 8: Create offline messaging and synchronization - Sync Mechanism
// Reference: in-app-communication/requirements.md - Requirements 1.2, 8.1, 8.2, 8.3

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../auth_service.dart';
import 'messaging_service.dart';
import 'offline_messaging_service.dart';
import 'message_compression_service.dart';

class MessageSyncService {
  static final MessageSyncService _instance = MessageSyncService._internal();
  factory MessageSyncService() => _instance;
  MessageSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessagingService _messagingService = MessagingService();
  final OfflineMessagingService _offlineService = OfflineMessagingService();
  final MessageCompressionService _compressionService = MessageCompressionService();
  
  final StreamController<SyncProgress> _syncProgressController = 
      StreamController<SyncProgress>.broadcast();
  final StreamController<SyncStatus> _syncStatusController = 
      StreamController<SyncStatus>.broadcast();
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isOnline = false;
  
  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 5);
  static const int _maxMessagesPerSync = 100;
  static const int _maxConversationsPerSync = 20;
  static const String _lastSyncTimeKey = 'last_message_sync_time';
  static const String _syncConfigKey = 'message_sync_config';
  
  // Getters for streams
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Initialize the message sync service
  Future<void> initialize() async {
    try {
      debugPrint('Initializing Message Sync Service');
      
      await _offlineService.initialize();
      await _startConnectivityMonitoring();
      await _schedulePeriodicSync();
      
      debugPrint('Message Sync Service initialized');
    } catch (e) {
      debugPrint('Error initializing message sync service: $e');
      rethrow;
    }
  }

  /// Perform full synchronization
  Future<SyncResult> performFullSync() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncType: SyncType.full,
      );
    }

    try {
      _isSyncing = true;
      _syncStatusController.add(SyncStatus.syncing);
      
      debugPrint('Starting full message sync');
      
      final startTime = DateTime.now();
      int downloadedMessages = 0;
      int updatedConversations = 0;
      final errors = <String>[];

      // Phase 1: Download missed messages
      _syncProgressController.add(SyncProgress(
        phase: SyncPhase.downloadingMessages,
        progress: 0.1,
        message: 'Downloading missed messages...',
      ));

      final downloadResult = await _downloadMissedMessages();
      downloadedMessages = downloadResult.downloadedCount;
      errors.addAll(downloadResult.errors);

      // Phase 2: Update conversation metadata
      _syncProgressController.add(SyncProgress(
        phase: SyncPhase.updatingConversations,
        progress: 0.5,
        message: 'Updating conversations...',
      ));

      final conversationResult = await _syncConversationMetadata();
      updatedConversations = conversationResult.updatedCount;
      errors.addAll(conversationResult.errors);

      // Phase 3: Resolve any conflicts
      _syncProgressController.add(SyncProgress(
        phase: SyncPhase.resolvingConflicts,
        progress: 0.8,
        message: 'Resolving conflicts...',
      ));

      final conflictResult = await _resolveMessageConflicts();
      errors.addAll(conflictResult.errors);

      // Phase 4: Update sync timestamp
      _syncProgressController.add(SyncProgress(
        phase: SyncPhase.finalizing,
        progress: 0.9,
        message: 'Finalizing sync...',
      ));

      await _updateLastSyncTime(DateTime.now());

      _syncProgressController.add(SyncProgress(
        phase: SyncPhase.completed,
        progress: 1.0,
        message: 'Sync completed successfully',
      ));

      final duration = DateTime.now().difference(startTime);
      final result = SyncResult(
        success: errors.isEmpty,
        message: 'Downloaded $downloadedMessages messages, updated $updatedConversations conversations',
        syncType: SyncType.full,
        downloadedMessages: downloadedMessages,
        updatedConversations: updatedConversations,
        duration: duration,
        errors: errors,
      );

      _syncStatusController.add(
        errors.isEmpty ? SyncStatus.completed : SyncStatus.completedWithErrors
      );

      debugPrint('Full sync completed: ${result.message}');
      return result;
    } catch (e) {
      debugPrint('Error during full sync: $e');
      _syncStatusController.add(SyncStatus.failed);
      return SyncResult(
        success: false,
        message: e.toString(),
        syncType: SyncType.full,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Perform incremental synchronization
  Future<SyncResult> performIncrementalSync() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncType: SyncType.incremental,
      );
    }

    try {
      _isSyncing = true;
      _syncStatusController.add(SyncStatus.syncing);
      
      debugPrint('Starting incremental message sync');
      
      final lastSyncTime = await _getLastSyncTime();
      if (lastSyncTime == null) {
        // No previous sync, perform full sync
        return await performFullSync();
      }

      final startTime = DateTime.now();
      int downloadedMessages = 0;
      final errors = <String>[];

      // Download only messages newer than last sync
      final downloadResult = await _downloadRecentMessages(lastSyncTime);
      downloadedMessages = downloadResult.downloadedCount;
      errors.addAll(downloadResult.errors);

      // Update sync timestamp
      await _updateLastSyncTime(DateTime.now());

      final duration = DateTime.now().difference(startTime);
      final result = SyncResult(
        success: errors.isEmpty,
        message: 'Downloaded $downloadedMessages new messages',
        syncType: SyncType.incremental,
        downloadedMessages: downloadedMessages,
        duration: duration,
        errors: errors,
      );

      _syncStatusController.add(
        errors.isEmpty ? SyncStatus.completed : SyncStatus.completedWithErrors
      );

      debugPrint('Incremental sync completed: ${result.message}');
      return result;
    } catch (e) {
      debugPrint('Error during incremental sync: $e');
      _syncStatusController.add(SyncStatus.failed);
      return SyncResult(
        success: false,
        message: e.toString(),
        syncType: SyncType.incremental,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Download missed messages since last sync
  Future<DownloadResult> _downloadMissedMessages() async {
    try {
      final lastSyncTime = await _getLastSyncTime();
      final cutoffTime = lastSyncTime ?? DateTime.now().subtract(const Duration(days: 7));
      
      return await _downloadRecentMessages(cutoffTime);
    } catch (e) {
      debugPrint('Error downloading missed messages: $e');
      return DownloadResult(
        downloadedCount: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Download recent messages since a specific time
  Future<DownloadResult> _downloadRecentMessages(DateTime since) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      int downloadedCount = 0;
      final errors = <String>[];

      // Get user's conversations
      final conversationsStream = _messagingService.getUserConversations();
      final conversations = await conversationsStream.first;
      
      final limitedConversations = conversations.take(_maxConversationsPerSync).toList();

      for (int i = 0; i < limitedConversations.length; i++) {
        final conversation = limitedConversations[i];
        
        try {
          // Update progress
          final progress = 0.1 + (0.4 * (i + 1) / limitedConversations.length);
          _syncProgressController.add(SyncProgress(
            phase: SyncPhase.downloadingMessages,
            progress: progress,
            message: 'Downloading messages from ${conversation.name}...',
          ));

          final messages = await _downloadConversationMessages(conversation.id, since);
          
          for (final message in messages) {
            await _offlineService.storeMessageOffline(message);
            downloadedCount++;
          }
        } catch (e) {
          errors.add('Conversation ${conversation.id}: $e');
        }
      }

      return DownloadResult(
        downloadedCount: downloadedCount,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error downloading recent messages: $e');
      return DownloadResult(
        downloadedCount: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Download messages for a specific conversation
  Future<List<MessageModel>> _downloadConversationMessages(
    String conversationId,
    DateTime since,
  ) async {
    try {
      // Query messages from Firestore directly for better control
      final query = _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('sentAt', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('sentAt', descending: true)
          .limit(_maxMessagesPerSync);

      final snapshot = await query.get();
      
      final messages = <MessageModel>[];
      for (final doc in snapshot.docs) {
        try {
          final message = MessageModel.fromFirestore(doc);
          messages.add(message);
        } catch (e) {
          debugPrint('Error parsing message ${doc.id}: $e');
        }
      }

      return messages;
    } catch (e) {
      debugPrint('Error downloading conversation messages: $e');
      return [];
    }
  }

  /// Sync conversation metadata
  Future<ConversationSyncResult> _syncConversationMetadata() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      int updatedCount = 0;
      final errors = <String>[];

      // Get conversations from Firestore
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUser.uid)
          .get();

      for (final doc in conversationsSnapshot.docs) {
        try {
          final conversation = ConversationModel.fromFirestore(doc);
          
          // Store conversation metadata offline
          await _storeConversationOffline(conversation);
          updatedCount++;
        } catch (e) {
          errors.add('Conversation ${doc.id}: $e');
        }
      }

      return ConversationSyncResult(
        updatedCount: updatedCount,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error syncing conversation metadata: $e');
      return ConversationSyncResult(
        updatedCount: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Store conversation metadata offline
  Future<void> _storeConversationOffline(ConversationModel conversation) async {
    try {
      final db = await _offlineService.database;
      
      await db.insertOrReplace('offline_conversations', {
        'id': conversation.id,
        'name': conversation.name,
        'type': conversation.type.toString(),
        'participant_ids': jsonEncode(conversation.participantIds),
        'created_by': conversation.createdBy,
        'created_at': conversation.createdAt.millisecondsSinceEpoch,
        'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
        'last_message': conversation.lastMessage,
        'last_message_at': conversation.lastMessageAt.millisecondsSinceEpoch,
        'last_message_sender_id': conversation.lastMessageSenderId,
        'unread_counts': jsonEncode(conversation.unreadCounts),
        'is_active': conversation.isActive ? 1 : 0,
        'description': conversation.description,
        'metadata': jsonEncode(conversation.metadata),
        'sync_status': 'synced',
      });
    } catch (e) {
      debugPrint('Error storing conversation offline: $e');
      rethrow;
    }
  }

  /// Resolve message conflicts
  Future<ConflictResolutionResult> _resolveMessageConflicts() async {
    try {
      final db = await _offlineService.database;
      
      // Get unresolved conflicts
      final conflictsResult = await db.query(
        'sync_conflicts',
        where: 'is_resolved = 0',
      );

      int resolvedCount = 0;
      final errors = <String>[];

      for (final conflictMap in conflictsResult) {
        try {
          final conflict = _conflictFromMap(conflictMap);
          final resolution = await _resolveConflict(conflict);
          
          if (resolution.isResolved) {
            await _markConflictResolved(conflict.id, resolution.strategy);
            resolvedCount++;
          }
        } catch (e) {
          errors.add('Conflict ${conflictMap['id']}: $e');
        }
      }

      return ConflictResolutionResult(
        resolvedCount: resolvedCount,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error resolving message conflicts: $e');
      return ConflictResolutionResult(
        resolvedCount: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Resolve a single conflict
  Future<ConflictResolution> _resolveConflict(MessageConflict conflict) async {
    try {
      // Simple conflict resolution strategy: prefer remote (server) version
      switch (conflict.type) {
        case ConflictType.messageModified:
          // Use remote version for content conflicts
          await _applyRemoteMessage(conflict.remoteData);
          return ConflictResolution(
            isResolved: true,
            strategy: 'remote_wins',
          );
          
        case ConflictType.messageDeleted:
          // If message was deleted remotely, delete locally too
          await _deleteLocalMessage(conflict.messageId);
          return ConflictResolution(
            isResolved: true,
            strategy: 'remote_wins',
          );
          
        case ConflictType.timestampMismatch:
          // Update local timestamp to match remote
          await _updateLocalMessageTimestamp(
            conflict.messageId,
            conflict.remoteData['sentAt'],
          );
          return ConflictResolution(
            isResolved: true,
            strategy: 'timestamp_sync',
          );
          
        default:
          return ConflictResolution(
            isResolved: false,
            strategy: 'unhandled',
          );
      }
    } catch (e) {
      debugPrint('Error resolving conflict: $e');
      return ConflictResolution(
        isResolved: false,
        strategy: 'error',
      );
    }
  }

  /// Apply remote message data locally
  Future<void> _applyRemoteMessage(Map<String, dynamic> remoteData) async {
    try {
      final message = MessageModel.fromMap(remoteData);
      await _offlineService.storeMessageOffline(message);
    } catch (e) {
      debugPrint('Error applying remote message: $e');
      rethrow;
    }
  }

  /// Delete local message
  Future<void> _deleteLocalMessage(String messageId) async {
    try {
      final db = await _offlineService.database;
      await db.delete(
        'offline_messages',
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('Error deleting local message: $e');
      rethrow;
    }
  }

  /// Update local message timestamp
  Future<void> _updateLocalMessageTimestamp(String messageId, dynamic timestamp) async {
    try {
      final db = await _offlineService.database;
      
      int timestampMs;
      if (timestamp is Timestamp) {
        timestampMs = timestamp.millisecondsSinceEpoch;
      } else if (timestamp is DateTime) {
        timestampMs = timestamp.millisecondsSinceEpoch;
      } else {
        timestampMs = int.parse(timestamp.toString());
      }
      
      await db.update(
        'offline_messages',
        {'created_at': timestampMs, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('Error updating local message timestamp: $e');
      rethrow;
    }
  }

  /// Mark conflict as resolved
  Future<void> _markConflictResolved(String conflictId, String strategy) async {
    try {
      final db = await _offlineService.database;
      await db.update(
        'sync_conflicts',
        {
          'is_resolved': 1,
          'resolved_at': DateTime.now().millisecondsSinceEpoch,
          'resolution_strategy': strategy,
        },
        where: 'id = ?',
        whereArgs: [conflictId],
      );
    } catch (e) {
      debugPrint('Error marking conflict resolved: $e');
    }
  }

  /// Get last sync time from storage
  Future<DateTime?> _getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastSyncTimeKey);
      
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting last sync time: $e');
      return null;
    }
  }

  /// Update last sync time in storage
  Future<void> _updateLastSyncTime(DateTime syncTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncTimeKey, syncTime.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error updating last sync time: $e');
    }
  }

  /// Convert database map to MessageConflict
  MessageConflict _conflictFromMap(Map<String, dynamic> map) {
    return MessageConflict(
      id: map['id'],
      messageId: map['message_id'],
      type: ConflictType.values.firstWhere(
        (e) => e.toString().split('.').last == map['conflict_type'],
        orElse: () => ConflictType.unknown,
      ),
      localData: jsonDecode(map['local_data']),
      remoteData: jsonDecode(map['remote_data']),
      detectedAt: DateTime.fromMillisecondsSinceEpoch(map['detected_at']),
    );
  }

  /// Start monitoring connectivity changes
  Future<void> _startConnectivityMonitoring() async {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      
      if (!wasOnline && _isOnline && !_isSyncing) {
        debugPrint('Connection restored, starting message sync');
        performIncrementalSync();
      }
    });
    
    // Check initial connectivity
    final connectivityResults = await Connectivity().checkConnectivity();
    _isOnline = connectivityResults.isNotEmpty && !connectivityResults.contains(ConnectivityResult.none);
  }

  /// Schedule periodic sync
  Future<void> _schedulePeriodicSync() async {
    _syncTimer?.cancel();
    
    _syncTimer = Timer.periodic(_syncInterval, (timer) async {
      if (_isOnline && !_isSyncing) {
        performIncrementalSync();
      }
    });
  }

  /// Get sync statistics
  Future<SyncStatistics> getSyncStatistics() async {
    try {
      final lastSyncTime = await _getLastSyncTime();
      final db = await _offlineService.database;
      
      final messagesResult = await db.rawQuery('SELECT COUNT(*) as count FROM offline_messages');
      final conflictsResult = await db.rawQuery('SELECT COUNT(*) as count FROM sync_conflicts WHERE is_resolved = 0');
      
      return SyncStatistics(
        lastSyncTime: lastSyncTime,
        totalMessages: messagesResult.first['count'] as int,
        pendingConflicts: conflictsResult.first['count'] as int,
        isSyncing: _isSyncing,
        isOnline: _isOnline,
      );
    } catch (e) {
      debugPrint('Error getting sync statistics: $e');
      return SyncStatistics(
        lastSyncTime: null,
        totalMessages: 0,
        pendingConflicts: 0,
        isSyncing: false,
        isOnline: false,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _syncProgressController.close();
    _syncStatusController.close();
  }
}

// Data models for message sync

enum SyncStatus {
  idle,
  syncing,
  completed,
  completedWithErrors,
  failed,
}

enum SyncType {
  full,
  incremental,
}

enum SyncPhase {
  downloadingMessages,
  updatingConversations,
  resolvingConflicts,
  finalizing,
  completed,
}

enum ConflictType {
  messageModified,
  messageDeleted,
  timestampMismatch,
  unknown,
}

class SyncProgress {
  final SyncPhase phase;
  final double progress; // 0.0 to 1.0
  final String message;

  SyncProgress({
    required this.phase,
    required this.progress,
    required this.message,
  });
}

class SyncResult {
  final bool success;
  final String message;
  final SyncType syncType;
  final int downloadedMessages;
  final int updatedConversations;
  final Duration? duration;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncType,
    this.downloadedMessages = 0,
    this.updatedConversations = 0,
    this.duration,
    this.errors = const [],
  });
}

class DownloadResult {
  final int downloadedCount;
  final List<String> errors;

  DownloadResult({
    required this.downloadedCount,
    required this.errors,
  });
}

class ConversationSyncResult {
  final int updatedCount;
  final List<String> errors;

  ConversationSyncResult({
    required this.updatedCount,
    required this.errors,
  });
}

class ConflictResolutionResult {
  final int resolvedCount;
  final List<String> errors;

  ConflictResolutionResult({
    required this.resolvedCount,
    required this.errors,
  });
}

class MessageConflict {
  final String id;
  final String messageId;
  final ConflictType type;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime detectedAt;

  MessageConflict({
    required this.id,
    required this.messageId,
    required this.type,
    required this.localData,
    required this.remoteData,
    required this.detectedAt,
  });
}

class ConflictResolution {
  final bool isResolved;
  final String strategy;

  ConflictResolution({
    required this.isResolved,
    required this.strategy,
  });
}

class SyncStatistics {
  final DateTime? lastSyncTime;
  final int totalMessages;
  final int pendingConflicts;
  final bool isSyncing;
  final bool isOnline;

  SyncStatistics({
    required this.lastSyncTime,
    required this.totalMessages,
    required this.pendingConflicts,
    required this.isSyncing,
    required this.isOnline,
  });

  bool get canSync => isOnline && !isSyncing;
  bool get hasConflicts => pendingConflicts > 0;
}
