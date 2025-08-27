// Notification Widget - Display individual notifications
// Part of Task 14: Build notification system

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/notification_model.dart';
import '../../core/theme/app_theme.dart';

class NotificationWidget extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool showDismissButton;
  final bool isCompact;
  
  const NotificationWidget({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
    this.showDismissButton = true,
    this.isCompact = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: notification.isRead ? 1 : 3,
      color: notification.isRead ? Colors.white : Colors.blue.shade50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification icon
              _buildNotificationIcon(),
              
              const SizedBox(width: 12),
              
              // Notification content
              Expanded(
                child: _buildNotificationContent(context),
              ),
              
              // Actions
              if (showDismissButton) _buildActions(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNotificationIcon() {
    final color = _getNotificationColor();
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          _getNotificationIcon(),
          color: color,
          size: 20,
        ),
      ),
    );
  }
  
  Widget _buildNotificationContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          notification.title,
          style: TextStyle(
            fontSize: isCompact ? 14 : 16,
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
            color: notification.isRead ? Colors.grey.shade700 : Colors.black87,
          ),
          maxLines: isCompact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // Body
        Text(
          notification.body,
          style: TextStyle(
            fontSize: isCompact ? 12 : 14,
            color: notification.isRead ? Colors.grey.shade600 : Colors.grey.shade800,
            height: 1.3,
          ),
          maxLines: isCompact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 8),
        
        // Metadata
        Row(
          children: [
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getNotificationColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _getNotificationColor().withOpacity(0.3),
                ),
              ),
              child: Text(
                notification.type.displayName,
                style: TextStyle(
                  fontSize: 10,
                  color: _getNotificationColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Time
            Text(
              notification.getTimeAgo(),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
            
            const Spacer(),
            
            // Unread indicator
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.talowaGreen,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        
        // Image if available
        if (notification.imageUrl != null && !isCompact) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: notification.imageUrl!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 120,
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 120,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildActions() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: Colors.grey.shade600,
      ),
      onSelected: (action) {
        switch (action) {
          case 'dismiss':
            onDismiss?.call();
            break;
          case 'mark_read':
            // TODO: Implement mark as read
            break;
          case 'mark_unread':
            // TODO: Implement mark as unread
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'dismiss',
          child: Row(
            children: [
              Icon(Icons.close, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              const Text('Dismiss'),
            ],
          ),
        ),
        PopupMenuItem(
          value: notification.isRead ? 'mark_unread' : 'mark_read',
          child: Row(
            children: [
              Icon(
                notification.isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(notification.isRead ? 'Mark as Unread' : 'Mark as Read'),
            ],
          ),
        ),
      ],
    );
  }
  
  IconData _getNotificationIcon() {
    switch (notification.type) {
      case NotificationType.postLike:
        return Icons.favorite;
      case NotificationType.postComment:
        return Icons.comment;
      case NotificationType.postShare:
        return Icons.share;
      case NotificationType.emergency:
        return Icons.warning;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.legalUpdate:
        return Icons.gavel;
      case NotificationType.successStory:
        return Icons.celebration;
      case NotificationType.networkUpdate:
        return Icons.group;
      case NotificationType.systemUpdate:
        return Icons.system_update;
      case NotificationType.newFollower:
        return Icons.person_add;
      case NotificationType.mentionInPost:
      case NotificationType.mentionInComment:
        return Icons.alternate_email;
      case NotificationType.campaignUpdate:
        return Icons.flag;
      case NotificationType.landRightsAlert:
        return Icons.landscape;
      case NotificationType.courtDateReminder:
        return Icons.event;
      case NotificationType.documentExpiry:
        return Icons.description;
      case NotificationType.meetingReminder:
        return Icons.meeting_room;
      default:
        return Icons.notifications;
    }
  }
  
  Color _getNotificationColor() {
    switch (notification.type) {
      case NotificationType.postLike:
        return Colors.red;
      case NotificationType.postComment:
        return Colors.blue;
      case NotificationType.postShare:
        return Colors.green;
      case NotificationType.emergency:
        return Colors.red.shade700;
      case NotificationType.announcement:
        return Colors.orange;
      case NotificationType.legalUpdate:
        return Colors.purple;
      case NotificationType.successStory:
        return Colors.green.shade600;
      case NotificationType.networkUpdate:
        return Colors.blue.shade600;
      case NotificationType.systemUpdate:
        return Colors.grey.shade600;
      case NotificationType.newFollower:
        return Colors.teal;
      case NotificationType.mentionInPost:
      case NotificationType.mentionInComment:
        return Colors.indigo;
      case NotificationType.campaignUpdate:
        return Colors.deepOrange;
      case NotificationType.landRightsAlert:
        return Colors.brown;
      case NotificationType.courtDateReminder:
        return Colors.amber.shade700;
      case NotificationType.documentExpiry:
        return Colors.red.shade600;
      case NotificationType.meetingReminder:
        return Colors.cyan;
      default:
        return AppTheme.talowaGreen;
    }
  }
}

/// Compact notification widget for in-app display
class CompactNotificationWidget extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  
  const CompactNotificationWidget({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon
                Icon(
                  _getNotificationIcon(),
                  color: _getNotificationColor(),
                  size: 20,
                ),
                
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 2),
                      
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Dismiss button
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  IconData _getNotificationIcon() {
    switch (notification.type) {
      case NotificationType.postLike:
        return Icons.favorite;
      case NotificationType.postComment:
        return Icons.comment;
      case NotificationType.postShare:
        return Icons.share;
      case NotificationType.emergency:
        return Icons.warning;
      case NotificationType.announcement:
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }
  
  Color _getNotificationColor() {
    switch (notification.type) {
      case NotificationType.postLike:
        return Colors.red;
      case NotificationType.postComment:
        return Colors.blue;
      case NotificationType.postShare:
        return Colors.green;
      case NotificationType.emergency:
        return Colors.red.shade700;
      case NotificationType.announcement:
        return Colors.orange;
      default:
        return AppTheme.talowaGreen;
    }
  }
}

/// Notification badge widget
class NotificationBadge extends StatelessWidget {
  final int count;
  final Widget child;
  final Color? badgeColor;
  final Color? textColor;
  final double? size;
  
  const NotificationBadge({
    super.key,
    required this.count,
    required this.child,
    this.badgeColor,
    this.textColor,
    this.size,
  });
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: BoxConstraints(
                minWidth: size ?? 16,
                minHeight: size ?? 16,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: (size ?? 16) * 0.6,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}