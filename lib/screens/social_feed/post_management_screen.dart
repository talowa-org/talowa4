// Post Management Screen - Dashboard for managing user's posts
// Part of Task 11: Add post editing and management

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/social_feed/post_model.dart';
import '../../services/social_feed/post_management_service.dart';
import '../../services/social_feed/feed_service.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/navigation_helper.dart';
import '../../widgets/social_feed/post_widget.dart';

/// Screen for managing user's posts, drafts, and scheduled posts
class PostManagementScreen extends StatefulWidget {
  const PostManagementScreen({super.key});
  
  @override
  State<PostManagementScreen> createState() => _PostManagementScreenState();
}

class _PostManagementScreenState extends State<PostManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Data
  List<PostModel> _userPosts = [];
  List<Map<String, dynamic>> _drafts = [];
  List<Map<String, dynamic>> _scheduledPosts = [];
  Map<String, dynamic>? _analytics;
  
  // UI state
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Load data in parallel
      final futures = await Future.wait([
        _loadUserPosts(currentUser.uid),
        _loadDrafts(currentUser.uid),
        _loadScheduledPosts(currentUser.uid),
        _loadAnalytics(currentUser.uid),
      ]);
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadUserPosts(String userId) async {
    try {
      // Get user's recent posts
      final posts = await FeedService.getFeedPosts(
        userId: userId,
        limit: 50,
      );
      
      // Filter to only user's own posts
      _userPosts = posts.where((post) => post.authorId == userId).toList();
    } catch (e) {
      debugPrint('Error loading user posts: $e');
    }
  }
  
  Future<void> _loadDrafts(String userId) async {
    try {
      _drafts = await PostManagementService.getUserDrafts(userId);
    } catch (e) {
      debugPrint('Error loading drafts: $e');
    }
  }
  
  Future<void> _loadScheduledPosts(String userId) async {
    try {
      _scheduledPosts = await PostManagementService.getScheduledPosts(userId);
    } catch (e) {
      debugPrint('Error loading scheduled posts: $e');
    }
  }
  
  Future<void> _loadAnalytics(String userId) async {
    try {
      _analytics = await PostManagementService.getUserPostAnalytics(userId);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.article),
              text: 'Posts (${_userPosts.length})',
            ),
            Tab(
              icon: const Icon(Icons.drafts),
              text: 'Drafts (${_drafts.length})',
            ),
            Tab(
              icon: const Icon(Icons.schedule),
              text: 'Scheduled (${_scheduledPosts.length})',
            ),
            const Tab(
              icon: Icon(Icons.analytics),
              text: 'Analytics',
            ),
          ],
          isScrollable: true,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsTab(),
                    _buildDraftsTab(),
                    _buildScheduledTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
    );
  }
  
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPostsTab() {
    if (_userPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article,
        title: 'No Posts Yet',
        subtitle: 'Your published posts will appear here',
        actionText: 'Create Post',
        onAction: () => context.navigateToPostCreation(),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _userPosts.length,
        itemBuilder: (context, index) {
          final post = _userPosts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }
  
  Widget _buildPostCard(PostModel post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Post preview
          PostWidget(
            post: post,
            showFullContent: false,
            enableInteractions: false,
            onPostUpdated: (updatedPost) {
              setState(() {
                final index = _userPosts.indexWhere((p) => p.id == updatedPost.id);
                if (index != -1) {
                  _userPosts[index] = updatedPost;
                }
              });
            },
          ),
          
          // Management actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                // Analytics button
                TextButton.icon(
                  onPressed: () => _showPostAnalytics(post),
                  icon: const Icon(Icons.analytics, size: 16),
                  label: const Text('Analytics'),
                ),
                
                const SizedBox(width: 8),
                
                // Edit button
                TextButton.icon(
                  onPressed: () => _editPost(post),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                
                const SizedBox(width: 8),
                
                // Visibility button
                TextButton.icon(
                  onPressed: () => _changeVisibility(post),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Visibility'),
                ),
                
                const Spacer(),
                
                // Delete button
                TextButton.icon(
                  onPressed: () => _deletePost(post),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDraftsTab() {
    if (_drafts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.drafts,
        title: 'No Drafts',
        subtitle: 'Your saved drafts will appear here',
        actionText: 'Create Post',
        onAction: () => context.navigateToPostCreation(),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drafts.length,
        itemBuilder: (context, index) {
          final draft = _drafts[index];
          return _buildDraftCard(draft);
        },
      ),
    );
  }
  
  Widget _buildDraftCard(Map<String, dynamic> draft) {
    final title = draft['title'] as String?;
    final content = draft['content'] as String? ?? '';
    final updatedAt = (draft['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.drafts, color: Colors.white),
        ),
        title: Text(
          title?.isNotEmpty == true ? title! : 'Untitled Draft',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.length > 100 ? '${content.substring(0, 100)}...' : content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Last saved: ${DateFormat('MMM d, yyyy h:mm a').format(updatedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleDraftAction(action, draft),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _editDraft(draft),
      ),
    );
  }
  
  Widget _buildScheduledTab() {
    if (_scheduledPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.schedule,
        title: 'No Scheduled Posts',
        subtitle: 'Your scheduled posts will appear here',
        actionText: 'Schedule Post',
        onAction: () => _showScheduleDialog(),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _scheduledPosts.length,
        itemBuilder: (context, index) {
          final scheduledPost = _scheduledPosts[index];
          return _buildScheduledPostCard(scheduledPost);
        },
      ),
    );
  }
  
  Widget _buildScheduledPostCard(Map<String, dynamic> scheduledPost) {
    final title = scheduledPost['title'] as String?;
    final content = scheduledPost['content'] as String? ?? '';
    final scheduledTime = (scheduledPost['scheduledTime'] as Timestamp).toDate();
    final isOverdue = scheduledTime.isBefore(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue ? Colors.red : Colors.blue,
          child: Icon(
            isOverdue ? Icons.warning : Icons.schedule,
            color: Colors.white,
          ),
        ),
        title: Text(
          title?.isNotEmpty == true ? title! : 'Untitled Post',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.length > 100 ? '${content.substring(0, 100)}...' : content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Scheduled for: ${DateFormat('MMM d, yyyy h:mm a').format(scheduledTime)}',
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? Colors.red : Colors.grey.shade600,
                fontWeight: isOverdue ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            if (isOverdue)
              const Text(
                'Overdue - needs manual publishing',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleScheduledPostAction(action, scheduledPost),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'publish',
              child: Row(
                children: [
                  Icon(Icons.publish, size: 16),
                  SizedBox(width: 8),
                  Text('Publish Now'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'cancel',
              child: Row(
                children: [
                  Icon(Icons.cancel, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Cancel', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnalyticsTab() {
    if (_analytics == null) {
      return const Center(
        child: Text('Analytics data not available'),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview cards
          _buildAnalyticsOverview(),
          
          const SizedBox(height: 24),
          
          // Category breakdown
          _buildCategoryBreakdown(),
          
          const SizedBox(height: 24),
          
          // Daily activity
          _buildDailyActivity(),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview (Last 30 Days)',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                'Posts',
                _analytics!['totalPosts'].toString(),
                Icons.article,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAnalyticsCard(
                'Total Likes',
                _analytics!['totalLikes'].toString(),
                Icons.favorite,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                'Comments',
                _analytics!['totalComments'].toString(),
                Icons.comment,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAnalyticsCard(
                'Shares',
                _analytics!['totalShares'].toString(),
                Icons.share,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAnalyticsCard(
          'Avg Engagement per Post',
          _analytics!['avgEngagementPerPost'].toString(),
          Icons.trending_up,
          Colors.purple,
          fullWidth: true,
        ),
      ],
    );
  }
  
  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryBreakdown() {
    final categoryBreakdown = _analytics!['categoryBreakdown'] as Map<String, dynamic>;
    
    if (categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Posts by Category',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        ...categoryBreakdown.entries.map((entry) {
          final category = entry.key;
          final count = entry.value as int;
          final percentage = (_analytics!['totalPosts'] as int) > 0
              ? (count / (_analytics!['totalPosts'] as int) * 100).toStringAsFixed(1)
              : '0.0';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getCategoryDisplayName(category),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text('$count ($percentage%)'),
              ],
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildDailyActivity() {
    final dailyPosts = _analytics!['dailyPosts'] as Map<String, dynamic>;
    
    if (dailyPosts.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Activity',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'Daily activity chart would go here\n(Chart implementation needed)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAction,
            child: Text(actionText),
          ),
        ],
      ),
    );
  }
  
  // Event handlers
  
  Future<void> _editPost(PostModel post) async {
    final result = await context.navigateToPostCreation(editingPost: post);
    if (result == true) {
      _loadData();
    }
  }
  
  Future<void> _deletePost(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await PostManagementService.deletePost(post.id);
        _showSuccess('Post deleted successfully');
        _loadData();
      } catch (e) {
        _showError('Failed to delete post: $e');
      }
    }
  }
  
  Future<void> _changeVisibility(PostModel post) async {
    final newVisibility = await showDialog<PostVisibility>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Visibility'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PostVisibility.values.map((visibility) {
            return RadioListTile<PostVisibility>(
              title: Text(visibility.displayName),
              subtitle: Text(visibility.description),
              value: visibility,
              groupValue: post.visibility,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
      ),
    );
    
    if (newVisibility != null && newVisibility != post.visibility) {
      try {
        await PostManagementService.updatePostVisibility(post.id, newVisibility);
        _showSuccess('Post visibility updated');
        _loadData();
      } catch (e) {
        _showError('Failed to update visibility: $e');
      }
    }
  }
  
  Future<void> _showPostAnalytics(PostModel post) async {
    try {
      final analytics = await PostManagementService.getPostAnalytics(post.id);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Post Analytics'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnalyticsRow('Likes', analytics['likes'].toString()),
                _buildAnalyticsRow('Comments', analytics['comments'].toString()),
                _buildAnalyticsRow('Shares', analytics['shares'].toString()),
                _buildAnalyticsRow('Total Engagement', analytics['totalEngagement'].toString()),
                _buildAnalyticsRow('Engagement Rate', '${analytics['engagementRate']}%'),
                _buildAnalyticsRow('Impressions', analytics['impressions'].toString()),
                _buildAnalyticsRow('Reach', analytics['reach'].toString()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Failed to load analytics: $e');
    }
  }
  
  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Future<void> _editDraft(Map<String, dynamic> draft) async {
    // TODO: Navigate to post creation with draft data
    _showInfo('Draft editing feature coming soon!');
  }
  
  void _handleDraftAction(String action, Map<String, dynamic> draft) async {
    switch (action) {
      case 'edit':
        await _editDraft(draft);
        break;
      case 'delete':
        await _deleteDraft(draft);
        break;
    }
  }
  
  Future<void> _deleteDraft(Map<String, dynamic> draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: const Text('Are you sure you want to delete this draft?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await PostManagementService.deleteDraft(draft['id']);
        _showSuccess('Draft deleted successfully');
        _loadData();
      } catch (e) {
        _showError('Failed to delete draft: $e');
      }
    }
  }
  
  void _handleScheduledPostAction(String action, Map<String, dynamic> scheduledPost) async {
    switch (action) {
      case 'publish':
        await _publishScheduledPost(scheduledPost);
        break;
      case 'edit':
        await _editScheduledPost(scheduledPost);
        break;
      case 'cancel':
        await _cancelScheduledPost(scheduledPost);
        break;
    }
  }
  
  Future<void> _publishScheduledPost(Map<String, dynamic> scheduledPost) async {
    // TODO: Implement immediate publishing of scheduled post
    _showInfo('Publish scheduled post feature coming soon!');
  }
  
  Future<void> _editScheduledPost(Map<String, dynamic> scheduledPost) async {
    // TODO: Navigate to post creation with scheduled post data
    _showInfo('Edit scheduled post feature coming soon!');
  }
  
  Future<void> _cancelScheduledPost(Map<String, dynamic> scheduledPost) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Scheduled Post'),
        content: const Text('Are you sure you want to cancel this scheduled post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Post'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await PostManagementService.cancelScheduledPost(scheduledPost['id']);
        _showSuccess('Scheduled post cancelled');
        _loadData();
      } catch (e) {
        _showError('Failed to cancel scheduled post: $e');
      }
    }
  }
  
  void _showScheduleDialog() {
    _showInfo('Post scheduling feature coming soon!');
  }
  
  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'successStory':
        return 'Success Story';
      case 'legalUpdate':
        return 'Legal Update';
      case 'announcement':
        return 'Announcement';
      case 'emergency':
        return 'Emergency';
      case 'generalDiscussion':
        return 'General Discussion';
      case 'landRights':
        return 'Land Rights';
      case 'communityNews':
        return 'Community News';
      default:
        return category;
    }
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

