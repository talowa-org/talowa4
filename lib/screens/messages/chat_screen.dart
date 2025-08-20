// Enhanced Chat Screen for TALOWA Messaging
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/message_model.dart';
import '../../services/messaging/messaging_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/messages/message_bubble_widget.dart';
import '../../widgets/messages/message_input_widget.dart';
import '../../widgets/messages/typing_indicator_widget.dart';
import '../../widgets/onboarding/contextual_tips_widget.dart';
import '../../widgets/onboarding/feature_discovery_widget.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ChatScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  MessageModel? _replyToMessage;
  List<String> _typingUsers = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markConversationAsRead();
    _setupTypingListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    TypingStatusManager.removeListener(widget.conversation.id);
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      MessagingService()
          .getConversationMessages(conversationId: widget.conversation.id)
          .listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages.reversed.toList(); // Reverse to show newest at bottom
            _isLoading = false;
          });
          _scrollToBottom();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> _markConversationAsRead() async {
    try {
      await MessagingService().markConversationAsRead(widget.conversation.id);
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  void _setupTypingListener() {
    TypingStatusManager.addListener(widget.conversation.id, (typingUsers) {
      setState(() {
        _typingUsers = typingUsers;
      });
    });
  }

  Future<void> _sendMessage(String content, {MessageType? messageType, List<String>? mediaUrls}) async {
    if (content.trim().isEmpty) return;

    try {
      Map<String, dynamic>? metadata;
      
      // Add reply metadata if replying to a message
      if (_replyToMessage != null) {
        metadata = {
          'replyTo': {
            'messageId': _replyToMessage!.id,
            'content': _replyToMessage!.content,
            'senderName': _replyToMessage!.senderName,
          }
        };
      }

      await MessagingService().sendMessage(
        conversationId: widget.conversation.id,
        content: content,
        messageType: messageType ?? MessageType.text,
        mediaUrls: mediaUrls,
        metadata: metadata,
      );

      // Clear reply state
      if (_replyToMessage != null) {
        setState(() {
          _replyToMessage = null;
        });
      }

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setReplyToMessage(MessageModel message) {
    setState(() {
      _replyToMessage = message;
    });
  }

  void _addReaction(MessageModel message, String emoji) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // TODO: Implement reaction functionality in messaging service
      // For now, just show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added reaction: $emoji'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('Error adding reaction: $e');
    }
  }

  void _editMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => EditMessageDialog(
        message: message,
        onSave: (newContent) async {
          try {
            await MessagingService().editMessage(
              messageId: message.id,
              newContent: newContent,
            );
            Navigator.pop(context);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to edit message: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _deleteMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await MessagingService().deleteMessage(message.id);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete message: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startTyping() {
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      TypingStatusManager.startTyping(
        widget.conversation.id,
        currentUser.uid,
        'You', // This would be the current user's name
      );
    }
  }

  void _stopTyping() {
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      TypingStatusManager.stopTyping(
        widget.conversation.id,
        currentUser.uid,
        'You',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (widget.conversation.type == ConversationType.group)
              Text(
                '${widget.conversation.participantCount} members',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        actions: [
          if (widget.conversation.type == ConversationType.direct)
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: _makeCall,
              tooltip: 'Voice Call',
            ),
          if (widget.conversation.type == ConversationType.direct)
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: _makeVideoCall,
              tooltip: 'Video Call',
            ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 8),
                    Text('Conversation Info'),
                  ],
                ),
              ),
              if (widget.conversation.type == ConversationType.group)
                const PopupMenuItem(
                  value: 'add_member',
                  child: Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 8),
                      Text('Add Member'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final isCurrentUser = message.senderId == AuthService.currentUser?.uid;
                                final showSenderName = widget.conversation.type == ConversationType.group && !isCurrentUser;
                                
                                return MessageBubbleWidget(
                                  message: message,
                                  isCurrentUser: isCurrentUser,
                                  showSenderName: showSenderName,
                                  onReply: () => _setReplyToMessage(message),
                                  onReaction: (emoji) => _addReaction(message, emoji),
                                  onEdit: isCurrentUser ? () => _editMessage(message) : null,
                                  onDelete: isCurrentUser ? () => _deleteMessage(message) : null,
                                );
                              },
                            ),
                          ),
                          
                          // Typing indicator
                          TypingIndicatorWidget(
                            typingUsers: _typingUsers,
                            isVisible: _typingUsers.isNotEmpty,
                          ),
                        ],
                      ),
          ),
          
          // Message input
          MessageInputWidget(
            onSendMessage: _sendMessage,
            onStartTyping: _startTyping,
            onStopTyping: _stopTyping,
            replyToMessage: _replyToMessage,
            onCancelReply: () => setState(() => _replyToMessage = null),
            isEnabled: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation by sending a message',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }





  void _makeCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice calling feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _makeVideoCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video calling feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }



  void _handleMenuAction(String action) {
    switch (action) {
      case 'info':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation info feature coming soon!')),
        );
        break;
      case 'add_member':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add member feature coming soon!')),
        );
        break;
      case 'clear_chat':
        _showClearChatDialog();
        break;
    }
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clear chat feature coming soon!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Edit Message Dialog
class EditMessageDialog extends StatefulWidget {
  final MessageModel message;
  final Function(String) onSave;

  const EditMessageDialog({
    super.key,
    required this.message,
    required this.onSave,
  });

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Message'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Enter your message...',
          border: OutlineInputBorder(),
        ),
        maxLines: null,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveMessage,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  void _saveMessage() async {
    final newContent = _controller.text.trim();
    if (newContent.isEmpty || newContent == widget.message.content) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      widget.onSave(newContent);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}