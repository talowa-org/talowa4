// Example usage of Real-time Messaging Service
// Demonstrates how to implement messaging with delivery confirmation

import 'package:flutter/material.dart';
import '../services/messaging/messaging_service.dart';
import '../models/messaging/message_model.dart';
import '../models/messaging/message_status_model.dart';
import '../widgets/messaging/message_status_indicator.dart';

class MessagingExample extends StatefulWidget {
  final String conversationId;
  
  const MessagingExample({
    super.key,
    required this.conversationId,
  });

  @override
  State<MessagingExample> createState() => _MessagingExampleState();
}

class _MessagingExampleState extends State<MessagingExample> {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _messageController = TextEditingController();
  final List<MessageModel> _messages = [];
  final Map<String, MessageStatusModel?> _messageStatuses = {};
  bool _isTyping = false;
  String _connectionStatus = 'disconnected';

  @override
  void initState() {
    super.initState();
    _initializeMessaging();
  }

  Future<void> _initializeMessaging() async {
    try {
      // Initialize messaging service
      await _messagingService.initialize();
      
      // Join conversation room for real-time updates
      _messagingService.joinConversationRoom(widget.conversationId);
      
      // Listen to incoming messages
      _messagingService.messageStream.listen((message) {
        if (mounted) {
          setState(() {
            _messages.add(message);
          });
        }
      });

      // Listen to delivery status updates
      _messagingService.deliveryStatusStream.listen((status) {
        debugPrint('📊 Delivery status: $status');
      });

      // Listen to message status updates
      _messagingService.messageStatusStream.listen((status) {
        if (mounted) {
          setState(() {
            _messageStatuses[status.messageId] = status;
          });
        }
      });

      // Listen to typing indicators
      _messagingService.typingIndicatorStream.listen((data) {
        // Handle typing indicators
        debugPrint('👀 Typing indicator: $data');
      });

      // Listen to connection status
      _messagingService.connectionStatusStream.listen((status) {
        if (mounted) {
          setState(() {
            _connectionStatus = status;
          });
        }
      });

    } catch (e) {
      debugPrint('❌ Error initializing messaging: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize messaging: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      // Clear input
      _messageController.clear();
      
      // Stop typing indicator
      _messagingService.sendTypingIndicator(widget.conversationId, false);
      setState(() {
        _isTyping = false;
      });

      // Send message
      final messageId = await _messagingService.sendMessage(
        conversationId: widget.conversationId,
        content: content,
        messageType: MessageType.text,
      );

      debugPrint('✅ Message sent with ID: $messageId');

    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onTextChanged(String text) {
    final isCurrentlyTyping = text.isNotEmpty;
    
    if (isCurrentlyTyping != _isTyping) {
      setState(() {
        _isTyping = isCurrentlyTyping;
      });
      
      // Send typing indicator
      _messagingService.sendTypingIndicator(widget.conversationId, isCurrentlyTyping);
    }
  }

  @override
  void dispose() {
    // Leave conversation room
    _messagingService.leaveConversationRoom(widget.conversationId);
    
    // Dispose controller
    _messageController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Messaging'),
        subtitle: Text('Status: $_connectionStatus'),
        backgroundColor: _getConnectionColor(),
      ),
      body: Column(
        children: [
          // Connection status indicator
          if (_connectionStatus != 'connected')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    _connectionStatus == 'connecting' 
                        ? Icons.sync 
                        : Icons.wifi_off,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _connectionStatus == 'connecting' 
                        ? 'Connecting...' 
                        : 'Offline - Messages will be sent when connected',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                final status = _messageStatuses[message.id];
                
                return _buildMessageBubble(message, status);
              },
            ),
          ),

          // Typing indicator
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: TypingIndicator(typingUsers: ['You']),
            ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, MessageStatusModel? status) {
    const isOwnMessage = true; // In real app, check if message.senderId == currentUserId
    
    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isOwnMessage 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isOwnMessage 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.sentAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: (isOwnMessage 
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant)
                        .withOpacity(0.7),
                  ),
                ),
                if (isOwnMessage && status != null) ...[
                  const SizedBox(width: 4),
                  MessageStatusIndicator(
                    status: status.status,
                    isRead: status.isRead,
                    deliveredAt: status.deliveredAt,
                    readAt: status.readAt,
                    readColor: Theme.of(context).colorScheme.onPrimary,
                    deliveredColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                    sentColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
                    failedColor: Colors.red,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getConnectionColor() {
    switch (_connectionStatus) {
      case 'connected':
        return Colors.green;
      case 'connecting':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}

/// Example of how to use the messaging service in a simple chat app
class SimpleChatExample extends StatelessWidget {
  const SimpleChatExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TALOWA Messaging Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MessagingExample(
        conversationId: 'example_conversation_id',
      ),
    );
  }
}