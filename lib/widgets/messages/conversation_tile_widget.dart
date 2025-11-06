// Conversation Tile Widget for Messages List
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/messaging/conversation_model.dart';

class ConversationTileWidget extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ConversationTileWidget({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation.getUnreadCount(currentUserId);
    final hasUnread = unreadCount > 0;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: _buildAvatar(),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.name,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.talowaGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation.lastMessage,
            style: TextStyle(
              color: hasUnread ? Colors.black87 : Colors.grey[600],
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _getConversationTypeIcon(),
                size: 12,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                _formatTime(conversation.lastMessageAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              if (conversation.type == ConversationType.group) ...[
                const SizedBox(width: 8),
                Text(
                  '${conversation.participantCount} members',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 24,
      backgroundColor: _getAvatarColor(),
      backgroundImage: conversation.avatarUrl != null 
          ? NetworkImage(conversation.avatarUrl!)
          : null,
      child: conversation.avatarUrl == null
          ? Text(
              _getAvatarText(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : null,
    );
  }

  Color _getAvatarColor() {
    switch (conversation.type) {
      case ConversationType.emergency:
        return Colors.red[600]!;
      case ConversationType.legalCase:
        return Colors.blue[600]!;
      case ConversationType.anonymous:
        return Colors.grey[600]!;
      case ConversationType.broadcast:
        return Colors.orange[600]!;
      default:
        return AppTheme.talowaGreen;
    }
  }

  String _getAvatarText() {
    if (conversation.name.isNotEmpty) {
      return conversation.name[0].toUpperCase();
    }
    return '?';
  }

  IconData _getConversationTypeIcon() {
    switch (conversation.type) {
      case ConversationType.direct:
        return Icons.person;
      case ConversationType.group:
        return Icons.group;
      case ConversationType.emergency:
        return Icons.emergency;
      case ConversationType.legalCase:
        return Icons.gavel;
      case ConversationType.anonymous:
        return Icons.visibility_off;
      case ConversationType.broadcast:
        return Icons.campaign;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}