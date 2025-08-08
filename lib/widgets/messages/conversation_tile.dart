// Conversation Tile Widget for Messages
// Reference: in-app-communication/ui-design-examples.md - Chat UI

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/messages/messages_screen.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAvatar(),
      title: Text(
        conversation.name,
        style: AppTheme.bodyLargeStyle.copyWith(
          fontWeight: conversation.unreadCount > 0 
              ? FontWeight.w600 
              : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        conversation.lastMessage,
        style: AppTheme.bodyStyle.copyWith(
          color: AppTheme.secondaryText,
          fontWeight: conversation.unreadCount > 0 
              ? FontWeight.w500 
              : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conversation.lastMessageTime),
            style: AppTheme.captionStyle.copyWith(
              color: conversation.unreadCount > 0 
                  ? AppTheme.talowaGreen 
                  : AppTheme.secondaryText,
              fontWeight: conversation.unreadCount > 0 
                  ? FontWeight.w600 
                  : FontWeight.normal,
            ),
          ),
          if (conversation.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: AppTheme.talowaGreen,
                shape: BoxShape.circle,
              ),
              child: Text(
                conversation.unreadCount > 99 
                    ? '99+' 
                    : conversation.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildAvatar() {
    Color avatarColor;
    IconData? avatarIcon;

    switch (conversation.type) {
      case ConversationType.emergency:
        avatarColor = AppTheme.emergencyRed;
        avatarIcon = Icons.emergency;
        break;
      case ConversationType.legalCase:
        avatarColor = AppTheme.legalBlue;
        avatarIcon = Icons.gavel;
        break;
      case ConversationType.anonymous:
        avatarColor = AppTheme.secondaryText;
        avatarIcon = Icons.privacy_tip;
        break;
      case ConversationType.group:
        avatarColor = AppTheme.talowaGreen;
        avatarIcon = Icons.group;
        break;
      default:
        avatarColor = AppTheme.talowaGreen;
        avatarIcon = null;
    }

    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: avatarColor,
          child: avatarIcon != null
              ? Icon(avatarIcon, color: Colors.white, size: 20)
              : Text(
                  conversation.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        if (conversation.isPinned)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppTheme.warningOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.push_pin,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}