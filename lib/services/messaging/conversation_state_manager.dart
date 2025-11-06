// Conversation State Manager for TALOWA
// Implements Task 5: Conversation state management to preserve scroll position and unread indicators
// Reference: in-app-communication/requirements.md - Requirements 5.4, 5.5, 5.6

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_history_service.dart';

class ConversationStateManager {
  static final ConversationStateManager _instance = ConversationStateManager._internal();
  factory ConversationStateManager() => _instance;
  ConversationStateManager._internal();

  final MessageHistoryService _historyService = MessageHistoryService();
  
  // State tracking
  final Map<String, ConversationViewState> _viewStates = {};
  final Map<String, Timer> _scrollTimers = {};
  final StreamController<ConversationViewState> _stateUpdateController = 
      StreamController<ConversationViewState>.broadcast();
  
  // Configuration
  static const Duration scrollSaveDelay = Duration(milliseconds: 500);
  static const String viewStatesKey = 'conversation_view_states';
  static const double scrollThreshold = 50.0; // Pixels to trigger state save
  
  bool _isInitialized = false;
  
  // Getters
  Stream<ConversationViewState> get stateUpdatesStream => _stateUpdateController.stream;

  /// Initialize the conversation state manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Conversation State Manager');
      
      await _historyService.initialize();
      await _loadViewStates();
      
      _isInitialized = true;
      debugPrint('Conversation State Manager initialized');
    } catch (e) {
      debugPrint('Error initializing conversation state manager: $e');
      rethrow;
    }
  }

  /// Get conversation view state
  ConversationViewState getViewState(String conversationId) {
    return _viewStates[conversationId] ?? ConversationViewState(
      conversationId: conversationId,
    );
  }

  /// Update scroll position with debouncing
  Future<void> updateScrollPosition({
    required String conversationId,
    required double scrollPosition,
    required int visibleMessageCount,
    String? firstVisibleMessageId,
    String? lastVisibleMessageId,
  }) async {
    try {
      final currentState = getViewState(conversationId);
      
      // Check if scroll position changed significantly
      if ((scrollPosition - currentState.scrollPosition).abs() < scrollThreshold) {
        return;
      }

      final updatedState = currentState.copyWith(
        scrollPosition: scrollPosition,
        visibleMessageCount: visibleMessageCount,
        firstVisibleMessageId: firstVisibleMessageId,
        lastVisibleMessageId: lastVisibleMessageId,
        lastScrollUpdate: DateTime.now(),
      );

      _viewStates[conversationId] = updatedState;

      // Cancel existing timer
      _scrollTimers[conversationId]?.cancel();
      
      // Set new timer to save state after delay
      _scrollTimers[conversationId] = Timer(scrollSaveDelay, () async {
        await _saveScrollState(conversationId, updatedState);
      });

      // Notify listeners immediately
      _stateUpdateController.add(updatedState);
      
    } catch (e) {
      debugPrint('Error updating scroll position: $e');
    }
  }

  /// Update unread message indicators
  Future<void> updateUnreadIndicators({
    required String conversationId,
    required int unreadCount,
    required List<String> unreadMessageIds,
    String? lastReadMessageId,
    DateTime? lastReadAt,
  }) async {
    try {
      final currentState = getViewState(conversationId);
      
      final updatedState = currentState.copyWith(
        unreadCount: unreadCount,
        unreadMessageIds: unreadMessageIds,
        lastReadMessageId: lastReadMessageId,
        lastReadAt: lastReadAt,
        lastUnreadUpdate: DateTime.now(),
      );

      _viewStates[conversationId] = updatedState;
      
      // Update message history service state
      await _historyService.updateConversationState(
        conversationId: conversationId,
        unreadCount: unreadCount,
        lastReadMessageId: lastReadMessageId,
        lastReadAt: lastReadAt,
      );

      // Save state immediately for unread updates
      await _saveViewState(conversationId, updatedState);
      
      // Notify listeners
      _stateUpdateController.add(updatedState);
      
      debugPrint('Updated unread indicators for $conversationId: $unreadCount unread');
    } catch (e) {
      debugPrint('Error updating unread indicators: $e');
    }
  }

  /// Mark messages as read and update state
  Future<void> markMessagesAsRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    try {
      final currentState = getViewState(conversationId);
      
      // Remove read messages from unread list
      final updatedUnreadIds = List<String>.from(currentState.unreadMessageIds);
      updatedUnreadIds.removeWhere((id) => messageIds.contains(id));
      
      final updatedState = currentState.copyWith(
        unreadCount: updatedUnreadIds.length,
        unreadMessageIds: updatedUnreadIds,
        lastReadMessageId: messageIds.last,
        lastReadAt: DateTime.now(),
        lastUnreadUpdate: DateTime.now(),
      );

      _viewStates[conversationId] = updatedState;
      
      // Update message history service
      await _historyService.markMessagesAsRead(
        conversationId: conversationId,
        messageIds: messageIds,
      );

      // Save state
      await _saveViewState(conversationId, updatedState);
      
      // Notify listeners
      _stateUpdateController.add(updatedState);
      
      debugPrint('Marked ${messageIds.length} messages as read in $conversationId');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Update typing indicators
  Future<void> updateTypingIndicators({
    required String conversationId,
    required List<String> typingUserIds,
    required Map<String, String> typingUserNames,
  }) async {
    try {
      final currentState = getViewState(conversationId);
      
      final updatedState = currentState.copyWith(
        typingUserIds: typingUserIds,
        typingUserNames: typingUserNames,
        lastTypingUpdate: DateTime.now(),
      );

      _viewStates[conversationId] = updatedState;
      
      // Don't save typing indicators to persistent storage (they're temporary)
      
      // Notify listeners
      _stateUpdateController.add(updatedState);
    } catch (e) {
      debugPrint('Error updating typing indicators: $e');
    }
  }

  /// Update conversation metadata
  Future<void> updateConversationMetadata({
    required String conversationId,
    String? conversationName,
    String? conversationAvatar,
    List<String>? participantIds,
    Map<String, dynamic>? customMetadata,
  }) async {
    try {
      final currentState = getViewState(conversationId);
      
      final updatedMetadata = Map<String, dynamic>.from(currentState.metadata);
      if (conversationName != null) updatedMetadata['name'] = conversationName;
      if (conversationAvatar != null) updatedMetadata['avatar'] = conversationAvatar;
      if (participantIds != null) updatedMetadata['participants'] = participantIds;
      if (customMetadata != null) updatedMetadata.addAll(customMetadata);
      
      final updatedState = currentState.copyWith(
        metadata: updatedMetadata,
        lastMetadataUpdate: DateTime.now(),
      );

      _viewStates[conversationId] = updatedState;
      
      // Save state
      await _saveViewState(conversationId, updatedState);
      
      // Notify listeners
      _stateUpdateController.add(updatedState);
    } catch (e) {
      debugPrint('Error updating conversation metadata: $e');
    }
  }

  /// Get conversations with unread messages
  List<String> getConversationsWithUnreadMessages() {
    return _viewStates.entries
        .where((entry) => entry.value.hasUnreadMessages)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get total unread count across all conversations
  int getTotalUnreadCount() {
    return _viewStates.values
        .map((state) => state.unreadCount)
        .fold(0, (sum, count) => sum + count);
  }

  /// Clear conversation state
  Future<void> clearConversationState(String conversationId) async {
    try {
      _viewStates.remove(conversationId);
      _scrollTimers[conversationId]?.cancel();
      _scrollTimers.remove(conversationId);
      
      await _saveViewStates();
      
      debugPrint('Cleared state for conversation $conversationId');
    } catch (e) {
      debugPrint('Error clearing conversation state: $e');
    }
  }

  /// Restore scroll position for conversation
  Future<void> restoreScrollPosition({
    required String conversationId,
    required Function(double position, String? messageId) onRestore,
  }) async {
    try {
      final state = getViewState(conversationId);
      
      if (state.scrollPosition > 0 || state.lastVisibleMessageId != null) {
        onRestore(state.scrollPosition, state.lastVisibleMessageId);
        debugPrint('Restored scroll position for $conversationId: ${state.scrollPosition}');
      }
    } catch (e) {
      debugPrint('Error restoring scroll position: $e');
    }
  }

  /// Get conversation state statistics
  ConversationStateStats getStateStats() {
    final totalConversations = _viewStates.length;
    final conversationsWithUnread = getConversationsWithUnreadMessages().length;
    final totalUnread = getTotalUnreadCount();
    final activeConversations = _viewStates.values
        .where((state) => state.lastScrollUpdate.isAfter(
            DateTime.now().subtract(const Duration(hours: 24))))
        .length;

    return ConversationStateStats(
      totalConversations: totalConversations,
      conversationsWithUnread: conversationsWithUnread,
      totalUnreadMessages: totalUnread,
      activeConversations: activeConversations,
    );
  }

  // Private helper methods

  /// Save scroll state with debouncing
  Future<void> _saveScrollState(String conversationId, ConversationViewState state) async {
    try {
      // Update message history service
      await _historyService.updateConversationState(
        conversationId: conversationId,
        scrollPosition: state.scrollPosition,
        metadata: {
          'firstVisibleMessageId': state.firstVisibleMessageId,
          'lastVisibleMessageId': state.lastVisibleMessageId,
          'visibleMessageCount': state.visibleMessageCount,
        },
      );

      // Save to local storage
      await _saveViewState(conversationId, state);
      
    } catch (e) {
      debugPrint('Error saving scroll state: $e');
    }
  }

  /// Save single view state
  Future<void> _saveViewState(String conversationId, ConversationViewState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = jsonEncode(state.toMap());
      await prefs.setString('${viewStatesKey}_$conversationId', stateJson);
    } catch (e) {
      debugPrint('Error saving view state: $e');
    }
  }

  /// Save all view states
  Future<void> _saveViewStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statesMap = <String, dynamic>{};
      
      for (final entry in _viewStates.entries) {
        statesMap[entry.key] = entry.value.toMap();
      }
      
      await prefs.setString(viewStatesKey, jsonEncode(statesMap));
    } catch (e) {
      debugPrint('Error saving view states: $e');
    }
  }

  /// Load view states from storage
  Future<void> _loadViewStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statesJson = prefs.getString(viewStatesKey);
      
      if (statesJson != null) {
        final statesMap = jsonDecode(statesJson) as Map<String, dynamic>;
        
        for (final entry in statesMap.entries) {
          try {
            final state = ConversationViewState.fromMap(entry.value);
            _viewStates[entry.key] = state;
          } catch (e) {
            debugPrint('Error loading view state ${entry.key}: $e');
          }
        }
        
        debugPrint('Loaded ${_viewStates.length} conversation view states');
      }
    } catch (e) {
      debugPrint('Error loading view states: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _scrollTimers.values) {
      timer.cancel();
    }
    _scrollTimers.clear();
    
    _stateUpdateController.close();
    _viewStates.clear();
  }
}

// Data models for conversation state management

class ConversationViewState {
  final String conversationId;
  final double scrollPosition;
  final int visibleMessageCount;
  final String? firstVisibleMessageId;
  final String? lastVisibleMessageId;
  final int unreadCount;
  final List<String> unreadMessageIds;
  final String? lastReadMessageId;
  final DateTime? lastReadAt;
  final List<String> typingUserIds;
  final Map<String, String> typingUserNames;
  final Map<String, dynamic> metadata;
  final DateTime lastScrollUpdate;
  final DateTime lastUnreadUpdate;
  final DateTime lastTypingUpdate;
  final DateTime lastMetadataUpdate;

  ConversationViewState({
    required this.conversationId,
    this.scrollPosition = 0.0,
    this.visibleMessageCount = 0,
    this.firstVisibleMessageId,
    this.lastVisibleMessageId,
    this.unreadCount = 0,
    this.unreadMessageIds = const [],
    this.lastReadMessageId,
    this.lastReadAt,
    this.typingUserIds = const [],
    this.typingUserNames = const {},
    this.metadata = const {},
    DateTime? lastScrollUpdate,
    DateTime? lastUnreadUpdate,
    DateTime? lastTypingUpdate,
    DateTime? lastMetadataUpdate,
  }) : lastScrollUpdate = lastScrollUpdate ?? DateTime.now(),
       lastUnreadUpdate = lastUnreadUpdate ?? DateTime.now(),
       lastTypingUpdate = lastTypingUpdate ?? DateTime.now(),
       lastMetadataUpdate = lastMetadataUpdate ?? DateTime.now();

  ConversationViewState copyWith({
    String? conversationId,
    double? scrollPosition,
    int? visibleMessageCount,
    String? firstVisibleMessageId,
    String? lastVisibleMessageId,
    int? unreadCount,
    List<String>? unreadMessageIds,
    String? lastReadMessageId,
    DateTime? lastReadAt,
    List<String>? typingUserIds,
    Map<String, String>? typingUserNames,
    Map<String, dynamic>? metadata,
    DateTime? lastScrollUpdate,
    DateTime? lastUnreadUpdate,
    DateTime? lastTypingUpdate,
    DateTime? lastMetadataUpdate,
  }) {
    return ConversationViewState(
      conversationId: conversationId ?? this.conversationId,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      visibleMessageCount: visibleMessageCount ?? this.visibleMessageCount,
      firstVisibleMessageId: firstVisibleMessageId ?? this.firstVisibleMessageId,
      lastVisibleMessageId: lastVisibleMessageId ?? this.lastVisibleMessageId,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadMessageIds: unreadMessageIds ?? this.unreadMessageIds,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      typingUserNames: typingUserNames ?? this.typingUserNames,
      metadata: metadata ?? this.metadata,
      lastScrollUpdate: lastScrollUpdate ?? this.lastScrollUpdate,
      lastUnreadUpdate: lastUnreadUpdate ?? this.lastUnreadUpdate,
      lastTypingUpdate: lastTypingUpdate ?? this.lastTypingUpdate,
      lastMetadataUpdate: lastMetadataUpdate ?? this.lastMetadataUpdate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'scrollPosition': scrollPosition,
      'visibleMessageCount': visibleMessageCount,
      'firstVisibleMessageId': firstVisibleMessageId,
      'lastVisibleMessageId': lastVisibleMessageId,
      'unreadCount': unreadCount,
      'unreadMessageIds': unreadMessageIds,
      'lastReadMessageId': lastReadMessageId,
      'lastReadAt': lastReadAt?.toIso8601String(),
      'typingUserIds': typingUserIds,
      'typingUserNames': typingUserNames,
      'metadata': metadata,
      'lastScrollUpdate': lastScrollUpdate.toIso8601String(),
      'lastUnreadUpdate': lastUnreadUpdate.toIso8601String(),
      'lastTypingUpdate': lastTypingUpdate.toIso8601String(),
      'lastMetadataUpdate': lastMetadataUpdate.toIso8601String(),
    };
  }

  factory ConversationViewState.fromMap(Map<String, dynamic> map) {
    return ConversationViewState(
      conversationId: map['conversationId'] ?? '',
      scrollPosition: (map['scrollPosition'] ?? 0.0).toDouble(),
      visibleMessageCount: map['visibleMessageCount'] ?? 0,
      firstVisibleMessageId: map['firstVisibleMessageId'],
      lastVisibleMessageId: map['lastVisibleMessageId'],
      unreadCount: map['unreadCount'] ?? 0,
      unreadMessageIds: List<String>.from(map['unreadMessageIds'] ?? []),
      lastReadMessageId: map['lastReadMessageId'],
      lastReadAt: map['lastReadAt'] != null 
          ? DateTime.parse(map['lastReadAt'])
          : null,
      typingUserIds: List<String>.from(map['typingUserIds'] ?? []),
      typingUserNames: Map<String, String>.from(map['typingUserNames'] ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      lastScrollUpdate: DateTime.parse(map['lastScrollUpdate'] ?? DateTime.now().toIso8601String()),
      lastUnreadUpdate: DateTime.parse(map['lastUnreadUpdate'] ?? DateTime.now().toIso8601String()),
      lastTypingUpdate: DateTime.parse(map['lastTypingUpdate'] ?? DateTime.now().toIso8601String()),
      lastMetadataUpdate: DateTime.parse(map['lastMetadataUpdate'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get hasUnreadMessages => unreadCount > 0;
  bool get hasTypingUsers => typingUserIds.isNotEmpty;
  bool get isScrolledToTop => scrollPosition <= 0;
  bool get isScrolledToBottom => scrollPosition >= 1.0;
}

class ConversationStateStats {
  final int totalConversations;
  final int conversationsWithUnread;
  final int totalUnreadMessages;
  final int activeConversations;

  ConversationStateStats({
    required this.totalConversations,
    required this.conversationsWithUnread,
    required this.totalUnreadMessages,
    required this.activeConversations,
  });

  double get unreadConversationRatio => 
      totalConversations > 0 ? conversationsWithUnread / totalConversations : 0.0;
  
  double get averageUnreadPerConversation => 
      conversationsWithUnread > 0 ? totalUnreadMessages / conversationsWithUnread : 0.0;
}