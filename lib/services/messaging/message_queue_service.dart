// Message Queue Service for TALOWA
// Implements Task 8: Create offline messaging and synchronization - Message Queuing
// Reference: in-app-communication/requirements.md - Requirements 1.2, 8.1, 8.2

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:sqflite/sqflite.dart'; // Not supported on web
import '../auth_service.dart';
import 'messaging_service.dart';
import 'offline_messaging_service.dart';
import 'message_compression_service.dart';

class MessageQueueService {
  static final MessageQueueService _instance = MessageQueueService._internal();
  factory MessageQueueService() => _instance;
  MessageQueueService._internal();

  final OfflineMessagingService _offlineService = OfflineMessagingService();
  final MessagingService _messagingService = MessagingService();
  final MessageCompressionService _compressionService = MessageCompressionService();
  
  final StreamController<QueueStatus> _queueStatusController = 
      StreamController<QueueStatus>.broadcast();
  final StreamController<List<QueuedMessage>> _queueUpdatesController = 
      StreamController<List<QueuedMessage>>.broadcast();
  
  Timer? _processingTimer;
  bool _isProcessing = false;
  bool _isOnline = false;
  
  // Queue processing configuration
  static const int _maxConcurrentSends = 3;
  static const Duration _processingInterval = Duration(seconds: 10);
  static const Duration _retryDelay = Duration(seconds: 30);
  
  // Getters for streams
  Stream<QueueStatus> get queueStatusStream => _queueStatusController.stream;
  Stream<List<QueuedMessage>> get queueUpdatesStream => _queueUpdatesController.stream;

  /// Initialize the message queue service
  Future<void> initialize() async {
    try {
      debugPrint('Initializing Message Queue Service');
      
      await _offlineService.initialize();
      await _startConnectivityMonitoring();
      await _startQueueProcessing();
      
      debugPrint('Message Queue Service initialized');
    } catch (e) {
      debugPrint('Error initializing message queue service: $e');
      rethrow;
    }
  }

  /// Add message to queue for sending
  Future<String> enqueueMessage({
    required String conversationId,
    required String content,
    required MessageType messageType,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
    MessagePriority priority = MessagePriority.normal,
    DateTime? scheduledAt,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if we're online and can send immediately
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      if (isOnline && scheduledAt == null) {
        // Try to send immediately
        try {
          final messageId = await _messagingService.sendMessage(
            conversationId: conversationId,
            content: content,
            messageType: messageType,
            mediaUrls: mediaUrls,
            metadata: metadata,
          );
          
          debugPrint('Message sent immediately: $messageId');
          return messageId;
        } catch (e) {
          debugPrint('Failed to send immediately, queuing: $e');
          // Fall through to queue the message
        }
      }

      // Queue the message for later sending
      final queuedMessageId = await _offlineService.queueMessageForSending(
        conversationId: conversationId,
        content: content,
        messageType: messageType,
        mediaUrls: mediaUrls,
        metadata: metadata,
        priority: _priorityToInt(priority),
      );

      // Update queue status
      await _updateQueueStatus();
      
      debugPrint('Message queued: $queuedMessageId');
      return queuedMessageId;
    } catch (e) {
      debugPrint('Error enqueuing message: $e');
      rethrow;
    }
  }

  /// Process queued messages
  Future<QueueProcessingResult> processQueue() async {
    if (_isProcessing) {
      return QueueProcessingResult(
        success: false,
        message: 'Queue processing already in progress',
      );
    }

    try {
      _isProcessing = true;
      _queueStatusController.add(QueueStatus.processing);

      final queuedMessages = await _offlineService.getQueuedMessages();
      if (queuedMessages.isEmpty) {
        _queueStatusController.add(QueueStatus.idle);
        return QueueProcessingResult(
          success: true,
          message: 'No messages in queue',
        );
      }

      // Sort by priority and creation time
      queuedMessages.sort((a, b) {
        if (a.priority != b.priority) {
          return b.priority.compareTo(a.priority); // Higher priority first
        }
        return a.createdAt.compareTo(b.createdAt); // Older messages first
      });

      int successCount = 0;
      int failureCount = 0;
      final errors = <String>[];
      
      // Process messages in batches to avoid overwhelming the server
      final batches = _createBatches(queuedMessages, _maxConcurrentSends);
      
      for (final batch in batches) {
        final futures = batch.map((message) => _processQueuedMessage(message));
        final results = await Future.wait(futures);
        
        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          final message = batch[i];
          
          if (result.success) {
            successCount++;
            await _markMessageAsProcessed(message.id, result.messageId);
          } else {
            failureCount++;
            await _handleMessageFailure(message.id, result.error ?? 'Unknown error');
            errors.add('Message ${message.id}: ${result.error}');
          }
        }
        
        // Small delay between batches to avoid rate limiting
        if (batches.indexOf(batch) < batches.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      await _updateQueueStatus();
      
      final result = QueueProcessingResult(
        success: failureCount == 0,
        message: 'Processed $successCount messages, $failureCount failed',
        processedCount: successCount,
        failedCount: failureCount,
        errors: errors,
      );

      _queueStatusController.add(
        failureCount == 0 ? QueueStatus.idle : QueueStatus.partiallyProcessed
      );

      return result;
    } catch (e) {
      debugPrint('Error processing queue: $e');
      _queueStatusController.add(QueueStatus.error);
      return QueueProcessingResult(
        success: false,
        message: e.toString(),
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Get current queue statistics
  Future<QueueStatistics> getQueueStatistics() async {
    try {
      final queuedMessages = await _offlineService.getQueuedMessages();
      
      int pendingCount = 0;
      int failedCount = 0;
      int highPriorityCount = 0;
      int scheduledCount = 0;
      
      for (final message in queuedMessages) {
        switch (message.status) {
          case QueuedMessageStatus.pending:
            pendingCount++;
            break;
          case QueuedMessageStatus.failed:
            failedCount++;
            break;
          default:
            break;
        }
        
        if (message.priority > 0) {
          highPriorityCount++;
        }
        
        if (message.scheduledAt != null && message.scheduledAt!.isAfter(DateTime.now())) {
          scheduledCount++;
        }
      }

      return QueueStatistics(
        totalMessages: queuedMessages.length,
        pendingMessages: pendingCount,
        failedMessages: failedCount,
        highPriorityMessages: highPriorityCount,
        scheduledMessages: scheduledCount,
        isProcessing: _isProcessing,
        isOnline: _isOnline,
      );
    } catch (e) {
      debugPrint('Error getting queue statistics: $e');
      return QueueStatistics(
        totalMessages: 0,
        pendingMessages: 0,
        failedMessages: 0,
        highPriorityMessages: 0,
        scheduledMessages: 0,
        isProcessing: false,
        isOnline: false,
      );
    }
  }

  /// Retry failed messages
  Future<QueueProcessingResult> retryFailedMessages() async {
    try {
      final db = await _offlineService.database;
      
      // Reset failed messages to pending status
      await db.update(
        'message_queue',
        {
          'status': 'pending',
          'attempts': 0,
          'error_message': null,
          'last_attempt_at': null,
        },
        where: 'status = ?',
        whereArgs: ['failed'],
      );

      await _updateQueueStatus();
      
      // Process the queue
      return await processQueue();
    } catch (e) {
      debugPrint('Error retrying failed messages: $e');
      return QueueProcessingResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Clear sent messages from queue
  Future<void> clearSentMessages() async {
    try {
      final db = await _offlineService.database;
      
      await db.delete(
        'message_queue',
        where: 'status = ?',
        whereArgs: ['sent'],
      );

      await _updateQueueStatus();
      debugPrint('Cleared sent messages from queue');
    } catch (e) {
      debugPrint('Error clearing sent messages: $e');
    }
  }

  /// Cancel a queued message
  Future<bool> cancelQueuedMessage(String queuedMessageId) async {
    try {
      final db = await _offlineService.database;
      
      // Check if message is still pending
      final result = await db.query(
        'message_queue',
        where: 'id = ? AND status = ?',
        whereArgs: [queuedMessageId, 'pending'],
        limit: 1,
      );

      if (result.isEmpty) {
        return false; // Message not found or already processed
      }

      // Delete the message from queue
      await db.delete(
        'message_queue',
        where: 'id = ?',
        whereArgs: [queuedMessageId],
      );

      await _updateQueueStatus();
      debugPrint('Cancelled queued message: $queuedMessageId');
      return true;
    } catch (e) {
      debugPrint('Error cancelling queued message: $e');
      return false;
    }
  }

  /// Schedule message for future sending
  Future<String> scheduleMessage({
    required String conversationId,
    required String content,
    required MessageType messageType,
    required DateTime scheduledAt,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
    MessagePriority priority = MessagePriority.normal,
  }) async {
    try {
      if (scheduledAt.isBefore(DateTime.now())) {
        throw Exception('Scheduled time must be in the future');
      }

      return await enqueueMessage(
        conversationId: conversationId,
        content: content,
        messageType: messageType,
        mediaUrls: mediaUrls,
        metadata: metadata,
        priority: priority,
        scheduledAt: scheduledAt,
      );
    } catch (e) {
      debugPrint('Error scheduling message: $e');
      rethrow;
    }
  }

  // Private helper methods

  /// Process a single queued message
  Future<MessageProcessingResult> _processQueuedMessage(QueuedMessage queuedMessage) async {
    try {
      // Check if message is scheduled for future
      if (queuedMessage.scheduledAt != null && 
          queuedMessage.scheduledAt!.isAfter(DateTime.now())) {
        return MessageProcessingResult(
          success: false,
          error: 'Message scheduled for future',
        );
      }

      // Decompress content if needed
      String content = queuedMessage.content;
      if (queuedMessage.compressionApplied) {
        content = await _compressionService.decompressText(content);
      }

      // Send the message
      final messageId = await _messagingService.sendMessage(
        conversationId: queuedMessage.conversationId,
        content: content,
        messageType: queuedMessage.messageType,
        mediaUrls: queuedMessage.mediaUrls,
        metadata: queuedMessage.metadata,
      );

      return MessageProcessingResult(
        success: true,
        messageId: messageId,
      );
    } catch (e) {
      return MessageProcessingResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Mark message as processed successfully
  Future<void> _markMessageAsProcessed(String queuedMessageId, String? messageId) async {
    try {
      final db = await _offlineService.database;
      
      await db.update(
        'message_queue',
        {
          'status': 'sent',
          'last_attempt_at': DateTime.now().millisecondsSinceEpoch,
          'error_message': null,
        },
        where: 'id = ?',
        whereArgs: [queuedMessageId],
      );
    } catch (e) {
      debugPrint('Error marking message as processed: $e');
    }
  }

  /// Handle message processing failure
  Future<void> _handleMessageFailure(String queuedMessageId, String error) async {
    try {
      final db = await _offlineService.database;
      
      // Get current attempt count
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
      debugPrint('Error handling message failure: $e');
    }
  }

  /// Create batches of messages for concurrent processing
  List<List<QueuedMessage>> _createBatches(List<QueuedMessage> messages, int batchSize) {
    final batches = <List<QueuedMessage>>[];
    
    for (int i = 0; i < messages.length; i += batchSize) {
      final end = (i + batchSize < messages.length) ? i + batchSize : messages.length;
      batches.add(messages.sublist(i, end));
    }
    
    return batches;
  }

  /// Start monitoring connectivity changes
  Future<void> _startConnectivityMonitoring() async {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      if (!wasOnline && _isOnline) {
        debugPrint('Connection restored, processing message queue');
        processQueue();
      }
    });
    
    // Check initial connectivity
    final connectivity = await Connectivity().checkConnectivity();
    _isOnline = connectivity != ConnectivityResult.none;
  }

  /// Start automatic queue processing
  Future<void> _startQueueProcessing() async {
    _processingTimer?.cancel();
    
    _processingTimer = Timer.periodic(_processingInterval, (timer) async {
      if (_isOnline && !_isProcessing) {
        final stats = await getQueueStatistics();
        if (stats.pendingMessages > 0 || stats.scheduledMessages > 0) {
          processQueue();
        }
      }
    });
  }

  /// Update queue status and notify listeners
  Future<void> _updateQueueStatus() async {
    try {
      final queuedMessages = await _offlineService.getQueuedMessages();
      _queueUpdatesController.add(queuedMessages);
    } catch (e) {
      debugPrint('Error updating queue status: $e');
    }
  }

  /// Convert MessagePriority to integer
  int _priorityToInt(MessagePriority priority) {
    switch (priority) {
      case MessagePriority.low:
        return 0;
      case MessagePriority.normal:
        return 1;
      case MessagePriority.high:
        return 2;
      case MessagePriority.emergency:
        return 3;
    }
  }

  /// Dispose resources
  void dispose() {
    _processingTimer?.cancel();
    _queueStatusController.close();
    _queueUpdatesController.close();
  }
}

// Data models for message queue

enum QueueStatus {
  idle,
  processing,
  partiallyProcessed,
  error,
}

enum MessagePriority {
  low,
  normal,
  high,
  emergency,
}

class QueueProcessingResult {
  final bool success;
  final String message;
  final int processedCount;
  final int failedCount;
  final List<String> errors;

  QueueProcessingResult({
    required this.success,
    required this.message,
    this.processedCount = 0,
    this.failedCount = 0,
    this.errors = const [],
  });
}

class MessageProcessingResult {
  final bool success;
  final String? messageId;
  final String? error;

  MessageProcessingResult({
    required this.success,
    this.messageId,
    this.error,
  });
}

class QueueStatistics {
  final int totalMessages;
  final int pendingMessages;
  final int failedMessages;
  final int highPriorityMessages;
  final int scheduledMessages;
  final bool isProcessing;
  final bool isOnline;

  QueueStatistics({
    required this.totalMessages,
    required this.pendingMessages,
    required this.failedMessages,
    required this.highPriorityMessages,
    required this.scheduledMessages,
    required this.isProcessing,
    required this.isOnline,
  });

  bool get hasMessages => totalMessages > 0;
  bool get hasPendingMessages => pendingMessages > 0;
  bool get hasFailedMessages => failedMessages > 0;
  bool get canProcess => isOnline && !isProcessing && hasPendingMessages;
}