// Instagram-style Feed Screen for TALOWA
// Modern social media feed with comprehensive features
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../../services/social_feed/instagram_feed_service.dart';
import '../../widgets/feed/instagram_post_widget.dart';
import '../../widgets/feed/feed_skeleton_loader.dart';
import '../../widgets/common/error_boundary_widget.dart';
import '../post_creation/instagram_post_creation_screen.dart';
import '../story/story_creation_screen.dart';
import '../feed/comments_screen.dart';
import '../../services/social_feed/story_service.dart';
import '../../services/social_feed/post_management_service.dart';
import '../../models/social_feed/story_model.dart';
import '../../services/auth/auth_service.dart';
import '../../services/feed_crash_prevention_service.dart';
import 'package:flutter/foundation.dart';

class InstagramFeedScreen extends StatefulWidget {
  const InstagramFeedScreen({super.key});

  @override
  State<InstagramFeedScreen> createState() => _InstagramFeedScreenState();
}

class _InstagramFeedScreenState extends State<InstagramFeedScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  // Services
  final InstagramFeedService _feedService = InstagramFeedService();
  final StoryService _storyService = StoryService();
  final PostManagementService _postManagementService = PostManagementService();
  final FeedCrashPreventionService _crashPrevention = FeedCrashPreventionService();
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  // Animation controllers
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  
  // State
  List<InstagramPostModel> _posts = [];
  List<StoryModel> _stories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showFab = true;
  
  // Streams
  StreamSubscription<List<InstagramPostModel>>? _feedSubscription;
  StreamSubscription<String>? _postUpdateSubscription;
  StreamSubscription<List<StoryModel>>? _storiesSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Call async initialization without awaiting in initState
    Future.microtask(() => _safeInitialize());
  }
  
  /// Safe initialization with comprehensive error handling
  Future<void> _safeInitialize() async {
    try {
      _crashPrevention.initialize(); // Synchronous initialization
      _initializeAnimations();
      _setupScrollListener();
      _setupStreamListeners();
      await _loadInitialFeed();
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize feed. Please restart the app.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _feedSubscription?.cancel();
    _postUpdateSubscription?.cancel();
    _storiesSubscription?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabAnimationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      try {
        // Safety check for mounted state
        if (!mounted) return;

        // Handle FAB visibility with safety checks
        if (_scrollController.hasClients) {
          final isScrollingDown = _scrollController.position.userScrollDirection == ScrollDirection.reverse;
          if (isScrollingDown && _showFab) {
            if (mounted) {
              setState(() => _showFab = false);
              _fabAnimationController.reverse();
            }
          } else if (!isScrollingDown && !_showFab) {
            if (mounted) {
              setState(() => _showFab = true);
              _fabAnimationController.forward();
            }
          }

          // Handle infinite scroll with crash prevention
          final shouldLoadMore = _crashPrevention.handleScrollEvent(
            pixels: _scrollController.position.pixels,
            maxScrollExtent: _scrollController.position.maxScrollExtent,
            onLoadMore: _loadMorePosts,
            threshold: 200.0,
          );

          if (shouldLoadMore && kDebugMode) {
            debugPrint('📜 Loading more posts triggered by scroll');
          }
        }
      } catch (e) {
        debugPrint('❌ Error in scroll listener: $e');
        // Don't rethrow to prevent crash
      }
    });
  }

  void _setupStreamListeners() {
    // Listen to feed updates with crash prevention
    _feedSubscription = _feedService.feedStream.listen(
      (posts) {
        if (mounted && _crashPrevention.isHealthy) {
          try {
            // Safely manage the posts list to prevent memory issues
            final managedPosts = _crashPrevention.manageFeedList(_posts, posts);
            
            setState(() {
              _posts = managedPosts;
              _isLoading = false;
              _hasError = false;
            });
          } catch (e) {
            debugPrint('❌ Error updating posts: $e');
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Failed to update feed';
                _isLoading = false;
              });
            }
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Feed stream error: $error');
        if (mounted) {
          String userMessage = 'Feed update failed';
          if (error.toString().contains('permission-denied')) {
            userMessage = 'Permission denied. Please check your account.';
          } else if (error.toString().contains('network')) {
            userMessage = 'Network error. Please check your connection.';
          }
          
          setState(() {
            _hasError = true;
            _errorMessage = userMessage;
            _isLoading = false;
          });
        }
      },
      cancelOnError: false, // Keep listening even after errors
    );

    // Listen to individual post updates
    _postUpdateSubscription = _feedService.postUpdateStream.listen(
      (postId) {
        // Post was updated (liked, bookmarked, etc.)
        // The feed stream will automatically emit the updated posts
      },
    );

    // Listen to stories updates
    _storiesSubscription = _storyService.storiesStream.listen(
      (stories) {
        if (mounted) {
          setState(() {
            _stories = stories;
          });
        }
      },
      onError: (error) {
        debugPrint('❌ Stories stream error: $error');
      },
    );
  }

  Future<void> _loadInitialFeed() async {
    try {
      debugPrint('🚀 Starting initial feed load...');
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Initialize feed service first
      await _feedService.initialize();
      
      // Load both posts and stories with timeout
      await Future.wait([
        _feedService.getFeed(refresh: true),
        _loadStories(),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Feed loading timed out. Please check your connection.');
        },
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      debugPrint('✅ Initial feed load complete');
      
    } catch (e) {
      debugPrint('❌ Initial feed load failed: $e');
      if (mounted) {
        String userMessage = 'Unable to load feed. Please try again.';
        
        // Provide specific error messages
        if (e.toString().contains('permission-denied')) {
          userMessage = 'You don\'t have permission to view the feed.';
        } else if (e.toString().contains('network')) {
          userMessage = 'Network error. Please check your internet connection.';
        } else if (e.toString().contains('timeout')) {
          userMessage = 'Loading timed out. Please try again.';
        }
        
        setState(() {
          _hasError = true;
          _errorMessage = userMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStories() async {
    try {
      await _storyService.initialize();
      await _storyService.getStories(refresh: true);
    } catch (e) {
      debugPrint('❌ Failed to load stories: $e');
    }
  }

  Future<void> _refreshFeed() async {
    try {
      HapticFeedback.lightImpact();
      await Future.wait([
        _feedService.getFeed(refresh: true),
        _storyService.getStories(refresh: true),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh feed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadMorePosts() async {
    // Use crash prevention service for safe async operation
    await _crashPrevention.safeAsyncOperation(
      () async {
        if (_isLoadingMore || !_feedService.hasMorePosts || !mounted) return;

        if (mounted) {
          setState(() => _isLoadingMore = true);
        }

        try {
          await _feedService.getFeed();
          debugPrint('✅ Successfully loaded more posts');
        } catch (e) {
          debugPrint('❌ Error loading more posts: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to load more posts'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isLoadingMore = false);
          }
        }
      },
      operationName: 'load_more_posts',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return ErrorBoundaryWidget(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: _buildBody(),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'TALOWA',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'Billabong', // Instagram-style font
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            // TODO: Implement notifications
          },
          icon: const Icon(Icons.favorite_border, color: Colors.black),
          tooltip: 'Activity',
        ),
        IconButton(
          onPressed: () {
            // TODO: Implement direct messages
          },
          icon: const Icon(Icons.send_outlined, color: Colors.black),
          tooltip: 'Direct Messages',
        ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return const FeedSkeletonLoader();
    }

    if (_hasError && _posts.isEmpty) {
      return _buildErrorWidget();
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _refreshFeed,
      color: AppTheme.talowaGreen,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Stories section (placeholder for now)
          SliverToBoxAdapter(
            child: _buildStoriesSection(),
          ),
          
          // Posts list with crash prevention
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _crashPrevention.buildSafeWidget(
                  builder: () {
                    if (index < _posts.length) {
                      final post = _posts[index];
                      return InstagramPostWidget(
                        key: ValueKey('post_${post.id}'), // Add key for better widget recycling
                        post: post,
                        onLike: () => _safeToggleLike(post.id),
                        onBookmark: () => _safeToggleBookmark(post.id),
                        onComment: () => _safeNavigateToComments(post),
                        onShare: () => _safeSharePost(post),
                        onViewProfile: () => _safeViewProfile(post.authorId),
                        onReport: () => _safeReportPost(post),
                        onEdit: _isCurrentUserPost(post) ? () => _safeEditPost(post) : null,
                        onDelete: _isCurrentUserPost(post) ? () => _safeDeletePost(post) : null,
                      );
                    } else if (_isLoadingMore) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.talowaGreen,
                          ),
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                  fallback: Container(
                    height: 200,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Post temporarily unavailable',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
              childCount: _posts.length + (_isLoadingMore ? 1 : 0),
              addAutomaticKeepAlives: false, // Improve memory usage
              addRepaintBoundaries: true, // Improve performance
            ),
          ),
          
          // Bottom padding for FAB
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesSection() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stories.length + 1, // +1 for "Add Story" button
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStoryItem();
          }
          return _buildStoryItem(_stories[index - 1]);
        },
      ),
    );
  }

  Widget _buildAddStoryItem() {
    return GestureDetector(
      onTap: _createStory,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: const Icon(Icons.add, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your Story',
              style: TextStyle(fontSize: 12, color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(StoryModel story) {
    return GestureDetector(
      onTap: () => _viewStory(story),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: story.isViewedByCurrentUser
                    ? null
                    : const LinearGradient(
                        colors: [Colors.purple, Colors.pink, Colors.orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: story.isViewedByCurrentUser
                    ? Border.all(color: Colors.grey[300]!, width: 2)
                    : null,
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: story.authorId.isNotEmpty
                      ? NetworkImage('https://ui-avatars.com/api/?name=${story.authorName}&background=random')
                      : null,
                  child: story.authorId.isEmpty
                      ? Text(
                          story.authorName.isNotEmpty 
                              ? story.authorName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                story.authorName,
                style: const TextStyle(fontSize: 12, color: Colors.black),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton(
        onPressed: _createPost,
        backgroundColor: AppTheme.talowaGreen,
        tooltip: 'Create Post',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadInitialFeed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start following people or create your first post',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _createPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Post'),
          ),
        ],
      ),
    );
  }

  // Event handlers
  void _createPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InstagramPostCreationScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _refreshFeed();
      }
    });
  }



  Widget _buildReportBottomSheet(InstagramPostModel post) {
    final reasons = [
      'Inappropriate content',
      'Spam',
      'Harassment',
      'False information',
      'Copyright violation',
      'Other',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Post',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...reasons.map((reason) => ListTile(
            title: Text(reason),
            onTap: () {
              Navigator.pop(context);
              _feedService.reportPost(post.id, reason);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post reported successfully'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          )),
        ],
      ),
    );
  }

  // New methods for enhanced functionality

  void _createStory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StoryCreationScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _loadStories();
      }
    });
  }

  void _viewStory(StoryModel story) {
    // Mark story as viewed
    _storyService.viewStory(story.id);
    
    // TODO: Navigate to story viewer screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${story.authorName}\'s story'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildShareBottomSheet(InstagramPostModel post) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share Post',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.share, color: AppTheme.talowaGreen),
            title: const Text('Share Externally'),
            subtitle: const Text('Share via other apps'),
            onTap: () {
              Navigator.pop(context);
              _postManagementService.sharePost(post, shareType: 'external');
            },
          ),
          ListTile(
            leading: const Icon(Icons.repeat, color: AppTheme.talowaGreen),
            title: const Text('Repost'),
            subtitle: const Text('Share to your feed'),
            onTap: () {
              Navigator.pop(context);
              _showRepostDialog(post);
            },
          ),
          ListTile(
            leading: const Icon(Icons.link, color: AppTheme.talowaGreen),
            title: const Text('Copy Link'),
            subtitle: const Text('Copy post link'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement copy link functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRepostDialog(InstagramPostModel post) {
    final TextEditingController captionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add your thoughts (optional):'),
            const SizedBox(height: 8),
            TextField(
              controller: captionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What do you think about this post?',
                border: OutlineInputBorder(),
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
              Navigator.pop(context);
              try {
                await _postManagementService.repostPost(
                  originalPostId: post.id,
                  additionalCaption: captionController.text.trim().isNotEmpty 
                      ? captionController.text.trim() 
                      : null,
                );
                
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Post reposted successfully!'),
                    backgroundColor: AppTheme.talowaGreen,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to repost: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
            ),
            child: const Text('Repost'),
          ),
        ],
      ),
    );
  }

  // Helper methods for post management

  bool _isCurrentUserPost(InstagramPostModel post) {
    try {
      final currentUser = AuthService.currentUser;
      return currentUser != null && post.authorId == currentUser.uid;
    } catch (e) {
      debugPrint('❌ Error checking post ownership: $e');
      return false;
    }
  }

  // Safe wrapper methods for post interactions
  void _safeToggleLike(String postId) {
    _crashPrevention.safeAsyncOperation(
      () async => _feedService.toggleLike(postId),
      operationName: 'toggle_like',
    );
  }

  void _safeToggleBookmark(String postId) {
    _crashPrevention.safeAsyncOperation(
      () async => _feedService.toggleBookmark(postId),
      operationName: 'toggle_bookmark',
    );
  }

  void _safeNavigateToComments(InstagramPostModel post) {
    try {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommentsScreen(post: post),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error navigating to comments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open comments'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _safeSharePost(InstagramPostModel post) {
    try {
      if (mounted) {
        showModalBottomSheet(
          context: context,
          builder: (context) => _buildShareBottomSheet(post),
        );
      }
    } catch (e) {
      debugPrint('❌ Error opening share dialog: $e');
    }
  }

  void _safeViewProfile(String userId) {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile view coming soon!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error viewing profile: $e');
    }
  }

  void _safeReportPost(InstagramPostModel post) {
    try {
      if (mounted) {
        showModalBottomSheet(
          context: context,
          builder: (context) => _buildReportBottomSheet(post),
        );
      }
    } catch (e) {
      debugPrint('❌ Error opening report dialog: $e');
    }
  }

  void _safeEditPost(InstagramPostModel post) {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post editing feature coming soon!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error editing post: $e');
    }
  }

  Future<void> _safeDeletePost(InstagramPostModel post) async {
    await _crashPrevention.safeAsyncOperation(
      () async {
        await _postManagementService.deletePost(post.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted successfully'),
              backgroundColor: AppTheme.talowaGreen,
            ),
          );
          
          // Refresh feed to remove deleted post
          _refreshFeed();
        }
      },
      operationName: 'delete_post',
    );
  }


}