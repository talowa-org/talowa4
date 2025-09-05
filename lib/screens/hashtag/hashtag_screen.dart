// Hashtag Screen - Display posts for a specific hashtag
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../services/social_feed/index.dart';
import '../../widgets/feed/post_widget.dart';
import '../../widgets/common/loading_widget.dart';

class HashtagScreen extends StatefulWidget {
  final String hashtag;

  const HashtagScreen({
    super.key,
    required this.hashtag,
  });

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  final ScrollController _scrollController = ScrollController();
  
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasMorePosts = true;
  
  int _postCount = 0;
  int _currentPage = 0;
  static const int _postsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHashtagPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              '#${widget.hashtag}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_postCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_postCount posts',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _shareHashtag,
            icon: const Icon(Icons.share),
            tooltip: 'Share Hashtag',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'follow',
                child: ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Follow Hashtag'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'mute',
                child: ListTile(
                  leading: Icon(Icons.volume_off),
                  title: Text('Mute Hashtag'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: ListTile(
                  leading: Icon(Icons.flag),
                  title: Text('Report Hashtag'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return const LoadingWidget(message: 'Loading hashtag posts...');
    }

    if (_hasError && _posts.isEmpty) {
      return CustomErrorWidget(
        message: _errorMessage ?? 'Failed to load hashtag posts',
        onRetry: _loadHashtagPosts,
      );
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshPosts,
      color: AppTheme.talowaGreen,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Hashtag info header
          SliverToBoxAdapter(
            child: _buildHashtagHeader(),
          ),
          
          // Posts list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < _posts.length) {
                  return _buildPostItem(_posts[index]);
                } else if (_isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (!_hasMorePosts) {
                  return _buildEndOfFeedMessage();
                }
                return null;
              },
              childCount: _posts.length + (_isLoadingMore || !_hasMorePosts ? 1 : 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.talowaGreen.withOpacity(0.1),
            AppTheme.talowaGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.talowaGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.talowaGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tag,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${widget.hashtag}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.talowaGreen,
                      ),
                    ),
                    if (_postCount > 0)
                      Text(
                        '$_postCount posts using this hashtag',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _followHashtag,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Follow'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.talowaGreen,
                    side: const BorderSide(color: AppTheme.talowaGreen),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareHashtag,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.talowaGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(PostModel post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: PostWidget(
        post: post,
        onLike: () => _likePost(post),
        onComment: () => _openComments(post),
        onShare: () => _sharePost(post),
        onUserTap: () => _openUserProfile(post.authorId),
        onPostTap: () => _openPostDetail(post),
        highlightQuery: widget.hashtag,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tag,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No posts found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to post with #${widget.hashtag}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createPost,
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfFeedMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'You\'ve seen all posts',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new posts with #${widget.hashtag}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Data loading methods
  Future<void> _loadHashtagPosts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      _currentPage = 0;
    });

    try {
      final posts = await FeedService.searchPostsByHashtag(
        widget.hashtag,
        limit: _postsPerPage,
      );

      setState(() {
        _posts = posts;
        _postCount = posts.length; // TODO: Get actual count from API
        _isLoading = false;
        _hasMorePosts = posts.length == _postsPerPage;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final morePosts = await FeedService.searchPostsByHashtag(
        widget.hashtag,
        limit: _postsPerPage,
        // TODO: Implement proper pagination with lastDocument
      );

      setState(() {
        _posts.addAll(morePosts);
        _currentPage++;
        _isLoadingMore = false;
        _hasMorePosts = morePosts.length == _postsPerPage;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more posts: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _refreshPosts() async {
    await _loadHashtagPosts();
  }

  // Scroll handling
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  // Actions
  void _handleMenuAction(String action) {
    switch (action) {
      case 'follow':
        _followHashtag();
        break;
      case 'mute':
        _muteHashtag();
        break;
      case 'report':
        _reportHashtag();
        break;
    }
  }

  void _followHashtag() {
    // TODO: Implement hashtag following
    debugPrint('Following hashtag: ${widget.hashtag}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now following #${widget.hashtag}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _muteHashtag() {
    // TODO: Implement hashtag muting
    debugPrint('Muting hashtag: ${widget.hashtag}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Muted #${widget.hashtag}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _reportHashtag() {
    // TODO: Implement hashtag reporting
    debugPrint('Reporting hashtag: ${widget.hashtag}');
  }

  void _shareHashtag() {
    // TODO: Implement hashtag sharing
    debugPrint('Sharing hashtag: ${widget.hashtag}');
  }

  void _createPost() {
    // TODO: Navigate to post creation with hashtag pre-filled
    debugPrint('Creating post with hashtag: ${widget.hashtag}');
  }

  // Post interaction methods
  void _likePost(PostModel post) {
    // TODO: Implement like functionality
    debugPrint('Liking post: ${post.id}');
  }

  void _openComments(PostModel post) {
    // TODO: Navigate to comments screen
    debugPrint('Opening comments for post: ${post.id}');
  }

  void _sharePost(PostModel post) {
    // TODO: Navigate to share screen
    debugPrint('Sharing post: ${post.id}');
  }

  void _openUserProfile(String userId) {
    // TODO: Navigate to user profile
    debugPrint('Opening profile for user: $userId');
  }

  void _openPostDetail(PostModel post) {
    // TODO: Navigate to post detail screen
    debugPrint('Opening post detail: ${post.id}');
  }
}

