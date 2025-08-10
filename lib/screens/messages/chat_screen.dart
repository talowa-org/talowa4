// Chat Screen for TALOWA Messaging
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/message_model.dart';
import '../../services/messaging/messaging_service.dart';
import '../../services/auth_service.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markConversationAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await MessagingService().sendMessage(
        conversationId: widget.conversation.id,
        content: content,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
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
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isCurrentUser = message.senderId == AuthService.currentUser?.uid;
                          
                          return _buildMessageBubble(message, isCurrentUser);
                        },
                      ),
          ),
          
          // Message input
          _buildMessageInput(),
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

  Widget _buildMessageBubble(MessageModel message, bool isCurrentUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.talowaGreen,
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser ? AppTheme.talowaGreen : Colors.grey[200],
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: isCurrentUser ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isCurrentUser ? const Radius.circular(4) : const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser && widget.conversation.type == ConversationType.group) ...[
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.talowaGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      color: isCurrentUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.sentAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.readBy.isNotEmpty ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.readBy.isNotEmpty ? Colors.blue[300] : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(
                Icons.person,
                size: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: AppTheme.talowaGreen),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _attachFile,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          
          const SizedBox(width: 8),
          
          FloatingActionButton(
            onPressed: _isSending ? null : _sendMessage,
            backgroundColor: AppTheme.talowaGreen,
            foregroundColor: Colors.white,
            mini: true,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
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

  void _attachFile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File attachment feature coming soon!'),
        backgroundColor: Colors.orange,
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