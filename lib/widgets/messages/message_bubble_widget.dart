// Enhanced Message Bubble Widget for TALOWA Messaging
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/messaging/message_model.dart';

class MessageBubbleWidget extends StatefulWidget {
  final MessageModel message;
  final bool isCurrentUser;
  final bool showSenderName;
  final VoidCallback? onReply;
  final Function(String)? onReaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showDeliveryStatus;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.showSenderName = false,
    this.onReply,
    this.onReaction,
    this.onEdit,
    this.onDelete,
    this.showDeliveryStatus = true,
  });

  @override
  State<MessageBubbleWidget> createState() => _MessageBubbleWidgetState();
}

class _MessageBubbleWidgetState extends State<MessageBubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showReactions = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: widget.isCurrentUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isCurrentUser) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: GestureDetector(
              onLongPress: _showMessageOptions,
              onTap: () {
                if (_showReactions) {
                  setState(() {
                    _showReactions = false;
                  });
                  _animationController.reverse();
                }
              },
              child: Column(
                crossAxisAlignment: widget.isCurrentUser 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  // Sender name (for group chats)
                  if (widget.showSenderName && !widget.isCurrentUser) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        widget.message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getSenderColor(),
                        ),
                      ),
                    ),
                  ],
                  
                  // Message bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: _getBubbleColor(),
                      borderRadius: _getBorderRadius(),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Message content
                        _buildMessageContent(),
                        
                        // Message metadata (time, status)
                        _buildMessageMetadata(),
                        
                        // Reactions
                        if (widget.message.metadata['reactions'] != null)
                          _buildReactions(),
                      ],
                    ),
                  ),
                  
                  // Quick reactions overlay
                  if (_showReactions)
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildQuickReactions(),
                    ),
                ],
              ),
            ),
          ),
          
          if (widget.isCurrentUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: widget.isCurrentUser 
          ? AppTheme.talowaGreen 
          : Colors.grey[400],
      child: Text(
        widget.message.senderName.isNotEmpty 
            ? widget.message.senderName[0].toUpperCase() 
            : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reply indicator
          if (widget.message.metadata['replyTo'] != null)
            _buildReplyIndicator(),
          
          // Message text
          if (widget.message.content.isNotEmpty)
            SelectableText(
              widget.message.content,
              style: TextStyle(
                fontSize: 16,
                color: widget.isCurrentUser ? Colors.white : Colors.black87,
                height: 1.3,
              ),
            ),
          
          // Media content
          if (widget.message.mediaUrls.isNotEmpty)
            _buildMediaContent(),
          
          // System message styling
          if (widget.message.messageType == MessageType.system)
            _buildSystemMessage(),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator() {
    final replyData = widget.message.metadata['replyTo'] as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (widget.isCurrentUser ? Colors.white : AppTheme.talowaGreen)
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: widget.isCurrentUser ? Colors.white : AppTheme.talowaGreen,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyData['senderName'] ?? 'Unknown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isCurrentUser 
                  ? Colors.white70 
                  : AppTheme.talowaGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyData['content'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: widget.isCurrentUser 
                  ? Colors.white70 
                  : Colors.black54,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        children: widget.message.mediaUrls.map((url) {
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        widget.message.content,
        style: const TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: Colors.grey,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMessageMetadata() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edited indicator
          if (widget.message.isEdited) ...[
            Text(
              'edited',
              style: TextStyle(
                fontSize: 10,
                color: widget.isCurrentUser 
                    ? Colors.white60 
                    : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 4),
          ],
          
          // Timestamp
          Text(
            _formatMessageTime(widget.message.sentAt),
            style: TextStyle(
              fontSize: 11,
              color: widget.isCurrentUser 
                  ? Colors.white70 
                  : Colors.grey[600],
            ),
          ),
          
          // Delivery status (for sent messages)
          if (widget.isCurrentUser && widget.showDeliveryStatus) ...[
            const SizedBox(width: 4),
            _buildDeliveryStatus(),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryStatus() {
    IconData icon;
    Color color;

    // Check if message has been read by anyone OTHER than the sender
    final readByOthers = widget.message.readBy
        .where((userId) => userId != widget.message.senderId)
        .isNotEmpty;

    if (readByOthers) {
      // Message has been read by receiver - show blue double ticks
      icon = Icons.done_all;
      color = Colors.blue[300]!;
    } else if (widget.message.deliveredAt != null) {
      // Message delivered but not read - show grey double ticks
      icon = Icons.done_all;
      color = Colors.white70;
    } else {
      // Message sent but not delivered - show single grey tick
      icon = Icons.done;
      color = Colors.white70;
    }

    return Icon(
      icon,
      size: 14,
      color: color,
    );
  }

  Widget _buildReactions() {
    final reactions = Map<String, List<String>>.from(
      widget.message.metadata['reactions'] ?? {}
    );

    if (reactions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 4,
        children: reactions.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          
          return GestureDetector(
            onTap: () => widget.onReaction?.call(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  if (users.length > 1) ...[
                    const SizedBox(width: 2),
                    Text(
                      users.length.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickReactions() {
    const reactions = ['👍', '❤️', '😂', '😮', '😢', '😡'];
    
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.map((emoji) {
          return GestureDetector(
            onTap: () {
              widget.onReaction?.call(emoji);
              setState(() {
                _showReactions = false;
              });
              _animationController.reverse();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getBubbleColor() {
    if (widget.message.messageType == MessageType.system) {
      return Colors.grey[200]!;
    }
    return widget.isCurrentUser ? AppTheme.talowaGreen : Colors.grey[200]!;
  }

  BorderRadius _getBorderRadius() {
    return BorderRadius.circular(18).copyWith(
      bottomLeft: widget.isCurrentUser 
          ? const Radius.circular(18) 
          : const Radius.circular(4),
      bottomRight: widget.isCurrentUser 
          ? const Radius.circular(4) 
          : const Radius.circular(18),
    );
  }

  Color _getSenderColor() {
    // Generate consistent color based on sender name
    final hash = widget.message.senderName.hashCode;
    final colors = [
      Colors.red[600]!,
      Colors.blue[600]!,
      Colors.green[600]!,
      Colors.orange[600]!,
      Colors.purple[600]!,
      Colors.teal[600]!,
    ];
    return colors[hash.abs() % colors.length];
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

  void _showMessageOptions() {
    HapticFeedback.mediumImpact();
    
    if (widget.onReaction != null) {
      setState(() {
        _showReactions = true;
      });
      _animationController.forward();
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => MessageOptionsSheet(
        message: widget.message,
        isCurrentUser: widget.isCurrentUser,
        onReply: widget.onReply,
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
        onCopy: () => _copyMessage(),
      ),
    );
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Message Options Bottom Sheet
class MessageOptionsSheet extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;

  const MessageOptionsSheet({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Options
          if (onReply != null)
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply?.call();
              },
            ),
          
          if (onCopy != null)
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                onCopy?.call();
              },
            ),
          
          if (isCurrentUser && onEdit != null)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
          
          if (isCurrentUser && onDelete != null)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
        ],
      ),
    );
  }
}


