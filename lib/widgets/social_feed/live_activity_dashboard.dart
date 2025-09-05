// Live Activity Dashboard Widget - Real-time activity display
// Enhanced real-time features for TALOWA app

import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/social_feed/live_activity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart' as AppDateUtils;

/// Widget for displaying live activity dashboard
class LiveActivityDashboard extends StatefulWidget {
  final bool showStats;
  final bool showRecentActivities;
  final int maxActivities;
  final VoidCallback? onViewAll;
  
  const LiveActivityDashboard({
    super.key,
    this.showStats = true,
    this.showRecentActivities = true,
    this.maxActivities = 10,
    this.onViewAll,
  });
  
  @override
  State<LiveActivityDashboard> createState() => _LiveActivityDashboardState();
}

class _LiveActivityDashboardState extends State<LiveActivityDashboard>
    with TickerProviderStateMixin {
  
  // Stream subscriptions
  StreamSubscription<LiveActivity>? _activitySubscription;
  StreamSubscription<Map<String, int>>? _countsSubscription;
  StreamSubscription<List<LiveActivity>>? _feedSubscription;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  // State
  final List<LiveActivity> _recentActivities = [];
  Map<String, int> _activityCounts = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeDashboard();
  }
  
  @override
  void dispose() {
    _activitySubscription?.cancel();
    _countsSubscription?.cancel();
    _feedSubscription?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }
  
  Future<void> _initializeDashboard() async {
    try {
      // Initialize live activity service
      await LiveActivityService.initialize();
      
      // Set up activity stream
      _activitySubscription = LiveActivityService.activityStream.listen(
        (activity) {
          _handleNewActivity(activity);
        },
      );
      
      // Set up counts stream
      _countsSubscription = LiveActivityService.activityCountsStream.listen(
        (counts) {
          if (mounted) {
            setState(() {
              _activityCounts = counts;
            });
          }
        },
      );
      
      // Load initial data
      await _loadInitialData();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
    } catch (e) {
      debugPrint('❌ LiveActivityDashboard: Initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadInitialData() async {
    try {
      // Load recent activities
      final activities = await LiveActivityService.getRecentActivities(
        limit: widget.maxActivities,
      );
      
      if (mounted) {
        setState(() {
          _recentActivities.clear();
          _recentActivities.addAll(activities);
        });
      }
      
    } catch (e) {
      debugPrint('❌ LiveActivityDashboard: Error loading initial data: $e');
    }
  }
  
  void _handleNewActivity(LiveActivity activity) {
    if (!mounted) return;
    
    setState(() {
      _recentActivities.insert(0, activity);
      if (_recentActivities.length > widget.maxActivities) {
        _recentActivities.removeLast();
      }
    });
    
    // Animate new activity
    _slideController.forward().then((_) {
      _slideController.reset();
    });
    
    // Pulse animation for stats
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(),
        
        const SizedBox(height: AppTheme.spacingMedium),
        
        // Stats section
        if (widget.showStats) ...[
          _buildStatsSection(),
          const SizedBox(height: AppTheme.spacingLarge),
        ],
        
        // Recent activities section
        if (widget.showRecentActivities) ...[
          _buildRecentActivitiesSection(),
        ],
      ],
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
          child: Icon(
            Icons.timeline,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Real-time updates from your community',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (widget.onViewAll != null)
          TextButton(
            onPressed: widget.onViewAll,
            child: const Text('View All'),
          ),
      ],
    );
  }
  
  Widget _buildStatsSection() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity Stats (Last Hour)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.article,
                        label: 'Posts',
                        value: _activityCounts['posts'] ?? 0,
                        color: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.comment,
                        label: 'Comments',
                        value: _activityCounts['comments'] ?? 0,
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.favorite,
                        label: 'Likes',
                        value: _activityCounts['likes'] ?? 0,
                        color: Colors.red,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.people,
                        label: 'Online',
                        value: _activityCounts['users_online'] ?? 0,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecentActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        
        if (_recentActivities.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentActivities.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final activity = _recentActivities[index];
              return SlideTransition(
                position: index == 0 ? _slideAnimation : 
                    const AlwaysStoppedAnimation(Offset.zero),
                child: _buildActivityItem(activity),
              );
            },
          ),
      ],
    );
  }
  
  Widget _buildActivityItem(LiveActivity activity) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Activity icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getActivityColor(activity.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getActivityIcon(activity.type),
              color: _getActivityColor(activity.type),
              size: 16,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingMedium),
          
          // Activity content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activity.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    activity.description,
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
          
          // Timestamp
          Text(
            AppDateUtils.DateUtils.formatRelativeTime(activity.timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
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
            Icons.timeline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            'No recent activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            'Activity from your community will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.postCreated:
        return Icons.article;
      case ActivityType.postUpdated:
        return Icons.edit;
      case ActivityType.comment:
        return Icons.comment;
      case ActivityType.like:
        return Icons.favorite;
      case ActivityType.share:
        return Icons.share;
      case ActivityType.userJoined:
        return Icons.person_add;
      case ActivityType.campaignCreated:
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }
  
  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.postCreated:
        return Colors.blue;
      case ActivityType.postUpdated:
        return Colors.orange;
      case ActivityType.comment:
        return Colors.green;
      case ActivityType.like:
        return Colors.red;
      case ActivityType.share:
        return Colors.purple;
      case ActivityType.userJoined:
        return Colors.teal;
      case ActivityType.campaignCreated:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}

/// Compact version of live activity dashboard for smaller spaces
class CompactLiveActivityDashboard extends StatelessWidget {
  final VoidCallback? onTap;
  
  const CompactLiveActivityDashboard({
    super.key,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.timeline,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Activity',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  StreamBuilder<Map<String, int>>(
                    stream: LiveActivityService.activityCountsStream,
                    builder: (context, snapshot) {
                      final counts = snapshot.data ?? {};
                      final total = counts.values.fold(0, (sum, count) => sum + count);
                      return Text(
                        '$total activities in the last hour',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

