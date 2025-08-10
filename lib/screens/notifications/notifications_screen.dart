// Notifications Screen - Display user notifications
// Part of Task 14: Build notification system

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../services/notifications/notification_service.dart';
import '../../widgets/notifications/notification_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  
  // State management
  List<NotificationModel> _allNotifications = [];
  List<NotificationModel> _unreadNotifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasMoreNotifications = true;
  DocumentSnapshot? _lastDocument;
  
  // Filter state
  NotificationType? _selectedTypeFilter;
  bool _showOnlyUnread = false;
  
  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    
    _loadNotifications();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Notifications'),
      backgroundColor: AppTheme.talowaGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Filter button
        IconButton(
          onPressed: _showFilterOptions,
          icon: Stack(
            children: [
              const Icon(Icons.filter_list),
              if (_hasActiveFilters())
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Filter',
        ),
        
        // Mark all as read
        IconButton(
          onPressed: _unreadNotifications.isNotEmpty ? _markAllAsRead : null,
          icon: const Icon(Icons.mark_email_read),
          tooltip: 'Mark All as Read',
        ),
        
        // More options
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text('Refresh'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 8),
                  Text('Notification Settings'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_all',
              child: Row(
                children: [
                  Icon(Icons.clear_all, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Clear All', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(
            text: 'All (${_allNotifications.length})',
          ),
          Tab(
            text: 'Unread (${_unreadNotifications.length})',
          ),
        ],
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading && _allNotifications.isEmpty) {
      return const LoadingWidget(message: 'Loading notifications...');
    }
    
    if (_hasError && _allNotifications.isEmpty) {
      return CustomErrorWidget(
        message: _errorMessage ?? 'Failed to load notifications',
        onRetry: _loadNotifications,
      );
    }
    
    return TabBarView(
      controller: _tabController,
      children: [
        // All notifications tab
        _buildNotificationsList(_allNotifications),
        
        // Unread notifications tab
        _buildNotificationsList(_unreadNotifications),
      ],
    );
  }
  
  Widget _buildNotificationsList(List<NotificationModel> notifications) {
    if (notifications.isEmpty) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      color: AppTheme.talowaGreen,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: notifications.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < notifications.length) {
            final notification = notifications[index];
            return NotificationWidget(
              notification: notification,
              onTap: () => _onNotificationTapped(notification),
              onDismiss: () => _dismissNotification(notification),
            );
          } else if (_isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return null;
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    final isUnreadTab = _tabController.index == 1;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUnreadTab ? Icons.mark_email_read : Icons.notifications_none,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              isUnreadTab ? 'All caught up!' : 'No notifications yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              isUnreadTab 
                  ? 'You have no unread notifications.'
                  : 'Notifications will appear here when you receive them.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (!isUnreadTab) ...[
              const SizedBox(height: AppTheme.spacingLarge),
              ElevatedButton.icon(
                onPressed: _refreshNotifications,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.talowaGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Event handlers
  
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      final notifications = await NotificationService.getUserNotifications(
        limit: 20,
      );
      
      setState(() {
        _allNotifications = notifications;
        _unreadNotifications = notifications.where((n) => !n.isRead).toList();
        _isLoading = false;
        _hasMoreNotifications = notifications.length == 20;
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }
  
  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMoreNotifications) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final moreNotifications = await NotificationService.getUserNotifications(
        limit: 20,
        lastDocument: _lastDocument,
      );
      
      setState(() {
        _allNotifications.addAll(moreNotifications);
        _unreadNotifications.addAll(moreNotifications.where((n) => !n.isRead));
        _isLoadingMore = false;
        _hasMoreNotifications = moreNotifications.length == 20;
      });
      
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more notifications: $e')),
        );
      }
    }
  }
  
  Future<void> _refreshNotifications() async {
    await _loadNotifications();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreNotifications();
    }
  }
  
  Future<void> _onNotificationTapped(NotificationModel notification) async {
    // Mark as read if not already read
    if (!notification.isRead) {
      await _markNotificationAsRead(notification);
    }
    
    // Navigate based on notification type
    _navigateBasedOnNotification(notification);
  }
  
  Future<void> _markNotificationAsRead(NotificationModel notification) async {
    try {
      await NotificationService.markNotificationAsRead(notification.id);
      
      setState(() {
        // Update the notification in both lists
        final allIndex = _allNotifications.indexWhere((n) => n.id == notification.id);
        if (allIndex != -1) {
          _allNotifications[allIndex] = notification.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }
        
        // Remove from unread list
        _unreadNotifications.removeWhere((n) => n.id == notification.id);
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark notification as read: $e')),
        );
      }
    }
  }
  
  Future<void> _markAllAsRead() async {
    try {
      await NotificationService.markAllNotificationsAsRead();
      
      setState(() {
        // Mark all notifications as read
        _allNotifications = _allNotifications.map((n) => n.copyWith(
          isRead: true,
          readAt: DateTime.now(),
        )).toList();
        
        // Clear unread list
        _unreadNotifications.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }
  
  Future<void> _dismissNotification(NotificationModel notification) async {
    try {
      await NotificationService.deleteNotification(notification.id);
      
      setState(() {
        _allNotifications.removeWhere((n) => n.id == notification.id);
        _unreadNotifications.removeWhere((n) => n.id == notification.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification dismissed'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to dismiss notification: $e')),
        );
      }
    }
  }
  
  void _navigateBasedOnNotification(NotificationModel notification) {
    // TODO: Implement navigation based on notification type and data
    switch (notification.type) {
      case NotificationType.postLike:
      case NotificationType.postComment:
      case NotificationType.postShare:
        // Navigate to post detail
        final postId = notification.data['postId'];
        if (postId != null) {
          // Navigator.pushNamed(context, '/post_detail', arguments: postId);
        }
        break;
      case NotificationType.emergency:
        // Navigate to emergency screen
        // Navigator.pushNamed(context, '/emergency');
        break;
      case NotificationType.announcement:
        // Navigate to announcement detail
        final announcementId = notification.data['announcementId'];
        if (announcementId != null) {
          // Navigator.pushNamed(context, '/announcement_detail', arguments: announcementId);
        }
        break;
      default:
        // Default action or no action
        break;
    }
  }
  
  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _refreshNotifications();
        break;
      case 'settings':
        _openNotificationSettings();
        break;
      case 'clear_all':
        _showClearAllDialog();
        break;
    }
  }
  
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildFilterBottomSheet(),
    );
  }
  
  Widget _buildFilterBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Filter Notifications',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _clearFilters();
                  Navigator.pop(context);
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          
          const Divider(),
          
          // Filter options
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type filter
                  const Text(
                    'Notification Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('All Types'),
                        selected: _selectedTypeFilter == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTypeFilter = null;
                          });
                        },
                      ),
                      ...NotificationType.values.map((type) => FilterChip(
                        label: Text(type.displayName),
                        selected: _selectedTypeFilter == type,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTypeFilter = selected ? type : null;
                          });
                        },
                      )),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Read status filter
                  SwitchListTile(
                    title: const Text('Show only unread'),
                    value: _showOnlyUnread,
                    onChanged: (value) {
                      setState(() {
                        _showOnlyUnread = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
  
  void _clearFilters() {
    setState(() {
      _selectedTypeFilter = null;
      _showOnlyUnread = false;
    });
    _applyFilters();
  }
  
  void _applyFilters() {
    // TODO: Implement filtering logic
    // For now, just refresh the notifications
    _refreshNotifications();
  }
  
  bool _hasActiveFilters() {
    return _selectedTypeFilter != null || _showOnlyUnread;
  }
  
  void _openNotificationSettings() {
    // TODO: Navigate to notification settings screen
    // Navigator.pushNamed(context, '/notification_settings');
  }
  
  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllNotifications();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _clearAllNotifications() async {
    try {
      // TODO: Implement clear all functionality
      // This would require a new method in NotificationService
      
      setState(() {
        _allNotifications.clear();
        _unreadNotifications.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear notifications: $e')),
        );
      }
    }
  }
}