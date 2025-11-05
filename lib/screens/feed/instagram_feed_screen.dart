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

class InstagramFeedScreen extends StatefulWidget {
  const InstagramFeedScreen({super.key});

  @override
  State<InstagramFeedScreen> createState() => _InstagramFeedScreenState();
}

class _InstagramFeedScreenState extends State<InstagramFeedScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  // Services
  final InstagramFeedService _feedService = InstagramFeedService();
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  // Animation controllers
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  
  // State
  List<InstagramPostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showFab = true;
  
  // Streams
  StreamSubscription<List<InstagramPostModel>>? _feedSubscription;
  StreamSubscription<String>? _postUpdateSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();
    _setupStreamListeners();
    _loadInitialFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _feedSubscription?.cancel();
    _postUpdateSubscription?.cancel();
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
      // Handle FAB visibility
      final isScrollingDown = _scrollController.position.userScrollDirection == ScrollDirection.reverse;
      if (isScrollingDown && _showFab) {
        setState(() => _showFab = false);
        _fabAnimationController.reverse();
      } else if (!isScrollingDown && !_showFab) {
        setState(() => _showFab = true);
        _fabAnimationController.forward();
      }

      // Handle infinite scroll
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    });
  }

  void _setupStreamListeners() {
    // Listen to feed updates
    _feedSubscription = _feedService.feedStream.listen(
      (posts) {
        if (mounted) {
          setState(() {
            _posts = posts;
            _isLoading = false;
            _hasError = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = error.toString();
            _isLoading = false;
          });
        }
      },
    );

    // Listen to individual post updates
    _postUpdateSubscription = _feedService.postUpdateStream.listen(
      (postId) {
        // Post was updated (liked, bookmarked, etc.)
        // The feed stream will automatically emit the updated posts
      },
    );
  }

  Future<void> _loadInitialFeed() async {
    try {
      debugPrint('🚀 Starting initial feed load...');
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      final posts = await _feedService.getFeed(refresh: true);
      debugPrint('✅ Initial feed load complete: ${posts.length} posts');
      
    } catch (e) {
      debugPrint('❌ Initial feed load failed: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshFeed() async {
    try {
      HapticFeedback.lightImpact();
      await _feedService.getFeed(refresh: true);
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
    if (_isLoadingMore || !_feedService.hasMorePosts) return;

    setState(() => _isLoadingMore = true);

    try {
      await _feedService.getFeed();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more posts: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
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
          
          // Posts list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < _posts.length) {
                  return InstagramPostWidget(
                    post: _posts[index],
                    onLike: () => _feedService.toggleLike(_posts[index].id),
                    onBookmark: () => _feedService.toggleBookmark(_posts[index].id),
                    onComment: () => _navigateToComments(_posts[index]),
                    onShare: () => _sharePost(_posts[index]),
                    onViewProfile: () => _viewProfile(_posts[index].authorId),
                    onReport: () => _reportPost(_posts[index]),
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
              childCount: _posts.length + (_isLoadingMore ? 1 : 0),
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
        itemCount: 10, // Placeholder count
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStoryItem();
          }
          return _buildStoryItem(index);
        },
      ),
    );
  }

  Widget _buildAddStoryItem() {
    return Container(
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
    );
  }

  Widget _buildStoryItem(int index) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.purple, Colors.pink, Colors.orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                child: Text('U$index'),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'User $index',
            style: const TextStyle(fontSize: 12, color: Colors.black),
            overflow: TextOverflow.ellipsis,
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
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create Post',
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

  void _navigateToComments(InstagramPostModel post) {
    // TODO: Navigate to comments screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comments feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sharePost(InstagramPostModel post) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _viewProfile(String userId) {
    // TODO: Navigate to user profile
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile view coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reportPost(InstagramPostModel post) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildReportBottomSheet(post),
    );
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
}