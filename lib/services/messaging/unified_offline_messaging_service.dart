// Unified Offline Messaging Service for TALOWA
// Implements Task 8: Create offline messaging and synchronization - Integration
// Reference: in-app-communication/requirements.md - Requirements 1.2, 8.1, 8.2, 8.3, 8.4

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/message_model.dart';
import '../auth_service.dart';
import 'offline_messaging_service.dart';
import 'message_queue_service.dart';
import 'message_sync_service.dart';
import 'message_conflict_resolver.dart';
import 'message_compression_service.dart';

class UnifiedOfflineMessagingService {
  static final UnifiedOfflineMessagingService _instance = UnifiedOfflineMessagingService._internal();
  factory UnifiedOfflineMessagingService() => _instance;
  UnifiedOfflineMessagingService._internal();

  // Service instances
  final OfflineMessagingService _offlineService = OfflineMessagingService();
  final MessageQueueService _queueService = MessageQueueService();
  final MessageSyncService _syncService = MessageSyncService();
  final MessageConflictResolver _conflictResolver = MessageConflictResolver();
  final MessageCompressionService _compressionService = MessageCompressionService();
  
  // Status controllers
  final StreamController<UnifiedOfflineStatus> _statusController = 
      StreamController<UnifiedOfflineStatus>.broadcast();
  final StreamController<OfflineMessagingStats> _statsController = 
      StreamController<OfflineMessagingStats>.broadcast();
  
  Timer? _statusUpdateTimer;
  bool _isInitialized = false;
  
  // Getters for streams
  Stream<UnifiedOfflineStatus> get statusStream => _statusController.stream;
  Stream<OfflineMessagingStats> get statsStream => _statsController.stream;

  /// Initialize all offline messaging services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Unified Offline Messaging Service');
      
      // Initialize all sub-services
      await _offlineService.initialize();
      await _queueService.initialize();
      await _syncService.initialize();
      
      // Start status monitoring
      await _startStatusMonitoring();
      
      _isInitialized = true;
      debugPrint('Unified Offline Messaging Service initialized');
    } catch (e) {
      debugPrint('Error initializing unified offline messaging service: $e');
      rethrow;
    }
  }

  /// Send message with offline support
  Future<MessageSendResult> sendMessage({
    required String conversationId,
    required String content,
    required MessageType messageType,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
    MessagePriority priority = MessagePriority.normal,
    bool enableCompression = true,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      // Apply compression if enabled and appropriate
      String finalContent = content;
      List<String> finalMediaUrls = mediaUrls ?? [];
      Map<String, dynamic> finalMetadata = metadata ?? {};
      
      if (enableCompression) {
        final compressionResult = await _compressionService.compressMessageData(
          content: content,
          mediaUrls: mediaUrls ?? [],
          metadata: metadata ?? {},
        );
        
        if (compressionResult.success) {
          finalContent = compressionResult.compressedContent;
          finalMediaUrls = compressionResult.compressedMediaUrls;
          finalMetadata = compressionResult.compressedMetadata;
        }
      }

      if (isOnline) {
        // Try to send immediately
        try {
          final messageId = await _queueService.enqueueMessage(
            conversationId: conversationId,
            content: finalContent,
            messageType: messageType,
            mediaUrls: finalMediaUrls,
            metadata: finalMetadata,
            priority: priority,
          );
          
          return MessageSendResult(
            success: true,
            messageId: messageId,
            sentImmediately: true,
          );
        } catch (e) {
          debugPrint('Failed to send immediately, queuing: $e');
          // Fall through to queue the message
        }
      }

      // Queue for later sending
      final queuedMessageId = await _queueService.enqueueMessage(
        conversationId: conversationId,
        content: finalContent,
        messageType: messageType,
        mediaUrls: finalMediaUrls,
        metadata: finalMetadata,
        priority: priority,
      );

      return MessageSendResult(
        success: true,
        messageId: queuedMessageId,
        sentImmediately: false,
        queued: true,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      return MessageSendResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get messages for a conversation (offline-first)
  Future<List<MessageModel>> getConversationMessages({
    required String conversationId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // First, get messages from offline storage
      final offlineMessages = await _offlineService.getOfflineMessages(
        conversationId: conversationId,
        limit: limit,
        offset: offset,
      );

      // If we have offline messages, return them
      if (offlineMessages.isNotEmpty) {
        return offlineMessages;
      }

      // If no offline messages and we're online, try to sync
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        await _syncService.performIncrementalSync();
        
        // Try to get messages again after sync
        return await _offlineService.getOfflineMessages(
          conversationId: conversationId,
          limit: limit,
          offset: offset,
        );
      }

      return [];
    } catch (e) {
      debugPrint('Error getting conversation messages: $e');
      return [];
    }
  }

  /// Perform full synchronization
  Future<UnifiedSyncResult> performFullSync() async {
    try {
      debugPrint('Starting unified full sync');
      
      final startTime = DateTime.now();
      
      // Step 1: Process queued messages
      final queueResult = await _queueService.processQueue();
      
      // Step 2: Download missed messages
      final syncResult = await _syncService.performFullSync();
      
      // Step 3: Resolve conflicts
      final conflictResult = await _conflictResolver.detectAndResolveConflicts();
      
      final duration = DateTime.now().difference(startTime);
      
      final result = UnifiedSyncResult(
        success: queueResult.success && syncResult.success && conflictResult.success,
        message: 'Full sync completed',
        queueProcessingResult: queueResult,
        syncResult: syncResult,
        conflictResolutionResult: conflictResult,
        duration: duration,
      );

      await _updateStats();
      
      return result;
    } catch (e) {
      debugPrint('Error in unified full sync: $e');
      return UnifiedSyncResult(
        success: false,
        message: e.toString(),
        queueProcessingResult: QueueProcessingResult(success: false, message: 'Not executed'),
        syncResult: SyncResult(success: false, message: 'Not executed', syncType: SyncType.full),
        conflictResolutionResult: ConflictResolutionResult(
          success: false,
          message: 'Not executed',
          resolvedConflicts: 0,
          totalConflicts: 0,
        ),
      );
    }
  }

  /// Perform incremental synchronization
  Future<UnifiedSyncResult> performIncrementalSync() async {
    try {
      debugPrint('Starting unified incremental sync');
      
      final startTime = DateTime.now();
      
      // Step 1: Process queued messages
      final queueResult = await _queueService.processQueue();
      
      // Step 2: Download recent messages
      final syncResult = await _syncService.performIncrementalSync();
      
      // Step 3: Resolve any new conflicts
      final conflictResult = await _conflictResolver.detectAndResolveConflicts();
      
      final duration = DateTime.now().difference(startTime);
      
      final result = UnifiedSyncResult(
        success: queueResult.success && syncResult.success && conflictResult.success,
        message: 'Incremental sync completed',
        queueProcessingResult: queueResult,
        syncResult: syncResult,
        conflictResolutionResult: conflictResult,
        duration: duration,
      );

      await _updateStats();
      
      return result;
    } catch (e) {
      debugPrint('Error in unified incremental sync: $e');
      return UnifiedSyncResult(
        success: false,
        message: e.toString(),
        queueProcessingResult: QueueProcessingResult(success: false, message: 'Not executed'),
        syncResult: SyncResult(success: false, message: 'Not executed', syncType: SyncType.incremental),
        conflictResolutionResult: ConflictResolutionResult(
          success: false,
          message: 'Not executed',
          resolvedConflicts: 0,
          totalConflicts: 0,
        ),
      );
    }
  }

  /// Get comprehensive offline messaging statistics
  Future<OfflineMessagingStats> getStats() async {
    try {
      final storageStats = await _offlineService.getStorageStats();
      final queueStats = await _queueService.getQueueStatistics();
      final syncStats = await _syncService.getSyncStatistics();
      final conflictStats = await _conflictResolver.getConflictStatistics();
      final compressionStats = await _compressionService.getCompressionStatistics();

      return OfflineMessagingStats(
        storageStats: storageStats,
        queueStats: queueStats,
        syncStats: syncStats,
        conflictStats: conflictStats,
        compressionStats: compressionStats,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting offline messaging stats: $e');
      return OfflineMessagingStats(
        storageStats: OfflineStorageStats(
          totalMessages: 0,
          queuedMessages: 0,
          cachedMediaFiles: 0,
          totalSizeBytes: 0,
          compressionSavings: 0,
        ),
        queueStats: QueueStatistics(
          totalMessages: 0,
          pendingMessages: 0,
          failedMessages: 0,
          highPriorityMessages: 0,
          scheduledMessages: 0,
          isProcessing: false,
          isOnline: false,
        ),
        syncStats: SyncStatistics(
          lastSyncTime: null,
          totalMessages: 0,
          pendingConflicts: 0,
          isSyncing: false,
          isOnline: false,
        ),
        conflictStats: ConflictStatistics(
          totalConflicts: 0,
          resolvedConflicts: 0,
          pendingConflicts: 0,
        ),
        compressionStats: CompressionStatistics(
          totalMessagesCompressed: 0,
          totalBytesOriginal: 0,
          totalBytesCompressed: 0,
          averageCompressionRatio: 0,
          totalCompressionTime: Duration.zero,
        ),
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Get current unified status
  Future<UnifiedOfflineStatus> getStatus() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;
      
      final queueStats = await _queueService.getQueueStatistics();
      final syncStats = await _syncService.getSyncStatistics();
      final conflictStats = await _conflictResolver.getConflictStatistics();

      return UnifiedOfflineStatus(
        isOnline: isOnline,
        isInitialized: _isInitialized,
        hasPendingMessages: queueStats.hasPendingMessages,
        hasFailedMessages: queueStats.hasFailedMessages,
        isSyncing: syncStats.isSyncing,
        hasConflicts: conflictStats.hasConflicts,
        lastSyncTime: syncStats.lastSyncTime,
        networkQuality: await _compressionService.getOptimalCompressionSettings()
            .then((settings) => _getNetworkQualityFromSettings(settings)),
      );
    } catch (e) {
      debugPrint('Error getting unified status: $e');
      return UnifiedOfflineStatus(
        isOnline: false,
        isInitialized: false,
        hasPendingMessages: false,
        hasFailedMessages: false,
        isSyncing: false,
        hasConflicts: false,
        lastSyncTime: null,
        networkQuality: NetworkQuality.unknown,
      );
    }
  }

  /// Clean up old data across all services
  Future<void> cleanupOldData({Duration? maxAge}) async {
    try {
      debugPrint('Starting unified cleanup');
      
      maxAge ??= const Duration(days: 30);
      
      // Clean up offline messages
      await _offlineService.cleanupOldData(maxAge: maxAge);
      
      // Clean up sent messages from queue
      await _queueService.clearSentMessages();
      
      debugPrint('Unified cleanup completed');
    } catch (e) {
      debugPrint('Error in unified cleanup: $e');
    }
  }

  /// Retry all failed operations
  Future<UnifiedRetryResult> retryFailedOperations() async {
    try {
      debugPrint('Retrying failed operations');
      
      // Retry failed queued messages
      final queueRetryResult = await _queueService.retryFailedMessages();
      
      // Retry conflict resolution
      final conflictRetryResult = await _conflictResolver.detectAndResolveConflicts();
      
      // Perform sync to get latest data
      final syncResult = await _syncService.performIncrementalSync();
      
      return UnifiedRetryResult(
        success: queueRetryResult.success && conflictRetryResult.success && syncResult.success,
        queueRetryResult: queueRetryResult,
        conflictRetryResult: conflictRetryResult,
        syncResult: syncResult,
      );
    } catch (e) {
      debugPrint('Error retrying failed operations: $e');
      return UnifiedRetryResult(
        success: false,
        queueRetryResult: QueueProcessingResult(success: false, message: 'Not executed'),
        conflictRetryResult: ConflictResolutionResult(
          success: false,
          message: 'Not executed',
          resolvedConflicts: 0,
          totalConflicts: 0,
        ),
        syncResult: SyncResult(success: false, message: 'Not executed', syncType: SyncType.incremental),
      );
    }
  }

  // Private helper methods

  /// Start monitoring status changes
  Future<void> _startStatusMonitoring() async {
    _statusUpdateTimer?.cancel();
    
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final status = await getStatus();
      _statusController.add(status);
      
      final stats = await getStats();
      _statsController.add(stats);
    });
    
    // Send initial status
    final initialStatus = await getStatus();
    _statusController.add(initialStatus);
  }

  /// Update statistics
  Future<void> _updateStats() async {
    try {
      final stats = await getStats();
      _statsController.add(stats);
    } catch (e) {
      debugPrint('Error updating stats: $e');
    }
  }

  /// Get network quality from compression settings
  NetworkQuality _getNetworkQualityFromSettings(CompressionSettings settings) {
    if (!settings.enableImageCompression) {
      return NetworkQuality.excellent;
    } else if (settings.imageQuality > 0.8) {
      return NetworkQuality.good;
    } else if (settings.imageQuality > 0.5) {
      return NetworkQuality.poor;
    } else {
      return NetworkQuality.veryPoor;
    }
  }

  /// Dispose all resources
  void dispose() {
    _statusUpdateTimer?.cancel();
    _statusController.close();
    _statsController.close();
    
    _queueService.dispose();
    _syncService.dispose();
    _conflictResolver.dispose();
    _offlineService.dispose();
  }
}

// Data models for unified service

class UnifiedOfflineStatus {
  final bool isOnline;
  final bool isInitialized;
  final bool hasPendingMessages;
  final bool hasFailedMessages;
  final bool isSyncing;
  final bool hasConflicts;
  final DateTime? lastSyncTime;
  final NetworkQuality networkQuality;

  UnifiedOfflineStatus({
    required this.isOnline,
    required this.isInitialized,
    required this.hasPendingMessages,
    required this.hasFailedMessages,
    required this.isSyncing,
    required this.hasConflicts,
    required this.lastSyncTime,
    required this.networkQuality,
  });

  bool get needsAttention => hasFailedMessages || hasConflicts;
  bool get canSync => isOnline && isInitialized && !isSyncing;
  bool get isHealthy => isInitialized && !hasFailedMessages && !hasConflicts;
}

class OfflineMessagingStats {
  final OfflineStorageStats storageStats;
  final QueueStatistics queueStats;
  final SyncStatistics syncStats;
  final ConflictStatistics conflictStats;
  final CompressionStatistics compressionStats;
  final DateTime lastUpdated;

  OfflineMessagingStats({
    required this.storageStats,
    required this.queueStats,
    required this.syncStats,
    required this.conflictStats,
    required this.compressionStats,
    required this.lastUpdated,
  });

  int get totalMessages => storageStats.totalMessages;
  int get totalPendingOperations => queueStats.pendingMessages + syncStats.pendingConflicts;
  double get totalStorageMB => storageStats.totalSizeMB;
  double get compressionSavingsMB => compressionStats.totalSavingsMB;
}

class MessageSendResult {
  final bool success;
  final String? messageId;
  final bool sentImmediately;
  final bool queued;
  final String? error;

  MessageSendResult({
    required this.success,
    this.messageId,
    this.sentImmediately = false,
    this.queued = false,
    this.error,
  });
}

class UnifiedSyncResult {
  final bool success;
  final String message;
  final QueueProcessingResult queueProcessingResult;
  final SyncResult syncResult;
  final ConflictResolutionResult conflictResolutionResult;
  final Duration? duration;

  UnifiedSyncResult({
    required this.success,
    required this.message,
    required this.queueProcessingResult,
    required this.syncResult,
    required this.conflictResolutionResult,
    this.duration,
  });

  int get totalProcessedItems => 
      queueProcessingResult.processedCount + 
      syncResult.downloadedMessages + 
      conflictResolutionResult.resolvedConflicts;
}

class UnifiedRetryResult {
  final bool success;
  final QueueProcessingResult queueRetryResult;
  final ConflictResolutionResult conflictRetryResult;
  final SyncResult syncResult;

  UnifiedRetryResult({
    required this.success,
    required this.queueRetryResult,
    required this.conflictRetryResult,
    required this.syncResult,
  });
}
