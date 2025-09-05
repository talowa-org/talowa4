// Real-time Notification Widget - Live notification display
// Enhanced real-time features for TALOWA app

import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart' as AppDateUtils;
import '../../models/notification_model.dart';

/// Widget for displaying real-time notifications
class RealTimeNotificationWidget extends StatefulWidget {
  final bool showUnreadOnly;
  final int maxNotifications;
  final VoidCallback? onViewAll;
  final Function(NotificationModel)? onNotificationTap;
  
  const RealTimeNotificationWidget({
    super.key,
    this.showUnreadOnly = false,
    this.maxNotifications = 5,
    this.onViewAll,
    this.onNotificationTap,
  });
  
  @override
  State<RealTimeNotificationWidget> createState() => _RealTimeNotificationWidgetState();
}

class _RealTimeNotificationWidgetState extends State<RealTimeNotificationWidget>
    with TickerProviderStateMixin {
  
  // Stream subscriptions
  StreamSubscription<NotificationModel>? _notificationSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;
  
  // State
  final List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeNotifications();
  }
  
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    _bounceController.dispose();
    super.dispose();
  }
  
  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
  }
  
  Future<void> _initializeNotifications() async {
    try {
      // Set up notification stream
      _notificationSubscription = NotificationService.notificationStream?.listen(
        (notification) {
          _handleNewNotification(notification);
        },
      );
      
      // Set up unread count stream
      _unreadCountSubscription = NotificationService.unreadCountStream?.listen(
        (count) {
          if (mounted) {
            setState(() {
              _unreadCount = count;
            });
          }
        },
      );
      
      // Load initial notifications
      await _loadInitialNotifications();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _fadeController.forward();
      }
      
    } catch (e) {
      debugPrint('❌ RealTimeNotificationWidget: Initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadInitialNotifications() async {
    try {
      final notifications = await NotificationService.getRecentNotifications(
        limit: widget.maxNotifications,
      );
      
      if (mounted) {
        setState(() {
          _notifications.clear();
          _notifications.addAll(notifications);
        });
      }
      
    } catch (e) {
      debugPrint('❌ RealTimeNotificationWidget: Error loading notifications: $e');
    }
  }
  
  void _handleNewNotification(NotificationModel notification) {
    if (!mounted) return;
    
    // Filter based on widget settings
    if (widget.showUnreadOnly && notification.isRead) {
      return;
    }
    
    setState(() {
      _notifications.insert(0, notification);
      if (_notifications.length > widget.maxNotifications) {
        _notifications.removeLast();
      }
    });
    
    // Animate new notification
    _slideController.forward().then((_) {
      _slideController.reset();
    });
    
    // Bounce animation for unread count
    if (!notification.isRead) {
      _bounceController.forward().then((_) {
        _bounceController.reverse();
      });
    }
  }
  
  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    
    try {
      await NotificationService.markAsRead(notification.id);
      
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = notification.copyWith(isRead: true);
          }
        });
      }
      
    } catch (e) {
      debugPrint('❌ RealTimeNotificationWidget: Error marking as read: $e');
    }
  }
  
  Future<void> _markAllAsRead() async {
    try {
      await NotificationService.markAllAsRead();
      
      if (mounted) {
        setState(() {
          for (int i = 0; i < _notifications.length; i++) {
            _notifications[i] = _notifications[i].copyWith(isRead: true);
          }
        });
      }
      
    } catch (e) {
      debugPrint('❌ RealTimeNotificationWidget: Error marking all as read: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          
          const SizedBox(height: AppTheme.spacingMedium),
          
          // Notifications list
          _buildNotificationsList(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Icon(
                Icons.notifications,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: ScaleTransition(
                    scale: _bounceAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_unreadCount > 0)
                Text(
                  '$_unreadCount unread notifications',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Text(
                  'All caught up!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green[600],
                  ),
                ),
            ],
          ),
        ),
        if (_unreadCount > 0)
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Mark All Read'),
          ),
        if (widget.onViewAll != null)
          TextButton(
            onPressed: widget.onViewAll,
            child: const Text('View All'),
          ),
      ],
    );
  }
  
  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return SlideTransition(
          position: index == 0 ? _slideAnimation : 
              const AlwaysStoppedAnimation(Offset.zero),
          child: _buildNotificationItem(notification),
        );
      },
    );
  }
  
  Widget _buildNotificationItem(NotificationModel notification) {
    return GestureDetector(
      onTap: () {
        _markAsRead(notification);
        widget.onNotificationTap?.call(notification);
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: notification.isRead ? Colors.grey[200]! : Colors.blue[200]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Notification icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getNotificationColor(notification.type.toString().split('.').last).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _getNotificationIcon(notification.type.toString().split('.').last),
                color: _getNotificationColor(notification.type.toString().split('.').last),
                size: 20,
              ),
            ),
            
            const SizedBox(width: AppTheme.spacingMedium),
            
            // Notification content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(width: AppTheme.spacingSmall),
            
            // Timestamp and unread indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppDateUtils.DateUtils.formatRelativeTime(notification.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            widget.showUnreadOnly ? 'No unread notifications' : 'No notifications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            widget.showUnreadOnly 
                ? 'All your notifications have been read'
                : 'Notifications will appear here when you receive them',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'post':
        return Icons.article;
      case 'comment':
        return Icons.comment;
      case 'like':
        return Icons.favorite;
      case 'follow':
        return Icons.person_add;
      case 'mention':
        return Icons.alternate_email;
      case 'campaign':
        return Icons.campaign;
      case 'system':
        return Icons.info;
      case 'security':
        return Icons.security;
      default:
        return Icons.notifications;
    }
  }
  
  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'post':
        return Colors.blue;
      case 'comment':
        return Colors.green;
      case 'like':
        return Colors.red;
      case 'follow':
        return Colors.purple;
      case 'mention':
        return Colors.orange;
      case 'campaign':
        return Colors.indigo;
      case 'system':
        return Colors.grey;
      case 'security':
        return Colors.red;
      default:
        return AppTheme.primaryColor;
    }
  }
}

/// Compact notification bell widget with unread count
class NotificationBellWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showCount;
  
  const NotificationBellWidget({
    super.key,
    this.onTap,
    this.showCount = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Icon(
              Icons.notifications,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            if (showCount)
              StreamBuilder<int>(
                stream: NotificationService.unreadCountStream,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  
                  return Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

