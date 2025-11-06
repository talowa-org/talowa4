// Main Messaging Service for TALOWA
// Combines simple and advanced messaging features with real-time delivery confirmation
// Enhanced with comprehensive error handling and loading states

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/message_status_model.dart';
import '../../models/user_model.dart';
import '../auth_service.dart';
import 'simple_messaging_service.dart';
import 'advanced_messaging_service.dart';
import 'real_time_messaging_service.dart';
import 'messaging_search_service.dart';
import 'messaging_error_integration.dart';
import 'loading_state_service.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SimpleMessagingService _simpleMessaging = SimpleMessagingService();
  final AdvancedMessagingService _advancedMessaging = AdvancedMessagingService();
  final RealTimeMessagingService _realTimeMessaging = RealTimeMessagingService();
  final MessagingSearchService _searchService = MessagingSearchService();
  final MessagingErrorIntegration _errorIntegration = MessagingErrorIntegration();


  // Stream controllers for message status updates
  final StreamController<MessageStatusModel> _messageStatusController = 
      StreamController<MessageStatusModel>.broadcast();
  final StreamController<Map<String, dynamic>> _typingIndicatorController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for real-time streams
  Stream<MessageModel> get messageStream => _realTimeMessaging.messageStream;
  Stream<MessageDeliveryStatus> get deliveryStatusStream => _realTimeMessaging.deliveryStatusStream;
  Stream<MessageStatusModel> get messageStatusStream => _messageStatusController.stream;
  Stream<Map<String, dynamic>> get typingIndicatorStream => _realTimeMessaging.typingIndicatorStream;
  Stream<String> get connectionStatusStream => _realTimeMessaging.connectionStatusStream;

  bool get isRealTimeConnected => _realTimeMessaging.isConnected;
  
  // Error handling and loading state getters
  bool get isOnline => _errorIntegration.isOnline;
  Stream<bool> get networkStatusStream => _errorIntegration.networkStatusStream;
  Stream<LoadingState?> getLoadingStateStream(String operationId) => _errorIntegration.getLoadingStateStream(operationId);
  bool isOperationLoading(String operationId) => _errorIntegration.isLoading(operationId);
  Map<String, dynamic> get systemStatus => _errorIntegration.getSystemStatus();

  /// Initialize messaging service
  Future<void> initialize() async {
    try {
      // Initialize error handling and loading states first
      await _errorIntegration.initialize();
      
      // Initialize real-time messaging
      await _realTimeMessaging.initialize();
      
      // Initialize advanced messaging
      await _advancedMessaging.initialize();
      
      // Initialize search service
      await _searchService.initialize();
      
      // Set up message status tracking
      _setupMessageStatusTracking();
      
      debugPrint('✅ Messaging Service initialized with comprehensive error handling');
    } catch (e) {
      debugPrint('❌ Error initializing messaging service: $e');
      rethrow;
    }
  }

  /// Set up message status tracking
  void _setupMessageStatusTracking() {
    // Listen to delivery status updates
    _realTimeMessaging.deliveryStatusStream.listen((status) {
      debugPrint('📊 Message delivery status: ${status.toString()}');
    });

    // Listen to typing indicators
    _realTimeMessaging.typingIndicatorStream.listen((data) {
      _typingIndicatorController.add(data);
    });

    // Listen to connection status
    _realTimeMessaging.connectionStatusStream.listen((status) {
      debugPrint('🔗 Connection status: $status');
    });
  }

  /// Get conversation messages stream
  Stream<List<MessageModel>> getConversationMessages({required String conversationId}) {
    return _simpleMessaging.getConversationMessages(conversationId);
  }

  /// Send a message with real-time delivery confirmation and error handling
  Future<String> sendMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
  }) async {
    final operationId = 'send_message_${conversationId}_${DateTime.now().millisecondsSinceEpoch}';
    
    return await _errorIntegration.executeOperation(
      operationId,
      () async {
        // Use real-time messaging service for enhanced delivery
        final messageId = await _realTimeMessaging.sendMessage(
          conversationId: conversationId,
          content: content,
          messageType: messageType,
          mediaUrls: mediaUrls,
          metadata: metadata,
        );

        // Create message status tracking
        await _createMessageStatus(messageId, conversationId);

        return messageId;
      },
      loadingMessage: 'Sending message...',
      successMessage: 'Message sent',
      errorMessage: 'Failed to send message',
      maxRetries: 3,
      requiresNetwork: true,
      context: {
        'conversationId': conversationId,
        'messageType': messageType.toString(),
        'contentLength': content.length,
        'hasMedia': mediaUrls?.isNotEmpty ?? false,
      },
    );
  }

  /// Create message status tracking record
  Future<void> _createMessageStatus(String messageId, String conversationId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      final messageStatus = MessageStatusModel(
        messageId: messageId,
        senderId: currentUser.uid,
        conversationId: conversationId,
        status: MessageStatus.sending,
        sentAt: DateTime.now(),
      );

      await _firestore
          .collection('message_status')
          .doc(messageId)
          .set(messageStatus.toFirestore());

      _messageStatusController.add(messageStatus);
    } catch (e) {
      debugPrint('❌ Error creating message status: $e');
    }
  }

  /// Edit a message
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'content': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error editing message: $e');
      rethrow;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  /// Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCounts.${currentUser.uid}': 0,
      });
    } catch (e) {
      debugPrint('❌ Error marking conversation as read: $e');
    }
  }

  /// Mark specific message as read with real-time confirmation
  Future<void> markMessageAsRead(String messageId) async {
    try {
      // Use real-time service for immediate read receipt
      await _realTimeMessaging.markMessageAsRead(messageId);

      // Update message status
      await _updateMessageStatus(messageId, MessageStatus.read);
    } catch (e) {
      debugPrint('❌ Error marking message as read: $e');
    }
  }

  /// Update message status
  Future<void> _updateMessageStatus(String messageId, MessageStatus status) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.value,
      };

      if (status == MessageStatus.delivered) {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      } else if (status == MessageStatus.read) {
        updateData['readAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('message_status')
          .doc(messageId)
          .update(updateData);

      // Get updated status and emit to stream
      final doc = await _firestore
          .collection('message_status')
          .doc(messageId)
          .get();
      
      if (doc.exists) {
        final messageStatus = MessageStatusModel.fromFirestore(doc);
        _messageStatusController.add(messageStatus);
      }
    } catch (e) {
      debugPrint('❌ Error updating message status: $e');
    }
  }

  /// Send typing indicator
  void sendTypingIndicator(String conversationId, bool isTyping) {
    _realTimeMessaging.sendTypingIndicator(conversationId, isTyping);
  }

  /// Join conversation room for real-time updates
  void joinConversationRoom(String conversationId) {
    _realTimeMessaging.joinConversationRoom(conversationId);
  }

  /// Leave conversation room
  void leaveConversationRoom(String conversationId) {
    _realTimeMessaging.leaveConversationRoom(conversationId);
  }

  /// Get message status
  Future<MessageStatusModel?> getMessageStatus(String messageId) async {
    try {
      final doc = await _firestore
          .collection('message_status')
          .doc(messageId)
          .get();
      
      if (doc.exists) {
        return MessageStatusModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting message status: $e');
      return null;
    }
  }

  /// Get message status stream for specific message
  Stream<MessageStatusModel?> getMessageStatusStream(String messageId) {
    return _firestore
        .collection('message_status')
        .doc(messageId)
        .snapshots()
        .map((doc) => doc.exists ? MessageStatusModel.fromFirestore(doc) : null);
  }

  /// Create a new conversation
  Future<String?> createConversation({
    required List<String> participantIds,
    required String name,
    ConversationType type = ConversationType.group,
  }) async {
    return await _simpleMessaging.createConversation(
      participantIds: participantIds,
      name: name,
      type: type,
    );
  }

  /// Search conversations
  Future<List<ConversationModel>> searchConversations(String query) async {
    return await _simpleMessaging.searchConversations(query);
  }

  /// Advanced search messages
  Future<List<MessageModel>> searchAdvancedMessages({
    required String query,
    List<String>? conversationIds,
    List<MessageType>? messageTypes,
    DateTime? startDate,
    DateTime? endDate,
    String? senderId,
    bool includeDeleted = false,
  }) async {
    return await _advancedMessaging.searchMessages(
      query: query,
      conversationIds: conversationIds,
      messageTypes: messageTypes,
      startDate: startDate,
      endDate: endDate,
      senderId: senderId,
      includeDeleted: includeDeleted,
    );
  }

  /// Smart search with AI
  Future<List<MessageModel>> smartSearch(String query) async {
    return await _advancedMessaging.smartSearch(query);
  }

  /// Translate message
  Future<String> translateMessage(String content, String targetLanguage) async {
    return await _advancedMessaging.translateMessage(content, targetLanguage);
  }

  /// Generate smart replies
  Future<List<String>> generateSmartReplies(String messageContent, {String? conversationContext}) async {
    return await _advancedMessaging.generateSmartReplies(messageContent, conversationContext: conversationContext);
  }

  /// Schedule a message
  Future<String?> scheduleMessage({
    required String conversationId,
    required String content,
    required DateTime scheduledAt,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
  }) async {
    return await _advancedMessaging.scheduleMessage(
      conversationId: conversationId,
      content: content,
      scheduledAt: scheduledAt,
      messageType: messageType,
      mediaUrls: mediaUrls,
    );
  }

  /// Get user conversations stream
  Stream<List<ConversationModel>> getUserConversations() {
    return _simpleMessaging.getUserConversations();
  }

  /// Get user messaging statistics
  Future<UserMessagingStats> getUserMessagingStats() async {
    return await _advancedMessaging.getUserMessagingStats();
  }

  /// Get conversation analytics
  Future<ConversationAnalytics> getConversationAnalytics(String conversationId) async {
    return await _advancedMessaging.getConversationAnalytics(conversationId);
  }

  // ==================== SEARCH FUNCTIONALITY ====================

  /// Search users globally with real-time filtering
  /// Requirements: 4.1, 4.2
  Future<UserSearchResult> searchUsers({
    required String query,
    UserSearchFilters? filters,
    int limit = 20,
  }) async {
    return await _searchService.searchUsers(
      query: query,
      filters: filters,
      limit: limit,
    );
  }

  /// Search messages with comprehensive filtering
  /// Requirements: 4.2, 4.3
  Future<MessageSearchResult> searchMessages({
    required String query,
    MessageSearchFilters? filters,
    int limit = 50,
  }) async {
    return await _searchService.searchMessages(
      query: query,
      filters: filters,
      limit: limit,
    );
  }

  /// Search within specific conversation
  /// Requirements: 4.2, 4.3
  Future<MessageSearchResult> searchInConversation({
    required String conversationId,
    required String query,
    MessageSearchFilters? filters,
    int limit = 50,
  }) async {
    return await _searchService.searchInConversation(
      conversationId: conversationId,
      query: query,
      filters: filters,
      limit: limit,
    );
  }

  /// Get search suggestions
  /// Requirements: 4.4, 4.5
  Future<List<String>> getSearchSuggestions(String query) async {
    return await _searchService.getSearchSuggestions(query);
  }

  /// Get search history
  /// Requirements: 4.6
  List<String> getSearchHistory() {
    return _searchService.getSearchHistory();
  }

  /// Save search for frequent use
  /// Requirements: 4.6
  Future<void> saveSearch(String name, String query) async {
    return await _searchService.saveSearch(name, query);
  }

  /// Get saved searches
  /// Requirements: 4.6
  Map<String, List<String>> getSavedSearches() {
    return _searchService.getSavedSearches();
  }

  /// Clear search history
  /// Requirements: 4.6
  Future<void> clearSearchHistory() async {
    return await _searchService.clearSearchHistory();
  }

  /// Get filtered users with advanced options
  /// Requirements: 4.3, 4.4
  Future<UserSearchResult> getFilteredUsers({
    required UserSearchFilters filters,
    int limit = 50,
  }) async {
    return await _searchService.getFilteredUsers(
      filters: filters,
      limit: limit,
    );
  }

  /// Get search result highlights for navigation
  /// Requirements: 4.4
  List<SearchHighlight> getSearchHighlights(String content, String query) {
    return _searchService.getSearchHighlights(content, query);
  }

  /// Get appropriate empty state message for search
  /// Requirements: 4.5
  String getSearchEmptyStateMessage(String query, {bool isUserSearch = true}) {
    return _searchService.getEmptyStateMessage(query, isUserSearch: isUserSearch);
  }

  /// Get search suggestions for empty state
  /// Requirements: 4.5
  List<String> getSearchEmptyStateSuggestions() {
    return _searchService.getEmptyStateSuggestions();
  }

  /// Get user search stream for real-time updates
  /// Requirements: 4.1, 4.2
  Stream<List<UserModel>> getUserSearchStream() {
    return _searchService.getUserSearchStream();
  }

  /// Get message search stream for real-time updates
  /// Requirements: 4.2, 4.3
  Stream<List<MessageModel>> getMessageSearchStream() {
    return _searchService.getMessageSearchStream();
  }

  /// Dispose of messaging service resources
  Future<void> dispose() async {
    try {
      // Dispose error integration first
      await _errorIntegration.dispose();
      
      // Dispose real-time messaging service
      await _realTimeMessaging.dispose();

      // Dispose search service
      await _searchService.dispose();

      // Close stream controllers
      await _messageStatusController.close();
      await _typingIndicatorController.close();

      debugPrint('✅ MessagingService: Disposed successfully');
    } catch (e) {
      debugPrint('❌ Error disposing messaging service: $e');
    }
  }

  /// Initiate voice call
  Future<CallSession?> initiateVoiceCall(String conversationId, List<String> participantIds) async {
    return await _advancedMessaging.initiateVoiceCall(conversationId, participantIds);
  }

  /// Initiate video call
  Future<CallSession?> initiateVideoCall(String conversationId, List<String> participantIds) async {
    return await _advancedMessaging.initiateVideoCall(conversationId, participantIds);
  }

  /// Answer call
  Future<bool> answerCall(String callId) async {
    return await _advancedMessaging.answerCall(callId);
  }

  /// End call
  Future<bool> endCall(String callId) async {
    return await _advancedMessaging.endCall(callId);
  }
}