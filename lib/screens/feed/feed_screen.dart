// Clean Feed Screen - Main social feed interface
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/post_model.dart';
import '../../services/social_feed/feed_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../post_creation/simple_post_creation_screen.dart';
import '../../models/social_feed/story_model.dart';
import '../../services/social_feed/stories_service.dart';
import '../../services/auth_service.dart';
import 'stories_screen.dart';
import 'story_creation_screen.dart';
import 'post_comments_screen.dart';
import '../../widgets/stories/story_ring.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  // State management
  List<PostModel> _posts = [];
  Map<String, List<StoryModel>> _storiesByAuthor = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasMorePosts = true;
  final bool _showFab = true;
  
  // Filtering and search
  PostCategory? _selectedCategory;
  String? _searchQuery;
  final FeedSortOption _sortOption = FeedSortOption.newest;
  final bool _showOnlyFollowing = false;

  // Pagination
  static const int _postsPerPage = 10;
  int _currentPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    // Setup scroll listener
    _scrollController.addListener(_onScroll);
    
    // Load initial data
    _loadFeed();
    _loadStories();
    
    // Start FAB animation
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.eco, color: Colors.white, size: 32),
          SizedBox(width: 8),
          Text(
            'TALOWA Feed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.talowaGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _openSearch,
          icon: const Icon(Icons.search),
          tooltip: 'Search',
        ),
        IconButton(
          onPressed: _showFilterOptions,
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return const LoadingWidget(message: 'Loading feed...');
    }

    if (_hasError && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${_errorMessage ?? 'Failed to load feed'}'),
            ElevatedButton(
              onPressed: _loadFeed,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: AppTheme.talowaGreen,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 1 + _posts.length + (_isLoadingMore || !_hasMorePosts ? 1 : 0), // +1 for stories
        itemBuilder: (context, index) {
          if (index == 0) {
            // Stories section at the top
            return _buildStoriesSection();
          } else if (index <= _posts.length) {
            // Posts section
            return _buildPostItem(_posts[index - 1]);
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
      ),
    );
  }

  Widget _buildPostItem(PostModel post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(post.authorRole),
                  child: Text(
                    post.authorName.isNotEmpty ? post.authorName[0] : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCategoryBadge(post.category),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            if (post.title != null) ...[
              Text(
                post.title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Content
            Text(
              post.content,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),

            // Media (Images, Videos, Documents)
            if (post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMediaSection(post.mediaUrls),
            ],

            // Hashtags
            if (post.hashtags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: post.hashtags.map((hashtag) => InkWell(
                  onTap: () => _searchByHashtag(hashtag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.talowaGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.talowaGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '#$hashtag',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.talowaGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // Engagement
            Row(
              children: [
                _buildEngagementButton(
                  icon: post.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                  count: post.likesCount,
                  label: 'Like',
                  color: post.isLikedByCurrentUser ? Colors.red : null,
                  onTap: () => _handleLike(post),
                ),
                _buildEngagementButton(
                  icon: Icons.comment_outlined,
                  count: post.commentsCount,
                  label: 'Comment',
                  onTap: () => _handleComment(post),
                ),
                _buildEngagementButton(
                  icon: Icons.share_outlined,
                  count: post.sharesCount,
                  label: 'Share',
                  onTap: () => _handleShare(post),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(PostCategory category) {
    final categoryInfo = _getCategoryInfo(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: categoryInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryInfo['color'].withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            categoryInfo['icon'],
            size: 12,
            color: categoryInfo['color'],
          ),
          const SizedBox(width: 4),
          Text(
            categoryInfo['label'],
            style: TextStyle(
              fontSize: 10,
              color: categoryInfo['color'],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementButton({
    required IconData icon,
    required int count,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: color ?? Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
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
              Icons.article_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to TALOWA Feed!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start following people and join communities to see posts here.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshFeed,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re all caught up!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new posts from your community.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton(
        onPressed: _createPost,
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        tooltip: 'Create Post',
        heroTag: "feed_create_post",
        child: const Icon(Icons.add),
      ),
    );
  }

  // Data loading methods
  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      _currentPage = 0;
    });

    try {
      final posts = await FeedService().getFeedPosts(
        limit: _postsPerPage,
        category: _selectedCategory,
        searchQuery: _searchQuery,
        sortOption: _sortOption,
      );

      setState(() {
        _posts = posts;
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
    if (_isLoadingMore || !_hasMorePosts || _posts.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final lastPost = _posts.last;
      final lastDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(lastPost.id)
          .get();

      final morePosts = await FeedService().getFeedPosts(
        limit: _postsPerPage,
        lastDocument: lastDoc,
        category: _selectedCategory,
        searchQuery: _searchQuery,
        sortOption: _sortOption,
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

  Future<void> _refreshFeed() async {
    HapticFeedback.lightImpact();
    await Future.wait([
      _loadFeed(),
      _loadStories(),
    ]);
  }

  // Load stories
  Future<void> _loadStories() async {
    try {
      final storiesByAuthor = await StoriesService().getStoriesByAuthor(limit: 20);
      setState(() {
        _storiesByAuthor = storiesByAuthor;
      });
    } catch (e) {
      debugPrint('Error loading stories: $e');
    }
  }

  // Scroll handling
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  // Event handlers
  void _handleLike(PostModel post) async {
    if (!mounted) return;
    
    // Store original state for rollback
    final originalPost = post;
    
    try {
      // Optimistic update
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          final isLiked = post.isLikedByCurrentUser;
          _posts[index] = post.copyWith(
            isLikedByCurrentUser: !isLiked,
            likesCount: isLiked ? post.likesCount - 1 : post.likesCount + 1,
          );
        }
      });
      
      // Perform server update
      await FeedService().toggleLike(post.id);
      
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !post.isLikedByCurrentUser 
                  ? 'Liked post by ${post.authorName}' 
                  : 'Unliked post by ${post.authorName}'
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            _posts[index] = originalPost;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update like. Please try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleLike(originalPost),
            ),
          ),
        );
      }
    }
  }

  void _handleComment(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostCommentsScreen(post: post),
      ),
    ).then((_) {
      // Refresh feed to update comment counts
      _refreshFeed();
    });
  }

  void _showCommentDialog(PostModel post) {
    final commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comment on ${post.authorName}\'s post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Comments will be visible to all members',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (commentController.text.trim().isNotEmpty) {
                try {
                  await FeedService().addComment(
                    postId: post.id,
                    content: commentController.text.trim(),
                  );
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Comment added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Refresh feed to show new comment count
                  _refreshFeed();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add comment: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Comment'),
          ),
        ],
      ),
    ).then((_) => commentController.dispose());
  }

  void _handleShare(PostModel post) async {
    _showShareDialog(post);
  }

  void _showShareDialog(PostModel post) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share ${post.authorName}\'s post',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Share options
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blue),
              title: const Text('Copy Link'),
              onTap: () async {
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(
                  text: 'Check out this post from ${post.authorName}: ${post.content.substring(0, 50)}...',
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Post link copied to clipboard!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _incrementShareCount(post);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('Share in Messages'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Shared to messages!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _incrementShareCount(post);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.share, color: Colors.orange),
              title: const Text('Share Externally'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('External sharing coming soon!'),
                    backgroundColor: Colors.blue,
                  ),
                );
                _incrementShareCount(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _incrementShareCount(PostModel post) async {
    if (!mounted) return;
    
    // Store original state for rollback
    final originalPost = post;
    
    try {
      // Optimistic update
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = post.copyWith(
            sharesCount: post.sharesCount + 1,
          );
        }
      });
      
      // Perform server update
      await FeedService().sharePost(post.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            _posts[index] = originalPost;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to share post. Please try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _incrementShareCount(originalPost),
            ),
          ),
        );
      }
    }
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: FeedSearchDelegate(
        onSearch: (query) {
          setState(() {
            _searchQuery = query;
          });
          _loadFeed();
        },
      ),
    );
  }

  void _showFilterOptions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filter options coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _searchByHashtag(String hashtag) {
    setState(() {
      _searchQuery = hashtag;
    });
    _loadFeed();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching for #$hashtag'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _createPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimplePostCreationScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _refreshFeed();
      }
    });
  }

  // Helper methods
  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'district_coordinator':
        return Colors.purple;
      case 'mandal_coordinator':
        return Colors.blue;
      case 'village_coordinator':
        return Colors.green;
      case 'volunteer':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> _getCategoryInfo(PostCategory category) {
    switch (category) {
      case PostCategory.announcement:
        return {'label': 'Announcement', 'color': Colors.blue, 'icon': Icons.campaign};
      case PostCategory.successStory:
        return {'label': 'Success', 'color': Colors.green, 'icon': Icons.celebration};
      case PostCategory.legalUpdate:
        return {'label': 'Legal', 'color': Colors.purple, 'icon': Icons.gavel};
      case PostCategory.emergency:
        return {'label': 'Emergency', 'color': Colors.red, 'icon': Icons.warning};
      case PostCategory.communityNews:
        return {'label': 'Community', 'color': Colors.orange, 'icon': Icons.people};
      default:
        return {'label': 'General', 'color': Colors.grey, 'icon': Icons.chat};
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildStoriesSection() {
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _storiesByAuthor.length + 1, // +1 for "Add Story" button
        itemBuilder: (context, index) {
          if (index == 0) {
            // "Add Story" button
            return _buildAddStoryButton();
          }
          
          final authorIndex = index - 1;
          final authorId = _storiesByAuthor.keys.elementAt(authorIndex);
          final authorStories = _storiesByAuthor[authorId]!;
          final latestStory = authorStories.last;

          return _buildStoryItem(
            story: latestStory,
            stories: authorStories,
            onTap: () => _openStories(authorStories, 0),
          );
        },
      ),
    );
  }

  void _openStories(List<StoryModel> stories, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoriesScreen(
          storiesByAuthor: _storiesByAuthor,
          initialAuthorId: stories.first.authorId,
          initialStoryIndex: initialIndex,
        ),
      ),
    );
  }
  // Media display section
  Widget _buildMediaSection(List<String> mediaUrls) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: mediaUrls.length == 1
          ? _buildSingleMedia(mediaUrls.first)
          : _buildMultipleMedia(mediaUrls),
    );
  }

  Widget _buildSingleMedia(String mediaUrl) {
    if (_isImageUrl(mediaUrl)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          mediaUrl,
          width: double.infinity,
          height: 300,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 300,
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 300,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            );
          },
        ),
      );
    } else if (_isVideoUrl(mediaUrl)) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_outline, size: 60, color: Colors.white),
        ),
      );
    } else {
      return _buildDocumentPreview(mediaUrl);
    }
  }

  Widget _buildMultipleMedia(List<String> mediaUrls) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mediaUrls.length,
        itemBuilder: (context, index) {
          final mediaUrl = mediaUrls[index];
          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _isImageUrl(mediaUrl)
                  ? Image.network(
                      mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        );
                      },
                    )
                  : _isVideoUrl(mediaUrl)
                      ? Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(Icons.play_circle_outline, color: Colors.white),
                          ),
                        )
                      : _buildDocumentPreview(mediaUrl),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentPreview(String documentUrl) {
    final fileName = documentUrl.split('/').last.split('?').first;
    final extension = fileName.split('.').last.toLowerCase();
    
    IconData icon;
    Color color;
    
    switch (extension) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'txt':
        icon = Icons.text_snippet;
        color = Colors.grey;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  bool _isImageUrl(String url) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    final extension = url.split('.').last.split('?').first.toLowerCase();
    return imageExtensions.contains(extension);
  }

  bool _isVideoUrl(String url) {
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    final extension = url.split('.').last.split('?').first.toLowerCase();
    return videoExtensions.contains(extension);
  }

  Widget _buildAddStoryButton() {
    return GestureDetector(
      onTap: _createStory,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
                color: Colors.grey.shade50,
              ),
              child: const Icon(
                Icons.add,
                color: AppTheme.talowaGreen,
                size: 32,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your Story',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem({
    required StoryModel story,
    required List<StoryModel> stories,
    required VoidCallback onTap,
  }) {
    final hasUnviewedStories = stories.any((s) => !s.reactions.containsKey(AuthService.currentUser?.uid));
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            StoryRing(
              hasUnviewedStories: hasUnviewedStories,
              child: story.mediaType == 'image'
                  ? Image.network(
                      story.mediaUrl,
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: AppTheme.talowaGreen.withOpacity(0.2),
                          child: Center(
                            child: Text(
                              story.authorName.isNotEmpty 
                                  ? story.authorName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppTheme.talowaGreen,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.black,
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 68,
              child: Text(
                story.authorName.split(' ').first,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hasUnviewedStories ? Colors.black87 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createStory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StoryCreationScreen(),
      ),
    );
    
    if (result != null) {
      // Refresh stories after creating a new one
      _loadStories();
    }
  }

}

// Feed Search Delegate
class FeedSearchDelegate extends SearchDelegate<String> {
  final Function(String) onSearch;

  FeedSearchDelegate({required this.onSearch});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, '');
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    close(context, query);
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = [
      'land rights',
      'success story',
      'legal update',
      'agriculture',
      'government schemes',
    ];

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: const Icon(Icons.search),
          title: Text(suggestion),
          onTap: () {
            query = suggestion;
            onSearch(query);
            close(context, query);
          },
        );
      },
    );
  }
}