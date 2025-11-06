// Message History Storage and Retrieval Service for TALOWA
// Implements Task 5: Message history storage and retrieval system
// Reference: in-app-communication/requirements.md - Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 10.1, 10.3

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/messaging/message_model.dart';

import '../auth_service.dart';
import 'message_pagination_service.dart';
import 'offline_messaging_service.dart';
import 'message_sync_service.dart';

class MessageHistoryService {
  static final MessageHistoryService _instance = MessageHistoryService._internal();
  factory MessageHistoryService() => _instance;
  MessageHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessagePaginationService _paginationService = MessagePaginationService();
  final OfflineMessagingService _offlineService = OfflineMessagingService();
  final MessageSyncService _syncService = MessageSyncService();
  
  // Conversation state management
  final Map<String, ConversationState> _conversationStates = {};
  final StreamController<Map<String, ConversationState>> _stateController = 
      StreamController<Map<String, ConversationState>>.broadcast();
  
  // Message history streams
  final Map<String, StreamController<List<MessageModel>>> _messageStreams = {};
  
  // Configuration
  static const int defaultPageSize = 50;
  static const int maxCachedMessages = 1000;
  static const Duration cacheExpiration = Duration(hours: 24);
  static const String conversationStateKey = 'conversation_states';
  
  bool _isInitialized = false;
  
  // Getters
  Stream<Map<String, ConversationState>> get conversationStatesStream => _stateController.stream;

  /// Initialize the message history service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Message History Service');
      
      await _paginationService.initialize();
      await _offlineService.initialize();
      await _syncService.initialize();
      
      await _loadConversationStates();
      
      _isInitialized = true;
      debugPrint('Message History Service initialized');
    } catch (e) {
      debugPrint('Error initializing message history service: $e');
      rethrow;
    }
  }

  /// Get message history for a conversation with pagination
  Future<MessageHistoryResult> getMessageHistory({
    required String conversationId,
    int page = 0,
    int pageSize = defaultPageSize,
    bool useCache = true,
    bool includeOffline = true,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get conversation state (for potential future use)
      // final state = _conversationStates[conversationId] ?? 
      //     ConversationState(conversationId: conversationId);

      // Get from online source
      final paginationResult = await _paginationService.loadMessages(
        conversationId: conversationId,
        page: page,
        pageSize: pageSize,
        useCache: useCache,
      );

      // Merge with offline messages if requested
      List<MessageModel> allMessages = paginationResult.messages;
      if (includeOffline && page == 0) {
        final offlineMessages = await _offlineService.getOfflineMessages(
          conversationId: conversationId,
          limit: pageSize,
        );
        
        // Merge and sort chronologically
        allMessages = _mergeAndSortMessages(paginationResult.messages, List<MessageModel>.from(offlineMessages));
      }

      // Update conversation state
      await _updateConversationState(conversationId, allMessages);

      return MessageHistoryResult(
        messages: allMessages,
        conversationId: conversationId,
        page: page,
        pageSize: pageSize,
        hasMore: paginationResult.hasMore,
        totalCount: paginationResult.totalCount,
        fromCache: paginationResult.fromCache,
        conversationState: _conversationStates[conversationId],
      );
    } catch (e) {
      debugPrint('Error getting message history: $e');
      return MessageHistoryResult(
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

  /// Stream message history with real-time updates
  Stream<List<MessageModel>> streamMessageHistory({
    required String conversationId,
    int pageSize = defaultPageSize,
    bool includeOffline = true,
  }) {
    try {
      // Create or get existing stream controller
      if (!_messageStreams.containsKey(conversationId)) {
        _messageStreams[conversationId] = StreamController<List<MessageModel>>.broadcast();
        
        // Start streaming from Firestore
        _startMessageStream(conversationId, pageSize, includeOffline);
      }
      
      return _messageStreams[conversationId]!.stream;
    } catch (e) {
      debugPrint('Error streaming message history: $e');
      return Stream.error(e);
    }
  }

  /// Load more messages (pagination)
  Future<MessageHistoryResult> loadMoreMessages({
    required String conversationId,
    int pageSize = defaultPageSize,
  }) async {
    try {
      final result = await _paginationService.loadNextPage(
        conversationId: conversationId,
        pageSize: pageSize,
      );

      // Update conversation state
      if (result.messages.isNotEmpty) {
        await _updateConversationState(conversationId, result.messages);
      }

      return MessageHistoryResult(
        messages: result.messages,
        conversationId: conversationId,
        page: result.page,
        pageSize: result.pageSize,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
        fromCache: result.fromCache,
        conversationState: _conversationStates[conversationId],
      );
    } catch (e) {
      debugPrint('Error loading more messages: $e');
      return MessageHistoryResult(
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

  /// Get conversation state
  ConversationState? getConversationState(String conversationId) {
    return _conversationStates[conversationId];
  }

  /// Update conversation state (scroll position, unread count, etc.)
  Future<void> updateConversationState({
    required String conversationId,
    double? scrollPosition,
    int? unreadCount,
    String? lastReadMessageId,
    DateTime? lastReadAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentState = _conversationStates[conversationId] ?? 
          ConversationState(conversationId: conversationId);

      final updatedState = currentState.copyWith(
        scrollPosition: scrollPosition,
        unreadCount: unreadCount,
        lastReadMessageId: lastReadMessageId,
        lastReadAt: lastReadAt,
        metadata: metadata != null ? {...currentState.metadata, ...metadata} : null,
        lastUpdated: DateTime.now(),
      );

      _conversationStates[conversationId] = updatedState;
      
      // Persist state
      await _saveConversationStates();
      
      // Notify listeners
      _stateController.add(Map.from(_conversationStates));
      
      debugPrint('Updated conversation state for $conversationId');
    } catch (e) {
      debugPrint('Error updating conversation state: $e');
    }
  }

  /// Mark messages as read and update unread indicators
  Future<void> markMessagesAsRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      
      // Update each message
      for (final messageId in messageIds) {
        final messageRef = _firestore.collection('messages').doc(messageId);
        batch.update(messageRef, {
          'readBy': FieldValue.arrayUnion([currentUser.uid]),
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Update conversation unread count
      final conversationRef = _firestore.collection('conversations').doc(conversationId);
      batch.update(conversationRef, {
        'unreadCounts.${currentUser.uid}': 0,
      });
      
      await batch.commit();
      
      // Update local state
      await updateConversationState(
        conversationId: conversationId,
        unreadCount: 0,
        lastReadMessageId: messageIds.last,
        lastReadAt: DateTime.now(),
      );
      
      debugPrint('Marked ${messageIds.length} messages as read');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // Private helper methods

  /// Start streaming messages from Firestore
  void _startMessageStream(String conversationId, int pageSize, bool includeOffline) {
    try {
      final stream = _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('sentAt', descending: true)
          .limit(pageSize)
          .snapshots();

      stream.listen((snapshot) async {
        try {
          final messages = snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();

          // Merge with offline messages if requested
          List<MessageModel> allMessages = messages;
          if (includeOffline) {
            final offlineMessages = await _offlineService.getOfflineMessages(
              conversationId: conversationId,
              limit: pageSize,
            );
            allMessages = _mergeAndSortMessages(messages, List<MessageModel>.from(offlineMessages));
          }

          // Update conversation state
          await _updateConversationState(conversationId, allMessages);

          // Emit to stream
          _messageStreams[conversationId]?.add(allMessages);
        } catch (e) {
          debugPrint('Error processing message stream: $e');
          _messageStreams[conversationId]?.addError(e);
        }
      }, onError: (error) {
        debugPrint('Error in message stream: $error');
        _messageStreams[conversationId]?.addError(error);
      });
    } catch (e) {
      debugPrint('Error starting message stream: $e');
    }
  }

  /// Merge and sort messages chronologically
  List<MessageModel> _mergeAndSortMessages(
    List<MessageModel> onlineMessages,
    List<MessageModel> offlineMessages,
  ) {
    final allMessages = <MessageModel>[];
    final messageIds = <String>{};
    
    // Add online messages first (they're authoritative)
    for (final message in onlineMessages) {
      if (!messageIds.contains(message.id)) {
        allMessages.add(message);
        messageIds.add(message.id);
      }
    }
    
    // Add offline messages that aren't already included
    for (final message in offlineMessages) {
      if (!messageIds.contains(message.id)) {
        allMessages.add(message);
        messageIds.add(message.id);
      }
    }
    
    // Sort chronologically (newest first)
    allMessages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    
    return allMessages;
  }

  /// Update conversation state based on messages
  Future<void> _updateConversationState(String conversationId, List<MessageModel> messages) async {
    try {
      if (messages.isEmpty) return;
      
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      final currentState = _conversationStates[conversationId] ?? 
          ConversationState(conversationId: conversationId);

      // Calculate unread count
      int unreadCount = 0;
      String? lastReadMessageId;
      
      for (final message in messages) {
        if (message.senderId != currentUser.uid && 
            !message.readBy.contains(currentUser.uid)) {
          unreadCount++;
        } else if (message.readBy.contains(currentUser.uid)) {
          lastReadMessageId ??= message.id;
        }
      }

      final updatedState = currentState.copyWith(
        unreadCount: unreadCount,
        lastReadMessageId: lastReadMessageId,
        lastMessageAt: messages.first.sentAt,
        lastUpdated: DateTime.now(),
      );

      _conversationStates[conversationId] = updatedState;
      
      // Notify listeners
      _stateController.add(Map.from(_conversationStates));
    } catch (e) {
      debugPrint('Error updating conversation state: $e');
    }
  }

  /// Load conversation states from storage
  Future<void> _loadConversationStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statesJson = prefs.getString(conversationStateKey);
      
      if (statesJson != null) {
        final statesMap = jsonDecode(statesJson) as Map<String, dynamic>;
        
        for (final entry in statesMap.entries) {
          try {
            final state = ConversationState.fromMap(entry.value);
            _conversationStates[entry.key] = state;
          } catch (e) {
            debugPrint('Error loading conversation state ${entry.key}: $e');
          }
        }
        
        debugPrint('Loaded ${_conversationStates.length} conversation states');
      }
    } catch (e) {
      debugPrint('Error loading conversation states: $e');
    }
  }

  /// Save conversation states to storage
  Future<void> _saveConversationStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statesMap = <String, dynamic>{};
      
      for (final entry in _conversationStates.entries) {
        statesMap[entry.key] = entry.value.toMap();
      }
      
      await prefs.setString(conversationStateKey, jsonEncode(statesMap));
    } catch (e) {
      debugPrint('Error saving conversation states: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _stateController.close();
    
    for (final controller in _messageStreams.values) {
      controller.close();
    }
    _messageStreams.clear();
    
    _conversationStates.clear();
  }
}
// Data models for message history

class MessageHistoryResult {
  final List<MessageModel> messages;
  final String conversationId;
  final int page;
  final int pageSize;
  final bool hasMore;
  final int? totalCount;
  final bool fromCache;
  final String? contextMessageId;
  final ConversationState? conversationState;
  final String? error;

  MessageHistoryResult({
    required this.messages,
    required this.conversationId,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    this.totalCount,
    this.fromCache = false,
    this.contextMessageId,
    this.conversationState,
    this.error,
  });

  bool get hasError => error != null;
  bool get isEmpty => messages.isEmpty;
  int get messageCount => messages.length;
}

class ConversationState {
  final String conversationId;
  final double scrollPosition;
  final int unreadCount;
  final String? lastReadMessageId;
  final DateTime? lastReadAt;
  final DateTime? lastMessageAt;
  final Map<String, dynamic> metadata;
  final DateTime lastUpdated;

  ConversationState({
    required this.conversationId,
    this.scrollPosition = 0.0,
    this.unreadCount = 0,
    this.lastReadMessageId,
    this.lastReadAt,
    this.lastMessageAt,
    this.metadata = const {},
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  ConversationState copyWith({
    String? conversationId,
    double? scrollPosition,
    int? unreadCount,
    String? lastReadMessageId,
    DateTime? lastReadAt,
    DateTime? lastMessageAt,
    Map<String, dynamic>? metadata,
    DateTime? lastUpdated,
  }) {
    return ConversationState(
      conversationId: conversationId ?? this.conversationId,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      metadata: metadata ?? this.metadata,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'scrollPosition': scrollPosition,
      'unreadCount': unreadCount,
      'lastReadMessageId': lastReadMessageId,
      'lastReadAt': lastReadAt?.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'metadata': metadata,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory ConversationState.fromMap(Map<String, dynamic> map) {
    return ConversationState(
      conversationId: map['conversationId'] ?? '',
      scrollPosition: (map['scrollPosition'] ?? 0.0).toDouble(),
      unreadCount: map['unreadCount'] ?? 0,
      lastReadMessageId: map['lastReadMessageId'],
      lastReadAt: map['lastReadAt'] != null 
          ? DateTime.parse(map['lastReadAt'])
          : null,
      lastMessageAt: map['lastMessageAt'] != null 
          ? DateTime.parse(map['lastMessageAt'])
          : null,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get hasUnreadMessages => unreadCount > 0;
}