// Offline-Aware Feed Screen for TALOWA
// Implements Task 20: Offline functionality - UI Integration

import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../services/social_feed/offline_sync_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/feed/post_widget.dart';
import '../post_creation/simple_post_creation_screen.dart';

class OfflineFeedScreen extends StatefulWidget {
  const OfflineFeedScreen({super.key});

  @override
  State<OfflineFeedScreen> createState() => _OfflineFeedScreenState();
}

class _OfflineFeedScreenState extends State<OfflineFeedScreen>
    with AutomaticKeepAliveClientMixin {
  final OfflineSyncService _offlineService = OfflineSyncService();
  final ScrollController _scrollController = ScrollController();
  
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _isOnline = true;
  bool _isSyncing = false;
  
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<SyncStatus>? _syncStatusSubscription;
  
  PostCategory? _selectedCategory;
  String? _lastPostId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeOfflineService();
    _loadPosts();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _syncStatusSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeOfflineService() async {
    try {
      await _offlineService.initialize();
      
      // Listen to connection changes
      _connectionSubscription = _offlineService.connectionStream.listen((isOnline) {
        if (mounted) {
          setState(() {
            _isOnline = isOnline;
          });
        }
      });
      
      // Listen to sync status changes
      _syncStatusSubscription = _offlineService.syncStatusStream.listen((status) {
        if (mounted) {
          setState(() {
            _isSyncing = status == SyncStatus.syncing;
          });
          
          // Refresh posts after successful sync
          if (status == SyncStatus.completed) {
            _refreshPosts();
          }
        }
      });
      
      // Set initial states
      setState(() {
        _isOnline = _offlineService.isOnline;
        _isSyncing = _offlineService.isSyncing;
      });
    } catch (e) {
      debugPrint('Error initializing offline service: $e');
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.eco, color: Colors.white, size: 32),
          const SizedBox(width: 8),
          const Text(
            'TALOWA Feed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 8),
          _buildConnectionIndicator(),
        ],
      ),
      backgroundColor: AppTheme.talowaGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        if (_isSyncing)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          )
        else
          IconButton(
            onPressed: _isOnline ? _forceSyncNow : null,
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Now',
          ),
        
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'filter',
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 20),
                  const SizedBox(width: 8),
                  Text(_selectedCategory != null ? 'Clear Filter' : 'Filter'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'sync_stats',
              child: Row(
                children: [
                  Icon(Icons.analytics, size: 20),
                  SizedBox(width: 8),
                  Text('Sync Stats'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'storage',
              child: Row(
                children: [
                  Icon(Icons.storage, size: 20),
                  SizedBox(width: 8),
                  Text('Storage Usage'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return const LoadingWidget(message: 'Loading posts...');
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshPosts,
      color: AppTheme.talowaGreen,
      child: Column(
        children: [
          if (_selectedCategory != null) _buildFilterBar(),
          if (!_isOnline) _buildOfflineBanner(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _posts.length) {
                  return _buildPostItem(_posts[index]);
                } else {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.talowaGreen.withOpacity(0.1),
      child: Row(
        children: [
          const Text(
            'Filtered by:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text(_getCategoryName(_selectedCategory!)),
            onDeleted: () => _clearFilter(),
            deleteIcon: const Icon(Icons.close, size: 16),
            backgroundColor: AppTheme.talowaGreen.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.orange.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'You\'re offline. Showing cached content. New posts will sync when online.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOnline ? Icons.article_outlined : Icons.cloud_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _isOnline ? 'No posts available' : 'No cached posts',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isOnline 
                  ? 'Be the first to share something with your community!'
                  : 'Posts will appear here when you\'re online.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_isOnline)
              ElevatedButton.icon(
                onPressed: _createPost,
                icon: const Icon(Icons.add),
                label: const Text('Create Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.talowaGreen,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostItem(PostModel post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          PostWidget(
            post: post,
            onLike: () => _handleLike(post),
            onComment: () => _handleComment(post),
            onShare: () => _handleShare(post),
            onUserTap: () => _handleUserTap(post),
            onPostTap: () => _handlePostTap(post),
          ),
          if (post.metadata?['synced'] == false)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync_problem, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Waiting to sync...',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _createPost,
      backgroundColor: AppTheme.talowaGreen,
      foregroundColor: Colors.white,
      tooltip: 'Create Post',
      child: const Icon(Icons.add),
    );
  }

  // Event handlers
  Future<void> _loadPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final posts = await _offlineService.getPosts(
        limit: 20,
        category: _selectedCategory,
      );

      setState(() {
        _posts = posts;
        _lastPostId = posts.isNotEmpty ? posts.last.id : null;
        _hasMorePosts = posts.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading posts: $e')),
        );
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final morePosts = await _offlineService.getPosts(
        limit: 20,
        lastPostId: _lastPostId,
        category: _selectedCategory,
      );

      setState(() {
        _posts.addAll(morePosts);
        _lastPostId = morePosts.isNotEmpty ? morePosts.last.id : _lastPostId;
        _hasMorePosts = morePosts.length == 20;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more posts: $e')),
        );
      }
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _posts.clear();
      _lastPostId = null;
      _hasMorePosts = true;
    });
    
    await _loadPosts();
  }

  Future<void> _handleLike(PostModel post) async {
    try {
      final newLikedState = !post.isLikedByCurrentUser;
      
      // Update UI immediately
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = post.copyWith(
            isLikedByCurrentUser: newLikedState,
            likesCount: newLikedState 
                ? post.likesCount + 1 
                : post.likesCount - 1,
          );
        }
      });
      
      // Handle offline/online sync
      await _offlineService.likePost(
        postId: post.id,
        userId: 'current_user_id', // TODO: Get from auth service
        isLiked: newLikedState,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error liking post: $e')),
        );
      }
    }
  }

  Future<void> _handleComment(PostModel post) async {
    final commentController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            hintText: 'Write your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, commentController.text.trim()),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      try {
        await _offlineService.addComment(
          postId: post.id,
          content: result,
          authorId: 'current_user_id', // TODO: Get from auth service
        );
        
        // Update UI
        setState(() {
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            _posts[index] = post.copyWith(
              commentsCount: post.commentsCount + 1,
            );
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment added!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding comment: $e')),
          );
        }
      }
    }
  }

  void _handleShare(PostModel post) {
    // Update UI immediately
    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = post.copyWith(
          sharesCount: post.sharesCount + 1,
          isSharedByCurrentUser: true,
        );
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shared post by ${post.authorName}')),
    );
  }

  void _handleUserTap(PostModel post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('View profile: ${post.authorName}')),
    );
  }

  void _handlePostTap(PostModel post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('View post details: ${post.title ?? "Post"}')),
    );
  }

  void _createPost() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const SimplePostCreationScreen(),
      ),
    );
    
    if (result == true) {
      _refreshPosts();
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'filter':
        if (_selectedCategory != null) {
          _clearFilter();
        } else {
          _showFilterDialog();
        }
        break;
      case 'sync_stats':
        _showSyncStats();
        break;
      case 'storage':
        _showStorageUsage();
        break;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Posts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PostCategory.values.map((category) {
            return ListTile(
              title: Text(_getCategoryName(category)),
              onTap: () {
                Navigator.pop(context);
                _applyFilter(category);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _applyFilter(PostCategory category) {
    setState(() {
      _selectedCategory = category;
      _posts.clear();
      _lastPostId = null;
      _hasMorePosts = true;
    });
    _loadPosts();
  }

  void _clearFilter() {
    setState(() {
      _selectedCategory = null;
      _posts.clear();
      _lastPostId = null;
      _hasMorePosts = true;
    });
    _loadPosts();
  }

  Future<void> _forceSyncNow() async {
    try {
      await _offlineService.forceSyncNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _showSyncStats() async {
    try {
      final stats = await _offlineService.getSyncStats();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Statistics'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending: ${stats['pending'] ?? 0}'),
                Text('Completed: ${stats['completed'] ?? 0}'),
                Text('Failed: ${stats['failed'] ?? 0}'),
                const SizedBox(height: 16),
                if (_offlineService.lastSyncTime != null)
                  Text('Last sync: ${_formatDateTime(_offlineService.lastSyncTime!)}')
                else
                  const Text('Never synced'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting sync stats: $e')),
        );
      }
    }
  }

  Future<void> _showStorageUsage() async {
    try {
      final usage = await _offlineService.getStorageUsage();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Storage Usage'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Posts: ${usage['posts_count'] ?? 0}'),
                Text('Comments: ${usage['comments_count'] ?? 0}'),
                Text('Sync queue: ${usage['sync_queue_count'] ?? 0}'),
                Text('Database size: ${usage['database_size_mb'] ?? 0} MB'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting storage usage: $e')),
        );
      }
    }
  }

  String _getCategoryName(PostCategory category) {
    switch (category) {
      case PostCategory.successStory:
        return 'Success Stories';
      case PostCategory.legalUpdate:
        return 'Legal Updates';
      case PostCategory.announcement:
        return 'Announcements';
      case PostCategory.emergency:
        return 'Emergency';
      case PostCategory.generalDiscussion:
        return 'General Discussion';
      case PostCategory.landRights:
        return 'Land Rights';
      case PostCategory.communityNews:
        return 'Community News';
      default:
        return 'General';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}