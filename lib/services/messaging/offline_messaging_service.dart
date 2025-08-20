// Offline Messaging Service for TALOWA
// Implements Task 8: Create offline messaging and synchronization
// Reference: in-app-communication/requirements.md - Requirements 1.2, 8.1, 8.2, 8.3, 8.4

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:sqflite/sqflite.dart'; // Not supported on web
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/message_model.dart';
import '../auth_service.dart';
import 'messaging_service.dart';
import 'message_compression_service.dart';

class OfflineMessagingService {
  static final OfflineMessagingService _instance = OfflineMessagingService._internal();
  factory OfflineMessagingService() => _instance;
  OfflineMessagingService._internal();

  Database? _database;
  final MessagingService _messagingService = MessagingService();
  final MessageCompressionService _compressionService = MessageCompressionService();
  
  static const String _databaseName = 'talowa_messages_offline.db';
  static const int _databaseVersion = 1;
  
  final StreamController<OfflineSyncStatus> _syncStatusController = 
      StreamController<OfflineSyncStatus>.broadcast();
  final StreamController<List<QueuedMessage>> _queuedMessagesController = 
      StreamController<List<QueuedMessage>>.broadcast();
  
  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _syncTimer;
  
  // Getters for streams
  Stream<OfflineSyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<List<QueuedMessage>> get queuedMessagesStream => _queuedMessagesController.stream;

  /// Initialize the offline messaging service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Offline Messaging Service');
      
      await _initializeDatabase();
      await _startConnectivityMonitoring();
      await _schedulePeriodicSync();
      
      _isInitialized = true;
      debugPrint('Offline Messaging Service initialized');
    } catch (e) {
      debugPrint('Error initializing offline messaging service: $e');
      rethrow;
    }
  }

  /// Initialize the local database
  Future<void> _initializeDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);
      
      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      
      debugPrint('Offline messaging database initialized at: $path');
    } catch (e) {
      debugPrint('Error initializing offline messaging database: $e');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    try {
      // Offline messages table
      await db.execute('''
        CREATE TABLE offline_messages (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          sender_id TEXT NOT NULL,
          sender_name TEXT NOT NULL,
          content TEXT NOT NULL,
          message_type TEXT NOT NULL,
          media_urls TEXT, -- JSON array
          metadata TEXT, -- JSON object
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_sent INTEGER DEFAULT 0,
          is_delivered INTEGER DEFAULT 0,
          is_read INTEGER DEFAULT 0,
          read_by TEXT, -- JSON array
          sync_status TEXT DEFAULT 'pending',
          compression_level INTEGER DEFAULT 0,
          original_size INTEGER,
          compressed_size INTEGER,
          client_message_id TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          last_retry_at INTEGER,
          error_message TEXT
        )
      ''');

      // Offline conversations table
      await db.execute('''
        CREATE TABLE offline_conversations (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          participant_ids TEXT NOT NULL, -- JSON array
          created_by TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          last_message TEXT,
          last_message_at INTEGER,
          last_message_sender_id TEXT,
          unread_counts TEXT, -- JSON object
          is_active INTEGER DEFAULT 1,
          description TEXT,
          metadata TEXT, -- JSON object
          sync_status TEXT DEFAULT 'pending'
        )
      ''');

      // Message queue table for outgoing messages
      await db.execute('''
        CREATE TABLE message_queue (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          content TEXT NOT NULL,
          message_type TEXT NOT NULL,
          media_urls TEXT, -- JSON array
          metadata TEXT, -- JSON object
          priority INTEGER DEFAULT 0, -- 0=normal, 1=high, 2=emergency
          created_at INTEGER NOT NULL,
          scheduled_at INTEGER, -- For delayed sending
          attempts INTEGER DEFAULT 0,
          max_attempts INTEGER DEFAULT 3,
          status TEXT DEFAULT 'pending', -- pending, sending, sent, failed
          last_attempt_at INTEGER,
          error_message TEXT,
          compression_applied INTEGER DEFAULT 0,
          original_size INTEGER,
          compressed_size INTEGER
        )
      ''');

      // Sync conflicts table
      await db.execute('''
        CREATE TABLE sync_conflicts (
          id TEXT PRIMARY KEY,
          message_id TEXT NOT NULL,
          conflict_type TEXT NOT NULL,
          local_data TEXT NOT NULL, -- JSON object
          remote_data TEXT NOT NULL, -- JSON object
          detected_at INTEGER NOT NULL,
          resolved_at INTEGER,
          resolution_strategy TEXT,
          is_resolved INTEGER DEFAULT 0
        )
      ''');

      // Media cache table for offline access
      await db.execute('''
        CREATE TABLE offline_media_cache (
          id TEXT PRIMARY KEY,
          message_id TEXT NOT NULL,
          media_url TEXT NOT NULL,
          local_path TEXT NOT NULL,
          media_type TEXT NOT NULL,
          file_size INTEGER,
          cached_at INTEGER NOT NULL,
          last_accessed INTEGER NOT NULL,
          compression_applied INTEGER DEFAULT 0,
          original_size INTEGER,
          compressed_size INTEGER
        )
      ''');

      // Create indexes for better performance
      await db.execute('CREATE INDEX idx_offline_messages_conversation_id ON offline_messages (conversation_id)');
      await db.execute('CREATE INDEX idx_offline_messages_created_at ON offline_messages (created_at DESC)');
      await db.execute('CREATE INDEX idx_offline_messages_sync_status ON offline_messages (sync_status)');
      await db.execute('CREATE INDEX idx_message_queue_status ON message_queue (status)');
      await db.execute('CREATE INDEX idx_message_queue_priority ON message_queue (priority DESC, created_at ASC)');
      await db.execute('CREATE INDEX idx_sync_conflicts_resolved ON sync_conflicts (is_resolved)');
      await db.execute('CREATE INDEX idx_offline_media_cache_message_id ON offline_media_cache (message_id)');

      debugPrint('Offline messaging database tables created successfully');
    } catch (e) {
      debugPrint('Error creating offline messaging database tables: $e');
      rethrow;
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading offline messaging database from version $oldVersion to $newVersion');
    // Handle database schema upgrades here
  }

  /// Get database instance
  Future<Database> get database async {
    if (_database == null) {
      await _initializeDatabase();
    }
    return _database!;
  }

  /// Store message locally for offline access
  Future<void> storeMessageOffline(MessageModel message) async {
    try {
      final db = await database;
      
      // Apply compression if message is large
      String content = message.content;
      int originalSize = content.length;
      int compressionLevel = 0;
      int compressedSize = originalSize;
      
      if (originalSize > 1024) { // Compress messages larger than 1KB
        final compressed = await _compressionService.compressText(content);
        if (compressed.length < originalSize * 0.8) { // Only use if 20%+ savings
          content = compressed;
          compressionLevel = 1;
          compressedSize = compressed.length;
        }
      }

      await db.insert('offline_messages', {
        'id': message.id,
        'conversation_id': message.conversationId ?? '',
        'sender_id': message.senderId,
        'sender_name': message.senderName ?? 'Unknown',
        'content': content,
        'message_type': message.messageType.toString(),
        'media_urls': jsonEncode(message.mediaUrls),
        'metadata': jsonEncode(message.metadata),
        'created_at': message.sentAt.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'is_sent': message.deliveredAt != null ? 1 : 0,
        'is_delivered': message.deliveredAt != null ? 1 : 0,
        'is_read': message.readAt != null ? 1 : 0,
        'read_by': jsonEncode(message.readBy),
        'sync_status': 'synced',
        'compression_level': compressionLevel,
        'original_size': originalSize,
        'compressed_size': compressedSize,
        'client_message_id': message.id,
        'retry_count': 0,
      });

      debugPrint('Message stored offline: ${message.id}');
    } catch (e) {
      debugPrint('Error storing message offline: $e');
      rethrow;
    }
  }

  /// Queue message for sending when back online
  Future<String> queueMessageForSending({
    required String conversationId,
    required String content,
    required MessageType messageType,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
    int priority = 0,
  }) async {
    try {
      final db = await database;
      final messageId = 'queued_${DateTime.now().millisecondsSinceEpoch}_${conversationId.hashCode}';
      
      // Apply compression for large messages
      String finalContent = content;
      int originalSize = content.length;
      int compressionApplied = 0;
      int compressedSize = originalSize;
      
      if (originalSize > 512) { // Compress messages larger than 512 bytes
        final compressed = await _compressionService.compressText(content);
        if (compressed.length < originalSize * 0.9) { // Use if 10%+ savings
          finalContent = compressed;
          compressionApplied = 1;
          compressedSize = compressed.length;
        }
      }

      await db.insert('message_queue', {
        'id': messageId,
        'conversation_id': conversationId,
        'content': finalContent,
        'message_type': messageType.toString(),
        'media_urls': jsonEncode(mediaUrls ?? []),
        'metadata': jsonEncode(metadata ?? {}),
        'priority': priority,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'attempts': 0,
        'max_attempts': priority > 0 ? 5 : 3, // More retries for high priority
        'status': 'pending',
        'compression_applied': compressionApplied,
        'original_size': originalSize,
        'compressed_size': compressedSize,
      });

      // Notify listeners about new queued message
      await _notifyQueuedMessagesChanged();

      debugPrint('Message queued for sending: $messageId');
      return messageId;
    } catch (e) {
      debugPrint('Error queuing message for sending: $e');
      rethrow;
    }
  }

  /// Get offline messages for a conversation
  Future<List<MessageModel>> getOfflineMessages({
    required String conversationId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final db = await database;
      final result = await db.query(
        'offline_messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );

      final messages = <MessageModel>[];
      for (final map in result) {
        try {
          final message = await _messageFromOfflineMap(map);
          messages.add(message);
        } catch (e) {
          debugPrint('Error converting offline message: $e');
        }
      }

      return messages;
    } catch (e) {
      debugPrint('Error getting offline messages: $e');
      return [];
    }
  }

  /// Get queued messages waiting to be sent
  Future<List<QueuedMessage>> getQueuedMessages() async {
    try {
      final db = await database;
      final result = await db.query(
        'message_queue',
        where: 'status IN (?, ?)',
        whereArgs: ['pending', 'failed'],
        orderBy: 'priority DESC, created_at ASC',
      );

      return result.map((map) => _queuedMessageFromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting queued messages: $e');
      return [];
    }
  }

  /// Sync queued messages when connection is restored
  Future<SyncResult> syncQueuedMessages() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    try {
      _isSyncing = true;
      _syncStatusController.add(OfflineSyncStatus.syncing);

      final queuedMessages = await getQueuedMessages();
      if (queuedMessages.isEmpty) {
        _syncStatusController.add(OfflineSyncStatus.completed);
        return SyncResult(success: true, message: 'No messages to sync');
      }

      int successCount = 0;
      int failureCount = 0;
      final errors = <String>[];

      for (final queuedMessage in queuedMessages) {
        try {
          final result = await _sendQueuedMessage(queuedMessage);
          if (result.success) {
            successCount++;
            await _markMessageAsSent(queuedMessage.id);
          } else {
            failureCount++;
            await _updateMessageRetryCount(queuedMessage.id, result.error);
            errors.add('Message ${queuedMessage.id}: ${result.error}');
          }
        } catch (e) {
          failureCount++;
          await _updateMessageRetryCount(queuedMessage.id, e.toString());
          errors.add('Message ${queuedMessage.id}: $e');
        }
      }

      await _notifyQueuedMessagesChanged();
      
      final syncResult = SyncResult(
        success: failureCount == 0,
        message: 'Synced $successCount messages, $failureCount failed',
        syncedCount: successCount,
        failedCount: failureCount,
        errors: errors,
      );

      _syncStatusController.add(
        failureCount == 0 ? OfflineSyncStatus.completed : OfflineSyncStatus.partiallyCompleted
      );

      return syncResult;
    } catch (e) {
      debugPrint('Error syncing queued messages: $e');
      _syncStatusController.add(OfflineSyncStatus.failed);
      return SyncResult(success: false, message: e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Download missed messages when reconnecting
  Future<SyncResult> downloadMissedMessages({DateTime? lastSyncTime}) async {
    try {
      _syncStatusController.add(OfflineSyncStatus.downloading);

      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        return SyncResult(success: false, message: 'User not authenticated');
      }

      // Get last sync time from local storage if not provided
      lastSyncTime ??= await _getLastSyncTime();
      
      // Get conversations to sync
      final conversations = await _getConversationsToSync();
      
      int downloadedCount = 0;
      final errors = <String>[];

      for (final conversation in conversations) {
        try {
          final messages = await _downloadConversationMessages(
            conversation.id,
            lastSyncTime,
          );
          
          for (final message in messages) {
            await storeMessageOffline(message);
            downloadedCount++;
          }
        } catch (e) {
          errors.add('Conversation ${conversation.id}: $e');
        }
      }

      // Update last sync time
      await _updateLastSyncTime(DateTime.now());

      _syncStatusController.add(OfflineSyncStatus.completed);
      
      return SyncResult(
        success: errors.isEmpty,
        message: 'Downloaded $downloadedCount messages',
        syncedCount: downloadedCount,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error downloading missed messages: $e');
      _syncStatusController.add(OfflineSyncStatus.failed);
      return SyncResult(success: false, message: e.toString());
    }
  }

  /// Get storage usage statistics
  Future<OfflineStorageStats> getStorageStats() async {
    try {
      final db = await database;
      
      final messagesResult = await db.rawQuery('SELECT COUNT(*) as count FROM offline_messages');
      final queueResult = await db.rawQuery('SELECT COUNT(*) as count FROM message_queue');
      final mediaResult = await db.rawQuery('SELECT COUNT(*) as count FROM offline_media_cache');
      
      // Calculate total storage size
      final sizeResult = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN compression_level > 0 THEN compressed_size ELSE original_size END) as total_size
        FROM offline_messages
      ''');
      
      final queueSizeResult = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN compression_applied = 1 THEN compressed_size ELSE original_size END) as total_size
        FROM message_queue
      ''');

      final totalMessages = messagesResult.first['count'] as int;
      final queuedMessages = queueResult.first['count'] as int;
      final cachedMedia = mediaResult.first['count'] as int;
      final messagesSize = sizeResult.first['total_size'] as int? ?? 0;
      final queueSize = queueSizeResult.first['total_size'] as int? ?? 0;

      return OfflineStorageStats(
        totalMessages: totalMessages,
        queuedMessages: queuedMessages,
        cachedMediaFiles: cachedMedia,
        totalSizeBytes: messagesSize + queueSize,
        compressionSavings: await _calculateCompressionSavings(),
      );
    } catch (e) {
      debugPrint('Error getting storage stats: $e');
      return OfflineStorageStats(
        totalMessages: 0,
        queuedMessages: 0,
        cachedMediaFiles: 0,
        totalSizeBytes: 0,
        compressionSavings: 0,
      );
    }
  }

  /// Clean up old offline data
  Future<void> cleanupOldData({Duration? maxAge}) async {
    try {
      maxAge ??= const Duration(days: 30);
      final cutoffTime = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
      
      final db = await database;
      
      // Clean up old synced messages
      await db.delete(
        'offline_messages',
        where: 'sync_status = ? AND created_at < ?',
        whereArgs: ['synced', cutoffTime],
      );
      
      // Clean up old sent messages from queue
      await db.delete(
        'message_queue',
        where: 'status = ? AND created_at < ?',
        whereArgs: ['sent', cutoffTime],
      );
      
      // Clean up old resolved conflicts
      await db.delete(
        'sync_conflicts',
        where: 'is_resolved = 1 AND resolved_at < ?',
        whereArgs: [cutoffTime],
      );
      
      // Clean up old media cache
      await db.delete(
        'offline_media_cache',
        where: 'last_accessed < ?',
        whereArgs: [cutoffTime],
      );

      debugPrint('Cleaned up old offline data');
    } catch (e) {
      debugPrint('Error cleaning up old data: $e');
    }
  }

  // Private helper methods

  /// Send a queued message
  Future<MessageSendResult> _sendQueuedMessage(QueuedMessage queuedMessage) async {
    try {
      // Decompress content if needed
      String content = queuedMessage.content;
      if (queuedMessage.compressionApplied) {
        content = await _compressionService.decompressText(content);
      }

      final messageId = await _messagingService.sendMessage(
        conversationId: queuedMessage.conversationId,
        content: content,
        messageType: queuedMessage.messageType,
        mediaUrls: queuedMessage.mediaUrls,
        metadata: queuedMessage.metadata,
      );

      return MessageSendResult(success: true, messageId: messageId);
    } catch (e) {
      return MessageSendResult(success: false, error: e.toString());
    }
  }

  /// Mark message as sent in queue
  Future<void> _markMessageAsSent(String queuedMessageId) async {
    try {
      final db = await database;
      await db.update(
        'message_queue',
        {
          'status': 'sent',
          'last_attempt_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [queuedMessageId],
      );
    } catch (e) {
      debugPrint('Error marking message as sent: $e');
    }
  }

  /// Update message retry count
  Future<void> _updateMessageRetryCount(String queuedMessageId, String? error) async {
    try {
      final db = await database;
      
      // Get current retry count
      final result = await db.query(
        'message_queue',
        columns: ['attempts', 'max_attempts'],
        where: 'id = ?',
        whereArgs: [queuedMessageId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final currentAttempts = result.first['attempts'] as int;
        final maxAttempts = result.first['max_attempts'] as int;
        final newAttempts = currentAttempts + 1;
        
        final status = newAttempts >= maxAttempts ? 'failed' : 'pending';
        
        await db.update(
          'message_queue',
          {
            'attempts': newAttempts,
            'status': status,
            'last_attempt_at': DateTime.now().millisecondsSinceEpoch,
            'error_message': error,
          },
          where: 'id = ?',
          whereArgs: [queuedMessageId],
        );
      }
    } catch (e) {
      debugPrint('Error updating message retry count: $e');
    }
  }

  /// Get conversations that need syncing
  Future<List<ConversationModel>> _getConversationsToSync() async {
    try {
      // Get conversations from messaging service
      final conversationsStream = _messagingService.getUserConversations();
      final conversations = await conversationsStream.first;
      return conversations;
    } catch (e) {
      debugPrint('Error getting conversations to sync: $e');
      return [];
    }
  }

  /// Download messages for a specific conversation
  Future<List<MessageModel>> _downloadConversationMessages(
    String conversationId,
    DateTime? lastSyncTime,
  ) async {
    try {
      // Get messages from messaging service
      final messagesStream = _messagingService.getConversationMessages(
        conversationId: conversationId,
        limit: 100,
      );
      
      final allMessages = await messagesStream.first;
      
      // Filter messages newer than last sync time
      if (lastSyncTime != null) {
        return allMessages.where((message) => 
          message.sentAt.isAfter(lastSyncTime)
        ).toList();
      }
      
      return allMessages;
    } catch (e) {
      debugPrint('Error downloading conversation messages: $e');
      return [];
    }
  }

  /// Convert offline database map to MessageModel
  Future<MessageModel> _messageFromOfflineMap(Map<String, dynamic> map) async {
    // Decompress content if needed
    String content = map['content'];
    if ((map['compression_level'] as int? ?? 0) > 0) {
      content = await _compressionService.decompressText(content);
    }

    return MessageModel(
      id: map['id'],
      conversationId: map['conversation_id'],
      senderId: map['sender_id'],
      senderName: map['sender_name'],
      content: content,
      messageType: MessageType.values.firstWhere(
        (e) => e.toString() == map['message_type'],
        orElse: () => MessageType.text,
      ),
      mediaUrls: List<String>.from(jsonDecode(map['media_urls'] ?? '[]')),
      sentAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      deliveredAt: (map['is_delivered'] as int) == 1 
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
      readAt: (map['is_read'] as int) == 1 
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
      readBy: List<String>.from(jsonDecode(map['read_by'] ?? '[]')),
      isEdited: false,
      isDeleted: false,
      metadata: Map<String, dynamic>.from(jsonDecode(map['metadata'] ?? '{}')),
    );
  }

  /// Convert database map to QueuedMessage
  QueuedMessage _queuedMessageFromMap(Map<String, dynamic> map) {
    return QueuedMessage(
      id: map['id'],
      conversationId: map['conversation_id'],
      content: map['content'],
      messageType: MessageType.values.firstWhere(
        (e) => e.toString() == map['message_type'],
        orElse: () => MessageType.text,
      ),
      mediaUrls: List<String>.from(jsonDecode(map['media_urls'] ?? '[]')),
      metadata: Map<String, dynamic>.from(jsonDecode(map['metadata'] ?? '{}')),
      priority: map['priority'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      scheduledAt: map['scheduled_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['scheduled_at'])
          : null,
      attempts: map['attempts'] ?? 0,
      maxAttempts: map['max_attempts'] ?? 3,
      status: QueuedMessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => QueuedMessageStatus.pending,
      ),
      lastAttemptAt: map['last_attempt_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_attempt_at'])
          : null,
      errorMessage: map['error_message'],
      compressionApplied: (map['compression_applied'] as int? ?? 0) == 1,
      originalSize: map['original_size'] ?? 0,
      compressedSize: map['compressed_size'] ?? 0,
    );
  }

  /// Start monitoring connectivity changes
  Future<void> _startConnectivityMonitoring() async {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none && !_isSyncing) {
        debugPrint('Connection restored, triggering message sync');
        syncQueuedMessages();
        downloadMissedMessages();
      }
    });
  }

  /// Schedule periodic sync when online
  Future<void> _schedulePeriodicSync() async {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none && !_isSyncing) {
        syncQueuedMessages();
      }
    });
  }

  /// Get last sync time from local storage
  Future<DateTime?> _getLastSyncTime() async {
    try {
      final db = await database;
      final result = await db.query(
        'offline_messages',
        columns: ['MAX(updated_at) as last_sync'],
        limit: 1,
      );
      
      if (result.isNotEmpty && result.first['last_sync'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(result.first['last_sync'] as int);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting last sync time: $e');
      return null;
    }
  }

  /// Update last sync time
  Future<void> _updateLastSyncTime(DateTime syncTime) async {
    try {
      // Store sync time in a simple key-value table or shared preferences
      // For now, we'll use the message update time as a proxy
      debugPrint('Last sync time updated: $syncTime');
    } catch (e) {
      debugPrint('Error updating last sync time: $e');
    }
  }

  /// Calculate compression savings
  Future<int> _calculateCompressionSavings() async {
    try {
      final db = await database;
      
      final result = await db.rawQuery('''
        SELECT 
          SUM(original_size) as total_original,
          SUM(CASE WHEN compression_level > 0 THEN compressed_size ELSE original_size END) as total_compressed
        FROM offline_messages
        WHERE compression_level > 0
      ''');
      
      if (result.isNotEmpty) {
        final totalOriginal = result.first['total_original'] as int? ?? 0;
        final totalCompressed = result.first['total_compressed'] as int? ?? 0;
        return totalOriginal - totalCompressed;
      }
      
      return 0;
    } catch (e) {
      debugPrint('Error calculating compression savings: $e');
      return 0;
    }
  }

  /// Notify listeners about queued messages changes
  Future<void> _notifyQueuedMessagesChanged() async {
    try {
      final queuedMessages = await getQueuedMessages();
      _queuedMessagesController.add(queuedMessages);
    } catch (e) {
      debugPrint('Error notifying queued messages changed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
    _queuedMessagesController.close();
    _database?.close();
  }
}

// Data models for offline messaging

enum OfflineSyncStatus {
  idle,
  syncing,
  downloading,
  completed,
  partiallyCompleted,
  failed,
}

enum QueuedMessageStatus {
  pending,
  sending,
  sent,
  failed,
}

class QueuedMessage {
  final String id;
  final String conversationId;
  final String content;
  final MessageType messageType;
  final List<String> mediaUrls;
  final Map<String, dynamic> metadata;
  final int priority;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final int attempts;
  final int maxAttempts;
  final QueuedMessageStatus status;
  final DateTime? lastAttemptAt;
  final String? errorMessage;
  final bool compressionApplied;
  final int originalSize;
  final int compressedSize;

  QueuedMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.messageType,
    required this.mediaUrls,
    required this.metadata,
    required this.priority,
    required this.createdAt,
    this.scheduledAt,
    required this.attempts,
    required this.maxAttempts,
    required this.status,
    this.lastAttemptAt,
    this.errorMessage,
    required this.compressionApplied,
    required this.originalSize,
    required this.compressedSize,
  });
}

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.errors = const [],
  });
}

class MessageSendResult {
  final bool success;
  final String? messageId;
  final String? error;

  MessageSendResult({
    required this.success,
    this.messageId,
    this.error,
  });
}

class OfflineStorageStats {
  final int totalMessages;
  final int queuedMessages;
  final int cachedMediaFiles;
  final int totalSizeBytes;
  final int compressionSavings;

  OfflineStorageStats({
    required this.totalMessages,
    required this.queuedMessages,
    required this.cachedMediaFiles,
    required this.totalSizeBytes,
    required this.compressionSavings,
  });

  double get totalSizeMB => totalSizeBytes / (1024 * 1024);
  double get compressionSavingsMB => compressionSavings / (1024 * 1024);
  double get compressionRatio => totalSizeBytes > 0 
      ? (compressionSavings / (totalSizeBytes + compressionSavings)) * 100 
      : 0;
}