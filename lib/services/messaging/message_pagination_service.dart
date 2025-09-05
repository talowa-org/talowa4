// Message Pagination Service for TALOWA
// Implements efficient loading of conversation history with caching
// Requirements: 1.1, 8.4

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../auth_service.dart';
import 'redis_cache_service.dart';

class MessagePaginationService {
  static final MessagePaginationService _instance = MessagePaginationService._internal();
  factory MessagePaginationService() => _instance;
  MessagePaginationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RedisCacheService _cacheService = RedisCacheService();
  
  // Pagination configuration
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;
  static const Duration cacheExpiration = Duration(minutes: 30);
  
  // Track pagination state for conversations
  final Map<String, PaginationState> _paginationStates = {};

  /// Initialize the pagination service
  Future<void> initialize() async {
    try {
      await _cacheService.initialize();
      debugPrint('MessagePaginationService initialized');
    } catch (e) {
      debugPrint('Error initializing MessagePaginationService: $e');
    }
  }

  /// Load messages for a conversation with pagination
  Future<PaginatedMessageResult> loadMessages({
    required String conversationId,
    int page = 0,
    int pageSize = defaultPageSize,
    bool useCache = true,
  }) async {
    try {
      // Validate parameters
      if (pageSize > maxPageSize) {
        pageSize = maxPageSize;
      }
      
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check cache first if enabled
      if (useCache) {
        final cachedMessages = await _cacheService.getCachedMessagesPaginated(
          conversationId: conversationId,
          page: page,
        );
        
        if (cachedMessages != null) {
          final messages = cachedMessages
              .map((data) => MessageModel.fromMap(data))
              .toList();
          
          return PaginatedMessageResult(
            messages: messages,
            page: page,
            pageSize: pageSize,
            hasMore: messages.length == pageSize,
            totalCount: null, // Not available from cache
            fromCache: true,
          );
        }
      }

      // Load from Firestore
      final result = await _loadMessagesFromFirestore(
        conversationId: conversationId,
        page: page,
        pageSize: pageSize,
      );

      // Cache the results
      if (useCache && result.messages.isNotEmpty) {
        final messageData = result.messages
            .map((message) => message.toMap())
            .toList();
        
        await _cacheService.cacheMessagesPaginated(
          conversationId: conversationId,
          messages: messageData,
          page: page,
          pageSize: pageSize,
        );
      }

      // Update pagination state
      _updatePaginationState(conversationId, result);

      return result;
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return PaginatedMessageResult(
        messages: [],
        page: page,
        pageSize: pageSize,
        hasMore: false,
        totalCount: 0,
        fromCache: false,
        error: e.toString(),
      );
    }
  }

  /// Load next page of messages
  Future<PaginatedMessageResult> loadNextPage({
    required String conversationId,
    int pageSize = defaultPageSize,
    bool useCache = true,
  }) async {
    final state = _paginationStates[conversationId];
    final nextPage = (state?.currentPage ?? -1) + 1;
    
    return loadMessages(
      conversationId: conversationId,
      page: nextPage,
      pageSize: pageSize,
      useCache: useCache,
    );
  }

  /// Load previous page of messages
  Future<PaginatedMessageResult> loadPreviousPage({
    required String conversationId,
    int pageSize = defaultPageSize,
    bool useCache = true,
  }) async {
    final state = _paginationStates[conversationId];
    final previousPage = (state?.currentPage ?? 1) - 1;
    
    if (previousPage < 0) {
      return PaginatedMessageResult(
        messages: [],
        page: previousPage,
        pageSize: pageSize,
        hasMore: false,
        totalCount: 0,
        fromCache: false,
        error: 'No previous page available',
      );
    }
    
    return loadMessages(
      conversationId: conversationId,
      page: previousPage,
      pageSize: pageSize,
      useCache: useCache,
    );
  }

  /// Get messages around a specific message (for search results)
  Future<PaginatedMessageResult> loadMessagesAroundMessage({
    required String conversationId,
    required String messageId,
    int contextSize = 25, // Messages before and after
    bool useCache = true,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // First, find the target message to get its timestamp
      final targetMessageDoc = await _firestore
          .collection('messages')
          .doc(messageId)
          .get();

      if (!targetMessageDoc.exists) {
        throw Exception('Message not found');
      }

      final targetMessage = MessageModel.fromFirestore(targetMessageDoc);
      final targetTimestamp = targetMessage.sentAt;

      // Load messages before the target
      final beforeQuery = _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('isDeleted', isEqualTo: false)
          .where('sentAt', isLessThan: Timestamp.fromDate(targetTimestamp))
          .orderBy('sentAt', descending: true)
          .limit(contextSize);

      // Load messages after the target
      final afterQuery = _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('isDeleted', isEqualTo: false)
          .where('sentAt', isGreaterThan: Timestamp.fromDate(targetTimestamp))
          .orderBy('sentAt', descending: false)
          .limit(contextSize);

      // Execute both queries
      final beforeSnapshot = await beforeQuery.get();
      final afterSnapshot = await afterQuery.get();

      // Combine results
      final beforeMessages = beforeSnapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      final afterMessages = afterSnapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      // Combine and sort all messages
      final allMessages = <MessageModel>[
        ...beforeMessages.reversed,
        targetMessage,
        ...afterMessages,
      ];

      allMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      return PaginatedMessageResult(
        messages: allMessages,
        page: 0,
        pageSize: allMessages.length,
        hasMore: false,
        totalCount: allMessages.length,
        fromCache: false,
        contextMessageId: messageId,
      );
    } catch (e) {
      debugPrint('Error loading messages around message: $e');
      return PaginatedMessageResult(
        messages: [],
        page: 0,
        pageSize: 0,
        hasMore: false,
        totalCount: 0,
        fromCache: false,
        error: e.toString(),
      );
    }
  }

  /// Stream messages with real-time updates and pagination
  Stream<PaginatedMessageResult> streamMessages({
    required String conversationId,
    int pageSize = defaultPageSize,
    bool includeDeleted = false,
  }) {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        return Stream.error('User not authenticated');
      }

      Query query = _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId);

      if (!includeDeleted) {
        query = query.where('isDeleted', isEqualTo: false);
      }

      return query
          .orderBy('sentAt', descending: true)
          .limit(pageSize)
          .snapshots()
          .map((snapshot) {
        final messages = snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList();

        return PaginatedMessageResult(
          messages: messages,
          page: 0,
          pageSize: pageSize,
          hasMore: messages.length == pageSize,
          totalCount: null,
          fromCache: false,
          isRealTime: true,
        );
      });
    } catch (e) {
      debugPrint('Error streaming messages: $e');
      return Stream.error(e);
    }
  }

  /// Get pagination state for a conversation
  PaginationState? getPaginationState(String conversationId) {
    return _paginationStates[conversationId];
  }

  /// Reset pagination state for a conversation
  void resetPaginationState(String conversationId) {
    _paginationStates.remove(conversationId);
  }

  /// Invalidate cache for a conversation
  Future<void> invalidateConversationCache(String conversationId) async {
    await _cacheService.invalidateConversationCache(conversationId);
    resetPaginationState(conversationId);
  }

  /// Preload next page in background
  Future<void> preloadNextPage({
    required String conversationId,
    int pageSize = defaultPageSize,
  }) async {
    try {
      final state = _paginationStates[conversationId];
      if (state != null && state.hasMore) {
        final nextPage = state.currentPage + 1;
        
        // Load in background without waiting
        loadMessages(
          conversationId: conversationId,
          page: nextPage,
          pageSize: pageSize,
          useCache: true,
        ).catchError((error) {
          debugPrint('Error preloading next page: $error');
        });
      }
    } catch (e) {
      debugPrint('Error preloading next page: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return _cacheService.getCacheStatistics();
  }

  // Private methods

  Future<PaginatedMessageResult> _loadMessagesFromFirestore({
    required String conversationId,
    required int page,
    required int pageSize,
  }) async {
    try {
      Query query = _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('sentAt', descending: true);

      // Apply pagination using startAfter (would need to be implemented with cursor-based pagination)
      query = query.limit(pageSize + 1); // Load one extra to check if there are more

      final snapshot = await query.get();
      final docs = snapshot.docs;

      // Check if there are more messages
      final hasMore = docs.length > pageSize;
      final messages = docs
          .take(pageSize)
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      return PaginatedMessageResult(
        messages: messages,
        page: page,
        pageSize: pageSize,
        hasMore: hasMore,
        totalCount: null, // Would require separate count query
        fromCache: false,
      );
    } catch (e) {
      debugPrint('Error loading messages from Firestore: $e');
      rethrow;
    }
  }

  void _updatePaginationState(String conversationId, PaginatedMessageResult result) {
    _paginationStates[conversationId] = PaginationState(
      conversationId: conversationId,
      currentPage: result.page,
      pageSize: result.pageSize,
      hasMore: result.hasMore,
      totalCount: result.totalCount,
      lastUpdated: DateTime.now(),
    );
  }
}

/// Pagination state for a conversation
class PaginationState {
  final String conversationId;
  final int currentPage;
  final int pageSize;
  final bool hasMore;
  final int? totalCount;
  final DateTime lastUpdated;

  PaginationState({
    required this.conversationId,
    required this.currentPage,
    required this.pageSize,
    required this.hasMore,
    this.totalCount,
    required this.lastUpdated,
  });
}

/// Result of a paginated message query
class PaginatedMessageResult {
  final List<MessageModel> messages;
  final int page;
  final int pageSize;
  final bool hasMore;
  final int? totalCount;
  final bool fromCache;
  final bool isRealTime;
  final String? contextMessageId;
  final String? error;

  PaginatedMessageResult({
    required this.messages,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    this.totalCount,
    this.fromCache = false,
    this.isRealTime = false,
    this.contextMessageId,
    this.error,
  });

  bool get hasError => error != null;
  bool get isEmpty => messages.isEmpty;
  int get messageCount => messages.length;
}
