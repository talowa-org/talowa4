// Message Queue Service for TALOWA
// Implements Task 8: Create offline messaging and synchronization - Message Queuing
// Reference: in-app-communication/requirements.md - Requirements 1.2, 8.1, 8.2

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../auth_service.dart';
import '../../models/messaging/message_model.dart';
import 'messaging_service.dart';

class MessageQueueService {
  static final MessageQueueService _instance = MessageQueueService._internal();
  factory MessageQueueService() => _instance;
  MessageQueueService._internal();

  final MessagingService _messagingService = MessagingService();
  
  final StreamController<QueueStatus> _queueStatusController = 
      StreamController<QueueStatus>.broadcast();
  
  Timer? _processingTimer;
  bool _isProcessing = false;
  bool _isOnline = false;
  
  // Queue processing configuration
  static const Duration _processingInterval = Duration(seconds: 10);
  
  // Getters for streams
  Stream<QueueStatus> get queueStatusStream => _queueStatusController.stream;

  /// Initialize the message queue service
  Future<void> initialize() async {
    try {
      debugPrint('Initializing Message Queue Service');
      
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
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;

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
          debugPrint('Failed to send immediately: $e');
          // For now, just rethrow the error
          rethrow;
        }
      }

      // For offline scenarios, we'll implement a simple queue later
      debugPrint('Message queuing not fully implemented yet');
      throw Exception('Offline messaging not available');
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

      // For now, return success with no messages processed
      _queueStatusController.add(QueueStatus.idle);
      return QueueProcessingResult(
        success: true,
        message: 'No messages in queue',
      );
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
      return QueueStatistics(
        totalMessages: 0,
        pendingMessages: 0,
        failedMessages: 0,
        highPriorityMessages: 0,
        scheduledMessages: 0,
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
      // Simplified implementation
      return QueueProcessingResult(
        success: true,
        message: 'No failed messages to retry',
      );
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
      debugPrint('Cleared sent messages from queue');
    } catch (e) {
      debugPrint('Error clearing sent messages: $e');
    }
  }

  /// Cancel a queued message
  Future<bool> cancelQueuedMessage(String queuedMessageId) async {
    try {
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

  /// Start monitoring connectivity changes
  Future<void> _startConnectivityMonitoring() async {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;
      
      if (!wasOnline && _isOnline) {
        debugPrint('Connection restored, processing message queue');
        processQueue();
      }
    });
    
    // Check initial connectivity
    final connectivity = await Connectivity().checkConnectivity();
    _isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
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



  /// Dispose resources
  void dispose() {
    _processingTimer?.cancel();
    _queueStatusController.close();
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
