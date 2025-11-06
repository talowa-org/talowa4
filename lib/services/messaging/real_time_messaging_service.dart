// Real-time Messaging Service for TALOWA
// Implements WebSocket-based messaging with delivery confirmation
// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 7.1, 7.3

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../models/messaging/message_model.dart';

import '../auth_service.dart';
import 'message_error_handler.dart';

/// Message delivery status enum
enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// Message retry configuration
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });
}

/// Real-time messaging service with WebSocket support
class RealTimeMessagingService {
  static final RealTimeMessagingService _instance = RealTimeMessagingService._internal();
  factory RealTimeMessagingService() => _instance;
  RealTimeMessagingService._internal();

  // Firebase Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Socket.IO client
  IO.Socket? _socket;
  
  // Connection state
  bool _isConnected = false;
  bool _isInitialized = false;
  String? _currentUserId;
  
  // Stream controllers for real-time updates
  final StreamController<MessageModel> _messageStreamController = 
      StreamController<MessageModel>.broadcast();
  final StreamController<MessageDeliveryStatus> _deliveryStatusController = 
      StreamController<MessageDeliveryStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _typingIndicatorController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionStatusController = 
      StreamController<String>.broadcast();
  
  // Error handler
  final MessageErrorHandler _errorHandler = MessageErrorHandler();
  
  // Message queues and retry logic
  final Map<String, MessageModel> _pendingMessages = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, int> _retryAttempts = {};
  final RetryConfig _retryConfig = const RetryConfig();
  
  // Typing indicators
  final Map<String, Timer> _typingTimers = {};
  
  // Getters for streams
  Stream<MessageModel> get messageStream => _messageStreamController.stream;
  Stream<MessageDeliveryStatus> get deliveryStatusStream => _deliveryStatusController.stream;
  Stream<Map<String, dynamic>> get typingIndicatorStream => _typingIndicatorController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;
  Stream<MessageError> get errorStream => _errorHandler.errorStream;
  
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;

  /// Initialize the real-time messaging service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      _currentUserId = currentUser.uid;
      
      // Initialize WebSocket connection
      await _initializeSocket();
      
      // Set up Firestore listeners for fallback
      _setupFirestoreListeners();
      
      _isInitialized = true;
      debugPrint('✅ RealTimeMessagingService: Initialized successfully');
      
    } catch (e) {
      final error = _errorHandler.handleError(e, context: {'action': 'initialization'});
      debugPrint('❌ RealTimeMessagingService: Initialization error: $e');
      throw Exception(error.userFriendlyMessage);
    }
  }

  /// Initialize Socket.IO connection
  Future<void> _initializeSocket() async {
    try {
      // Configure Socket.IO client
      _socket = IO.io(
        'https://your-socket-server.com', // Replace with your actual server URL
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setAuth({
              'userId': _currentUserId,
              'token': await AuthService.currentUser?.getIdToken(),
            })
            .build(),
      );

      // Set up socket event listeners
      _setupSocketListeners();
      
      // Connect to socket
      _socket?.connect();
      
    } catch (e) {
      debugPrint('❌ RealTimeMessagingService: Socket initialization error: $e');
      // Fall back to Firestore-only mode
      _isConnected = false;
    }
  }

  /// Set up Socket.IO event listeners
  void _setupSocketListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      debugPrint('🔗 Socket connected');
      _isConnected = true;
      _connectionStatusController.add('connected');
      
      // Join user's personal room for direct messages
      _socket!.emit('join_user_room', {'userId': _currentUserId});
      
      // Process any pending messages
      _processPendingMessages();
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 Socket disconnected');
      _isConnected = false;
      _connectionStatusController.add('disconnected');
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ Socket connection error: $error');
      _isConnected = false;
      _connectionStatusController.add('error');
    });

    // Message events
    _socket!.on('new_message', (data) {
      _handleIncomingMessage(data);
    });

    _socket!.on('message_delivered', (data) {
      _handleMessageDelivered(data);
    });

    _socket!.on('message_read', (data) {
      _handleMessageRead(data);
    });

    _socket!.on('typing_indicator', (data) {
      _handleTypingIndicator(data);
    });

    // Error events
    _socket!.on('error', (error) {
      debugPrint('❌ Socket error: $error');
      _handleSocketError(error);
    });
  }

  /// Set up Firestore listeners as fallback
  void _setupFirestoreListeners() {
    // Listen to messages in conversations where user is a participant
    _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: _currentUserId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final message = MessageModel.fromFirestore(change.doc);
                _messageStreamController.add(message);
                
                // Send delivery confirmation
                _sendDeliveryConfirmation(message.id);
              }
            }
          },
          onError: (error) {
            debugPrint('❌ Firestore listener error: $error');
          },
        );
  }

  /// Send a message with real-time delivery
  Future<String> sendMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique message ID
      final messageId = _firestore.collection('messages').doc().id;
      final clientMessageId = '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}';

      // Create message model
      final message = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: _currentUserId!,
        senderName: AuthService.currentUser?.displayName ?? 'User',
        content: content,
        messageType: messageType,
        mediaUrls: mediaUrls ?? [],
        sentAt: DateTime.now(),
        readBy: [],
        isEdited: false,
        isDeleted: false,
        metadata: {
          ...?metadata,
          'clientMessageId': clientMessageId,
        },
      );

      // Update delivery status to sending
      _deliveryStatusController.add(MessageDeliveryStatus.sending);

      // Try to send via WebSocket first
      if (_isConnected && _socket != null) {
        await _sendMessageViaSocket(message);
      } else {
        // Fall back to Firestore
        await _sendMessageViaFirestore(message);
      }

      // Add to pending messages for retry logic
      _pendingMessages[messageId] = message;
      _startRetryTimer(messageId);

      return messageId;

    } catch (e) {
      final error = _errorHandler.handleError(e, context: {'action': 'sending_message'});
      debugPrint('❌ Error sending message: $e');
      _deliveryStatusController.add(MessageDeliveryStatus.failed);
      throw Exception(error.userFriendlyMessage);
    }
  }

  /// Send message via WebSocket
  Future<void> _sendMessageViaSocket(MessageModel message) async {
    try {
      _socket!.emit('send_message', {
        'messageId': message.id,
        'conversationId': message.conversationId,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'content': message.content,
        'messageType': message.messageType.value,
        'mediaUrls': message.mediaUrls,
        'timestamp': message.sentAt.toIso8601String(),
        'metadata': message.metadata,
      });

      _deliveryStatusController.add(MessageDeliveryStatus.sent);

    } catch (e) {
      _errorHandler.handleError(e, context: {'action': 'socket_send'});
      debugPrint('❌ Error sending message via socket: $e');
      // Fall back to Firestore
      await _sendMessageViaFirestore(message);
    }
  }

  /// Send message via Firestore (fallback)
  Future<void> _sendMessageViaFirestore(MessageModel message) async {
    try {
      // Save message to Firestore
      await _firestore
          .collection('messages')
          .doc(message.id)
          .set(message.toFirestore());

      // Update conversation
      await _updateConversationLastMessage(message);

      _deliveryStatusController.add(MessageDeliveryStatus.sent);

    } catch (e) {
      final error = _errorHandler.handleError(e, context: {'action': 'firestore_send'});
      debugPrint('❌ Error sending message via Firestore: $e');
      _deliveryStatusController.add(MessageDeliveryStatus.failed);
      throw Exception(error.userFriendlyMessage);
    }
  }

  /// Update conversation with last message
  Future<void> _updateConversationLastMessage(MessageModel message) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(message.conversationId)
          .update({
        'lastMessage': message.content,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': message.senderId,
      });
    } catch (e) {
      debugPrint('❌ Error updating conversation: $e');
    }
  }

  /// Handle incoming message from WebSocket
  void _handleIncomingMessage(dynamic data) {
    try {
      final messageData = data as Map<String, dynamic>;
      
      final message = MessageModel(
        id: messageData['messageId'] ?? '',
        conversationId: messageData['conversationId'] ?? '',
        senderId: messageData['senderId'] ?? '',
        senderName: messageData['senderName'] ?? 'Unknown User',
        content: messageData['content'] ?? '',
        messageType: MessageTypeExtension.fromString(messageData['messageType'] ?? 'text'),
        mediaUrls: List<String>.from(messageData['mediaUrls'] ?? []),
        sentAt: DateTime.parse(messageData['timestamp'] ?? DateTime.now().toIso8601String()),
        readBy: [],
        isEdited: false,
        isDeleted: false,
        metadata: Map<String, dynamic>.from(messageData['metadata'] ?? {}),
      );

      _messageStreamController.add(message);

      // Send delivery confirmation
      _sendDeliveryConfirmation(message.id);

    } catch (e) {
      debugPrint('❌ Error handling incoming message: $e');
    }
  }

  /// Send delivery confirmation
  void _sendDeliveryConfirmation(String messageId) {
    if (_isConnected && _socket != null) {
      _socket!.emit('message_delivered', {
        'messageId': messageId,
        'userId': _currentUserId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Handle message delivered confirmation
  void _handleMessageDelivered(dynamic data) {
    try {
      final messageId = data['messageId'] as String;
      
      // Remove from pending messages
      _pendingMessages.remove(messageId);
      _cancelRetryTimer(messageId);
      
      _deliveryStatusController.add(MessageDeliveryStatus.delivered);

      // Update message status in Firestore
      _updateMessageStatus(messageId, 'delivered');

    } catch (e) {
      debugPrint('❌ Error handling message delivered: $e');
    }
  }

  /// Handle message read confirmation
  void _handleMessageRead(dynamic data) {
    try {
      final messageId = data['messageId'] as String;
      final userId = data['userId'] as String;
      
      _deliveryStatusController.add(MessageDeliveryStatus.read);

      // Update message read status in Firestore
      _updateMessageReadStatus(messageId, userId);

    } catch (e) {
      debugPrint('❌ Error handling message read: $e');
    }
  }

  /// Update message status in Firestore
  Future<void> _updateMessageStatus(String messageId, String status) async {
    try {
      await _firestore
          .collection('messages')
          .doc(messageId)
          .update({
        'status': status,
        '${status}At': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating message status: $e');
    }
  }

  /// Update message read status in Firestore
  Future<void> _updateMessageReadStatus(String messageId, String userId) async {
    try {
      await _firestore
          .collection('messages')
          .doc(messageId)
          .update({
        'readBy': FieldValue.arrayUnion([userId]),
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating message read status: $e');
    }
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      if (_currentUserId == null) return;

      // Send read receipt via WebSocket
      if (_isConnected && _socket != null) {
        _socket!.emit('message_read', {
          'messageId': messageId,
          'userId': _currentUserId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Update in Firestore
      await _updateMessageReadStatus(messageId, _currentUserId!);

    } catch (e) {
      debugPrint('❌ Error marking message as read: $e');
    }
  }

  /// Send typing indicator
  void sendTypingIndicator(String conversationId, bool isTyping) {
    if (_isConnected && _socket != null && _currentUserId != null) {
      _socket!.emit('typing_indicator', {
        'conversationId': conversationId,
        'userId': _currentUserId,
        'isTyping': isTyping,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Auto-stop typing after 3 seconds
      if (isTyping) {
        _typingTimers[conversationId]?.cancel();
        _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
          sendTypingIndicator(conversationId, false);
        });
      }
    }
  }

  /// Handle typing indicator
  void _handleTypingIndicator(dynamic data) {
    try {
      final typingData = data as Map<String, dynamic>;
      _typingIndicatorController.add(typingData);
    } catch (e) {
      debugPrint('❌ Error handling typing indicator: $e');
    }
  }

  /// Start retry timer for message delivery
  void _startRetryTimer(String messageId) {
    _retryAttempts[messageId] = 0;
    _scheduleRetry(messageId);
  }

  /// Schedule retry with exponential backoff
  void _scheduleRetry(String messageId) {
    final attempts = _retryAttempts[messageId] ?? 0;
    
    if (attempts >= _retryConfig.maxRetries) {
      // Max retries reached, mark as failed
      _pendingMessages.remove(messageId);
      _retryAttempts.remove(messageId);
      _deliveryStatusController.add(MessageDeliveryStatus.failed);
      return;
    }

    // Calculate delay with exponential backoff
    final delay = Duration(
      milliseconds: min(
        _retryConfig.initialDelay.inMilliseconds * 
            pow(_retryConfig.backoffMultiplier, attempts).round(),
        _retryConfig.maxDelay.inMilliseconds,
      ),
    );

    _retryTimers[messageId] = Timer(delay, () async {
      await _retryMessage(messageId);
    });
  }

  /// Retry sending a message
  Future<void> _retryMessage(String messageId) async {
    final message = _pendingMessages[messageId];
    if (message == null) return;

    try {
      _retryAttempts[messageId] = (_retryAttempts[messageId] ?? 0) + 1;
      
      debugPrint('🔄 Retrying message $messageId (attempt ${_retryAttempts[messageId]})');

      if (_isConnected && _socket != null) {
        await _sendMessageViaSocket(message);
      } else {
        await _sendMessageViaFirestore(message);
      }

    } catch (e) {
      debugPrint('❌ Retry failed for message $messageId: $e');
      _scheduleRetry(messageId); // Schedule next retry
    }
  }

  /// Cancel retry timer
  void _cancelRetryTimer(String messageId) {
    _retryTimers[messageId]?.cancel();
    _retryTimers.remove(messageId);
    _retryAttempts.remove(messageId);
  }

  /// Process pending messages when connection is restored
  void _processPendingMessages() {
    for (final messageId in _pendingMessages.keys.toList()) {
      _retryMessage(messageId);
    }
  }

  /// Handle socket errors
  void _handleSocketError(dynamic error) {
    debugPrint('❌ Socket error: $error');
    
    // Implement error-specific handling
    if (error.toString().contains('authentication')) {
      // Re-authenticate and reconnect
      _reconnectWithAuth();
    } else if (error.toString().contains('rate_limit')) {
      // Implement rate limiting backoff
      _handleRateLimit();
    }
  }

  /// Reconnect with authentication
  Future<void> _reconnectWithAuth() async {
    try {
      final token = await AuthService.currentUser?.getIdToken(true);
      _socket?.auth = {'userId': _currentUserId, 'token': token};
      _socket?.connect();
    } catch (e) {
      debugPrint('❌ Error reconnecting with auth: $e');
    }
  }

  /// Handle rate limiting
  void _handleRateLimit() {
    // Implement exponential backoff for rate limiting
    Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        _socket?.connect();
      }
    });
  }

  /// Join conversation room
  void joinConversationRoom(String conversationId) {
    if (_isConnected && _socket != null) {
      _socket!.emit('join_conversation', {'conversationId': conversationId});
    }
  }

  /// Leave conversation room
  void leaveConversationRoom(String conversationId) {
    if (_isConnected && _socket != null) {
      _socket!.emit('leave_conversation', {'conversationId': conversationId});
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    debugPrint('🔄 RealTimeMessagingService: Disposing...');

    // Cancel all timers
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();

    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();

    // Disconnect socket
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    // Close stream controllers
    await _messageStreamController.close();
    await _deliveryStatusController.close();
    await _typingIndicatorController.close();
    await _connectionStatusController.close();

    // Clear state
    _pendingMessages.clear();
    _retryAttempts.clear();
    _isConnected = false;
    _isInitialized = false;
    _currentUserId = null;

    debugPrint('✅ RealTimeMessagingService: Disposed successfully');
  }
}