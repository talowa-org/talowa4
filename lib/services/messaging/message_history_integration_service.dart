// Message History Integration Service for TALOWA
// Integrates all message history components for Task 5 completion
// Reference: in-app-communication/requirements.md - Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 10.1, 10.3

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../auth_service.dart';
import 'message_history_service.dart';
import 'conversation_state_manager.dart';
import 'enhanced_offline_cache_service.dart';
import 'message_threading_service.dart';
import 'message_pagination_service.dart';
import 'offline_messaging_service.dart';
import 'message_sync_service.dart';

class MessageHistoryIntegrationService {
  static final MessageHistoryIntegrationService _instance = MessageHistoryIntegrationService._internal();
  factory MessageHistoryIntegrationService() => _instance;
  MessageHistoryIntegrationService._internal();

  // Core services
  final MessageHistoryService _historyService = MessageHistoryService();
  final ConversationStateManager _stateManager = ConversationStateManager();
  final EnhancedOfflineCacheService _cacheService = EnhancedOfflineCacheService();
  final MessageThreadingService _threadingService = MessageThreadingService();
  final MessagePaginationService _paginationService = MessagePaginationService();
  final OfflineMessagingService _offlineService = OfflineMessagingService();
  final MessageSyncService _syncService = MessageSyncService();

  // Integration state
  bool _isInitialized = false;
  final StreamController<IntegrationStatus> _statusController = 
      StreamController<IntegrationStatus>.broadcast();

  // Getters
  Stream<IntegrationStatus> get statusStream => _statusController.stream;
  bool get isInitialized => _isInitialized;

  /// Initialize all message history components
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Message History Integration Service');
      _statusController.add(IntegrationStatus.initializing);

      // Initialize core services in dependency order
      await _historyService.initialize();
      await _stateManager.initialize();
      await _cacheService.initialize();
      await _paginationService.initialize();
      await _offlineService.initialize();
      await _syncService.initialize();

      _isInitialized = true;
      _statusController.add(IntegrationStatus.ready);
      debugPrint('Message History Integration Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing message history integration: $e');
      _statusController.add(IntegrationStatus.error);
      rethrow;
    }
  }

  /// Get comprehensive message history with all features integrated
  Future<ComprehensiveMessageResult> getComprehensiveMessageHistory({
    required String conversationId,
    int page = 0,
    int pageSize = 50,
    bool useCache = true,
    bool includeOffline = true,
    bool enableThreading = true,
    bool restoreScrollPosition = true,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get message history
      final historyResult = await _historyService.getMessageHistory(
        conversationId: conversationId,
        page: page,
        pageSize: pageSize,
        useCache: useCache,
        includeOffline: includeOffline,
      );

      // Apply threading if enabled
      List<MessageModel> processedMessages = historyResult.messages;
      List<MessageThread>? threads;
      
      if (enableThreading && processedMessages.isNotEmpty) {
        processedMessages = _threadingService.sortMessagesChronologically(
          messages: processedMessages,
          enableThreading: true,
        );
        
        threads = _threadingService.createMessageThreads(
          messages: processedMessages,
        );
      }

      // Get conversation state
      final conversationState = _stateManager.getViewState(conversationId);

      // Restore scroll position if requested
      if (restoreScrollPosition && conversationState.scrollPosition > 0) {
        // This would be handled by the UI layer
        debugPrint('Scroll position available: ${conversationState.scrollPosition}');
      }

      // Cache the results for future use
      if (useCache && processedMessages.isNotEmpty) {
        await _cacheService.cacheConversationMessages(
          conversationId: conversationId,
          messages: processedMessages,
        );
      }

      return ComprehensiveMessageResult(
        messages: processedMessages,
        threads: threads,
        conversationId: conversationId,
        page: page,
        pageSize: pageSize,
        hasMore: historyResult.hasMore,
        totalCount: historyResult.totalCount,
        fromCache: historyResult.fromCache,
        conversationState: conversationState,
        error: historyResult.error,
      );
    } catch (e) {
      debugPrint('Error getting comprehensive message history: $e');
      return ComprehensiveMessageResult(
        messages: [],
        conversationId: conversationId,
        page: page,
        pageSize: pageSize,
        hasMore: false,
        totalCount: 0,
        fromCache: false,
        error: e.toString(),
      );
    }
  }

  /// Stream comprehensive message history with real-time updates
  Stream<ComprehensiveMessageResult> streamComprehensiveMessageHistory({
    required String conversationId,
    int pageSize = 50,
    bool includeOffline = true,
    bool enableThreading = true,
  }) async* {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Stream from history service
      await for (final messages in _historyService.streamMessageHistory(
        conversationId: conversationId,
        pageSize: pageSize,
        includeOffline: includeOffline,
      )) {
        // Apply threading
        List<MessageModel> processedMessages = messages;
        List<MessageThread>? threads;
        
        if (enableThreading && messages.isNotEmpty) {
          processedMessages = _threadingService.sortMessagesChronologically(
            messages: messages,
            enableThreading: true,
          );
          
          threads = _threadingService.createMessageThreads(
            messages: processedMessages,
          );
        }

        // Get current conversation state
        final conversationState = _stateManager.getViewState(conversationId);

        yield ComprehensiveMessageResult(
          messages: processedMessages,
          threads: threads,
          conversationId: conversationId,
          page: 0,
          pageSize: pageSize,
          hasMore: false,
          totalCount: messages.length,
          fromCache: false,
          conversationState: conversationState,
          isRealTime: true,
        );
      }
    } catch (e) {
      debugPrint('Error streaming comprehensive message history: $e');
      yield ComprehensiveMessageResult(
        messages: [],
        conversationId: conversationId,
        page: 0,
        pageSize: pageSize,
        hasMore: false,
        totalCount: 0,
        fromCache: false,
        error: e.toString(),
      );
    }
  }

  /// Update scroll position and conversation state
  Future<void> updateScrollPosition({
    required String conversationId,
    required double scrollPosition,
    required int visibleMessageCount,
    String? firstVisibleMessageId,
    String? lastVisibleMessageId,
  }) async {
    try {
      // Update conversation state manager
      await _stateManager.updateScrollPosition(
        conversationId: conversationId,
        scrollPosition: scrollPosition,
        visibleMessageCount: visibleMessageCount,
        firstVisibleMessageId: firstVisibleMessageId,
        lastVisibleMessageId: lastVisibleMessageId,
      );

      // Update message history service state
      await _historyService.updateConversationState(
        conversationId: conversationId,
        scrollPosition: scrollPosition,
        metadata: {
          'visibleMessageCount': visibleMessageCount,
          'firstVisibleMessageId': firstVisibleMessageId,
          'lastVisibleMessageId': lastVisibleMessageId,
        },
      );
    } catch (e) {
      debugPrint('Error updating scroll position: $e');
    }
  }

  /// Mark messages as read with full integration
  Future<void> markMessagesAsRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    try {
      // Update conversation state manager
      await _stateManager.markMessagesAsRead(
        conversationId: conversationId,
        messageIds: messageIds,
      );

      // Update message history service
      await _historyService.markMessagesAsRead(
        conversationId: conversationId,
        messageIds: messageIds,
      );
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Perform comprehensive sync when coming back online
  Future<ComprehensiveSyncResult> performComprehensiveSync({
    List<String>? conversationIds,
    bool syncCache = true,
    bool syncOfflineMessages = true,
    bool syncConversationStates = true,
  }) async {
    try {
      debugPrint('Starting comprehensive message history sync');
      _statusController.add(IntegrationStatus.syncing);

      final results = <String, dynamic>{};
      final errors = <String>[];

      // Sync message history
      if (syncOfflineMessages) {
        try {
          final historyResult = await _historyService.syncMessageHistory(
            conversationIds: conversationIds,
          );
          results['messageHistory'] = historyResult;
          if (!historyResult.success) {
            errors.addAll(historyResult.errors);
          }
        } catch (e) {
          errors.add('Message history sync: $e');
        }
      }

      // Sync cached messages
      if (syncCache) {
        try {
          final cacheResult = await _cacheService.syncCachedMessages();
          results['cache'] = cacheResult;
          if (!cacheResult.success) {
            errors.addAll(cacheResult.errors);
          }
        } catch (e) {
          errors.add('Cache sync: $e');
        }
      }

      // Sync offline messages
      if (syncOfflineMessages) {
        try {
          final offlineResult = await _offlineService.syncQueuedMessages();
          results['offline'] = offlineResult;
          if (!offlineResult.success) {
            errors.add(offlineResult.message);
          }
        } catch (e) {
          errors.add('Offline sync: $e');
        }
      }

      final success = errors.isEmpty;
      _statusController.add(success ? IntegrationStatus.ready : IntegrationStatus.error);

      return ComprehensiveSyncResult(
        success: success,
        message: success 
            ? 'Comprehensive sync completed successfully'
            : 'Sync completed with ${errors.length} errors',
        results: results,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error during comprehensive sync: $e');
      _statusController.add(IntegrationStatus.error);
      return ComprehensiveSyncResult(
        success: false,
        message: e.toString(),
        results: {},
        errors: [e.toString()],
      );
    }
  }

  /// Get comprehensive statistics across all services
  Future<ComprehensiveStats> getComprehensiveStats() async {
    try {
      final historyStats = await _historyService.getStorageStats();
      final cacheStats = _cacheService.getCacheStatistics();
      final offlineStats = await _offlineService.getStorageStats();
      final stateStats = _stateManager.getStateStats();

      return ComprehensiveStats(
        messageHistoryStats: historyStats,
        cacheStats: cacheStats,
        offlineStats: offlineStats,
        conversationStateStats: stateStats,
      );
    } catch (e) {
      debugPrint('Error getting comprehensive stats: $e');
      return ComprehensiveStats(
        messageHistoryStats: MessageHistoryStats(
          totalMessages: 0,
          cachedMessages: 0,
          queuedMessages: 0,
          totalSizeBytes: 0,
          cacheHitRate: 0.0,
          compressionSavings: 0,
          conversationStates: 0,
        ),
        cacheStats: CacheStatistics(
          memoryCachedConversations: 0,
          diskCachedConversations: 0,
          memoryCachedMessages: 0,
          diskCachedMessages: 0,
          totalCacheSize: 0,
          cacheHitRate: 0.0,
          cacheHits: 0,
          cacheMisses: 0,
        ),
        offlineStats: OfflineStorageStats(
          totalMessages: 0,
          queuedMessages: 0,
          cachedMediaFiles: 0,
          totalSizeBytes: 0,
          compressionSavings: 0,
        ),
        conversationStateStats: ConversationStateStats(
          totalConversations: 0,
          conversationsWithUnread: 0,
          totalUnreadMessages: 0,
          activeConversations: 0,
        ),
      );
    }
  }

  /// Clean up old data across all services
  Future<void> cleanupOldData({Duration? maxAge}) async {
    try {
      debugPrint('Starting comprehensive cleanup');
      
      maxAge ??= const Duration(days: 30);

      // Cleanup message history
      await _historyService.cleanupOldData(maxAge: maxAge);
      
      // Cleanup cache
      await _cacheService.clearExpiredCache();
      
      // Cleanup offline data
      await _offlineService.cleanupOldData(maxAge: maxAge);

      debugPrint('Comprehensive cleanup completed');
    } catch (e) {
      debugPrint('Error during comprehensive cleanup: $e');
    }
  }

  /// Dispose all resources
  void dispose() {
    _statusController.close();
    _historyService.dispose();
    _stateManager.dispose();
    _cacheService.dispose();
  }
}

// Data models for integration service

enum IntegrationStatus {
  initializing,
  ready,
  syncing,
  error,
}

class ComprehensiveMessageResult {
  final List<MessageModel> messages;
  final List<MessageThread>? threads;
  final String conversationId;
  final int page;
  final int pageSize;
  final bool hasMore;
  final int? totalCount;
  final bool fromCache;
  final ConversationViewState? conversationState;
  final String? error;
  final bool isRealTime;

  ComprehensiveMessageResult({
    required this.messages,
    this.threads,
    required this.conversationId,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    this.totalCount,
    this.fromCache = false,
    this.conversationState,
    this.error,
    this.isRealTime = false,
  });

  bool get hasError => error != null;
  bool get isEmpty => messages.isEmpty;
  bool get hasThreads => threads != null && threads!.isNotEmpty;
  int get messageCount => messages.length;
  int get threadCount => threads?.length ?? 0;
}

class ComprehensiveSyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic> results;
  final List<String> errors;

  ComprehensiveSyncResult({
    required this.success,
    required this.message,
    required this.results,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get errorCount => errors.length;
}

class ComprehensiveStats {
  final MessageHistoryStats messageHistoryStats;
  final CacheStatistics cacheStats;
  final OfflineStorageStats offlineStats;
  final ConversationStateStats conversationStateStats;

  ComprehensiveStats({
    required this.messageHistoryStats,
    required this.cacheStats,
    required this.offlineStats,
    required this.conversationStateStats,
  });

  int get totalMessages => messageHistoryStats.totalMessages + 
                          cacheStats.totalCachedMessages + 
                          offlineStats.totalMessages;
  
  double get totalSizeMB => (messageHistoryStats.totalSizeBytes + 
                            cacheStats.totalCacheSize + 
                            offlineStats.totalSizeBytes) / (1024 * 1024);
  
  double get overallCacheHitRate => (messageHistoryStats.cacheHitRate + 
                                    cacheStats.cacheHitRate) / 2;
}