// Engagement Details Screen - Show who liked, shared, etc.
// Part of Task 7: Build post engagement interface

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../services/social_feed/index.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';

class EngagementDetailsScreen extends StatefulWidget {
  final PostModel post;
  final EngagementType initialTab;

  const EngagementDetailsScreen({
    super.key,
    required this.post,
    this.initialTab = EngagementType.likes,
  });

  @override
  State<EngagementDetailsScreen> createState() => _EngagementDetailsScreenState();
}

class _EngagementDetailsScreenState extends State<EngagementDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Data
  final Map<EngagementType, List<EngagementUser>> _engagementData = {};
  final Map<EngagementType, bool> _loadingStates = {};
  final Map<EngagementType, bool> _errorStates = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize tab controller
    final tabs = _getAvailableTabs();
    _tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: tabs.indexOf(widget.initialTab),
    );
    
    // Load initial data
    _loadEngagementData(widget.initialTab);
    
    // Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final currentTab = tabs[_tabController.index];
        _loadEngagementData(currentTab);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<EngagementType> _getAvailableTabs() {
    final tabs = <EngagementType>[];
    
    if (widget.post.likesCount > 0) tabs.add(EngagementType.likes);
    if (widget.post.commentsCount > 0) tabs.add(EngagementType.comments);
    if (widget.post.sharesCount > 0) tabs.add(EngagementType.shares);
    if (widget.post.viewsCount > 0) tabs.add(EngagementType.views);
    
    // Always show at least likes tab
    if (tabs.isEmpty) tabs.add(EngagementType.likes);
    
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _getAvailableTabs();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Engagement'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: tabs.map((type) => Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type.icon, size: 16),
                const SizedBox(width: 4),
                Text('${_getCount(type)}'),
              ],
            ),
          )).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabs.map((type) => _buildEngagementList(type)).toList(),
      ),
    );
  }

  Widget _buildEngagementList(EngagementType type) {
    final isLoading = _loadingStates[type] ?? false;
    final hasError = _errorStates[type] ?? false;
    final users = _engagementData[type] ?? [];

    if (isLoading && users.isEmpty) {
      return LoadingWidget(message: 'Loading ${type.displayName.toLowerCase()}...');
    }

    if (hasError && users.isEmpty) {
      return CustomErrorWidget(
        message: 'Failed to load ${type.displayName.toLowerCase()}',
        onRetry: () => _loadEngagementData(type),
      );
    }

    if (users.isEmpty) {
      return _buildEmptyState(type);
    }

    return RefreshIndicator(
      onRefresh: () => _loadEngagementData(type),
      color: AppTheme.talowaGreen,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return _buildUserTile(user, type);
        },
      ),
    );
  }

  Widget _buildEmptyState(EngagementType type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type.icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            'No ${type.displayName.toLowerCase()} yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            _getEmptyMessage(type),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(EngagementUser user, EngagementType type) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppTheme.talowaGreen,
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (user.role != null) ...[
            const SizedBox(width: 8),
            _buildRoleBadge(user.role!),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.location != null)
            Text(
              user.location!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          Text(
            _getEngagementTime(user, type),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
      trailing: _buildUserActions(user),
      onTap: () => _openUserProfile(user.id),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    String badgeText;
    
    if (role.contains('coordinator')) {
      badgeColor = AppTheme.talowaGreen;
      badgeText = 'Coordinator';
    } else if (role.contains('admin')) {
      badgeColor = Colors.red;
      badgeText = 'Admin';
    } else {
      badgeColor = Colors.blue;
      badgeText = 'Member';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildUserActions(EngagementUser user) {
    return PopupMenuButton<String>(
      onSelected: (action) => _handleUserAction(user, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view_profile',
          child: ListTile(
            leading: Icon(Icons.person),
            title: Text('View Profile'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'send_message',
          child: ListTile(
            leading: Icon(Icons.message),
            title: Text('Send Message'),
            dense: true,
          ),
        ),
      ],
    );
  }

  // Data loading
  Future<void> _loadEngagementData(EngagementType type) async {
    setState(() {
      _loadingStates[type] = true;
      _errorStates[type] = false;
    });

    try {
      // TODO: Implement actual API calls
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock data for now
      final users = _generateMockUsers(type);
      
      setState(() {
        _engagementData[type] = users;
        _loadingStates[type] = false;
      });
    } catch (e) {
      setState(() {
        _loadingStates[type] = false;
        _errorStates[type] = true;
      });
    }
  }

  // Helper methods
  int _getCount(EngagementType type) {
    switch (type) {
      case EngagementType.likes:
        return widget.post.likesCount;
      case EngagementType.comments:
        return widget.post.commentsCount;
      case EngagementType.shares:
        return widget.post.sharesCount;
      case EngagementType.views:
        return widget.post.viewsCount;
    }
  }

  String _getEmptyMessage(EngagementType type) {
    switch (type) {
      case EngagementType.likes:
        return 'Be the first to like this post';
      case EngagementType.comments:
        return 'No comments on this post yet';
      case EngagementType.shares:
        return 'This post hasn\'t been shared yet';
      case EngagementType.views:
        return 'No views recorded for this post';
    }
  }

  String _getEngagementTime(EngagementUser user, EngagementType type) {
    // TODO: Use actual engagement timestamp
    return '2 hours ago';
  }

  void _handleUserAction(EngagementUser user, String action) {
    switch (action) {
      case 'view_profile':
        _openUserProfile(user.id);
        break;
      case 'send_message':
        _sendMessage(user.id);
        break;
    }
  }

  void _openUserProfile(String userId) {
    // TODO: Navigate to user profile
    debugPrint('Opening profile for user: $userId');
  }

  void _sendMessage(String userId) {
    // TODO: Navigate to messaging
    debugPrint('Sending message to user: $userId');
  }

  // Mock data generation
  List<EngagementUser> _generateMockUsers(EngagementType type) {
    return List.generate(10, (index) => EngagementUser(
      id: 'user_$index',
      name: 'User ${index + 1}',
      role: index % 3 == 0 ? 'village_coordinator' : 'member',
      location: 'Village ${index + 1}',
      avatarUrl: null,
    ));
  }
}

enum EngagementType {
  likes('Likes', Icons.favorite),
  comments('Comments', Icons.comment),
  shares('Shares', Icons.share),
  views('Views', Icons.visibility);

  const EngagementType(this.displayName, this.icon);
  
  final String displayName;
  final IconData icon;
}

class EngagementUser {
  final String id;
  final String name;
  final String? role;
  final String? location;
  final String? avatarUrl;

  const EngagementUser({
    required this.id,
    required this.name,
    this.role,
    this.location,
    this.avatarUrl,
  });
}