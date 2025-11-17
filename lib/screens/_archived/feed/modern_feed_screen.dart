// Modern Social Feed Screen - Latest 2024 Design
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/post_model.dart';
import '../../services/social_feed/enhanced_feed_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../post_creation/simple_post_creation_screen.dart';
import '../../models/social_feed/story_model.dart';
import '../../services/social_feed/stories_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/notifications/notification_badge_widget.dart';
import 'stories_screen.dart';
import 'story_creation_screen.dart';
import 'post_comments_screen.dart';

import '../../utils/role_utils.dart';
import '../../utils/error_handler.dart';

class ModernFeedScreen extends StatefulWidget {
  const ModernFeedScreen({super.key});

  @override
  State<ModernFeedScreen> createState() => _ModernFeedScreenState();
}

class _ModernFeedScreenState extends State<ModernFeedScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  final PageController _pageController = PageController();

  // State management
  List<PostModel> _posts = [];
  Map<String, List<StoryModel>> _storiesByAuthor = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasMorePosts = true;
  int _currentTabIndex = 0;
  
  // Filtering and search
  PostCategory? _selectedCategory;
  String? _searchQuery;
  final FeedSortOption _sortOption = FeedSortOption.newest;

  // Pagination
  static const int _postsPerPage = 10;
  DocumentSnapshot? _lastDocument;

  // Enhanced feed service
  late EnhancedFeedService _feedService;

  // Tab options
  final List<String> _feedTabs = ['For You', 'Following', 'Trending', 'Local'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // Initialize enhanced feed service
    _feedService = EnhancedFeedService();
    _initializeFeedService();
    
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
    
    // Start FAB animation
    _fabAnimationController.forward();
  }

  Future<void> _initializeFeedService() async {
    try {
      await _feedService.initialize();
      _loadFeed();
      _loadStories();
    } catch (e) {
      debugPrint('Error initializing feed service: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _pageController.dispose();
    _feedService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildModernAppBar(),
      body: _buildModernBody(),
      floatingActionButton: _buildModernFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.talowaGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'TALOWA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _openSearch,
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search',
        ),
        const NotificationBadgeWidget(),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: _buildFeedTabs(),
      ),
    );
  }

  Widget _buildFeedTabs() {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _feedTabs.length,
        itemBuilder: (context, index) {
          final isSelected = index == _currentTabIndex;
          return GestureDetector(
            onTap: () => _switchTab(index),
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.talowaGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.talowaGreen : Colors.grey[300]!,
                ),
              ),
              child: Text(
                _feedTabs[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernBody() {
    if (_isLoading && _posts.isEmpty) {
      return const LoadingWidget(message: 'Loading your feed...');
    }

    if (_hasError && _posts.isEmpty) {
      return _buildErrorState();
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: AppTheme.talowaGreen,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Stories section
          SliverToBoxAdapter(
            child: _buildModernStoriesSection(),
          ),
          
          // Posts section
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < _posts.length) {
                  return _buildModernPostItem(_posts[index]);
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

  Widget _buildModernPostItem(PostModel post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.1),
          bottom: BorderSide(color: Colors.grey, width: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author header
            _buildModernAuthorHeader(post),
            
            const SizedBox(height: 12),
            
            // Content
            _buildPostContent(post),
            
            // Media
            if (post.hasMedia) ...[
              const SizedBox(height: 12),
              _buildModernMediaSection(post),
            ],
            
            // Hashtags
            if (post.hashtags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildHashtagsSection(post.hashtags),
            ],
            
            const SizedBox(height: 16),
            
            // Engagement bar
            _buildModernEngagementBar(post),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAuthorHeader(PostModel post) {
    return Row(
      children: [
        // Profile picture
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getRoleColor(post.authorRole),
            border: Border.all(color: Colors.grey[200]!, width: 2),
          ),
          child: Center(
            child: Text(
              post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Author info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    post.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  if (post.authorRole == 'coordinator') ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.blue[600],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _formatTime(post.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (post.location.isNotEmpty) ...[
                    Text(
                      ' • ${post.location}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        
        // Category badge
        _buildModernCategoryBadge(post.category),
        
        // More options
        IconButton(
          onPressed: () => _showPostOptions(post),
          icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
          iconSize: 20,
        ),
      ],
    );
  }

  Widget _buildPostContent(PostModel post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.title != null) ...[
          Text(
            post.title!,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          post.content,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildModernMediaSection(PostModel post) {
    final allMedia = [...post.imageUrls, ...post.videoUrls];
    if (allMedia.isEmpty) return const SizedBox.shrink();

    if (allMedia.length == 1) {
      return _buildSingleMedia(allMedia.first);
    } else {
      return _buildMultipleMedia(allMedia);
    }
  }

  Widget _buildSingleMedia(String mediaUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.image_not_supported, 
                      color: Colors.grey, size: 48),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMultipleMedia(List<String> mediaUrls) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mediaUrls.length,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: EdgeInsets.only(right: index < mediaUrls.length - 1 ? 8 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                mediaUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHashtagsSection(List<String> hashtags) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: hashtags.map((hashtag) => GestureDetector(
        onTap: () => _searchByHashtag(hashtag),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.talowaGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.talowaGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            '#$hashtag',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.talowaGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildModernEngagementBar(PostModel post) {
    return Column(
      children: [
        // Engagement stats
        if (post.likesCount > 0 || post.commentsCount > 0 || post.sharesCount > 0) ...[
          Row(
            children: [
              if (post.likesCount > 0) ...[
                Icon(Icons.favorite, size: 16, color: Colors.red[400]),
                const SizedBox(width: 4),
                Text(
                  '${post.likesCount}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
              if (post.likesCount > 0 && (post.commentsCount > 0 || post.sharesCount > 0))
                Text(' • ', style: TextStyle(color: Colors.grey[400])),
              if (post.commentsCount > 0) ...[
                Text(
                  '${post.commentsCount} comments',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
              if (post.commentsCount > 0 && post.sharesCount > 0)
                Text(' • ', style: TextStyle(color: Colors.grey[400])),
              if (post.sharesCount > 0) ...[
                Text(
                  '${post.sharesCount} shares',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 8),
        ],
        
        // Action buttons
        Row(
          children: [
            _buildModernEngagementButton(
              icon: post.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
              label: 'Like',
              color: post.isLikedByCurrentUser ? Colors.red : Colors.grey[600],
              onTap: () => _handleLike(post),
            ),
            _buildModernEngagementButton(
              icon: Icons.chat_bubble_outline,
              label: 'Comment',
              color: Colors.grey[600],
              onTap: () => _handleComment(post),
            ),
            _buildModernEngagementButton(
              icon: Icons.share_outlined,
              label: 'Share',
              color: Colors.grey[600],
              onTap: () => _handleShare(post),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernEngagementButton({
    required IconData icon,
    required String label,
    required Color? color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCategoryBadge(PostCategory category) {
    final categoryInfo = _getCategoryInfo(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: categoryInfo['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStoriesSection() {
    if (_storiesByAuthor.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.1),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _storiesByAuthor.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStoryButton();
          }
          
          final authorIndex = index - 1;
          final authorId = _storiesByAuthor.keys.elementAt(authorIndex);
          final authorStories = _storiesByAuthor[authorId]!;
          final latestStory = authorStories.last;

          return _buildModernStoryItem(
            story: latestStory,
            stories: authorStories,
            onTap: () => _openStories(authorStories, 0),
          );
        },
      ),
    );
  }

  Widget _buildAddStoryButton() {
    return GestureDetector(
      onTap: _createStory,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.talowaGreen, AppTheme.talowaGreen.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
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

  Widget _buildModernStoryItem({
    required StoryModel story,
    required List<StoryModel> stories,
    required VoidCallback onTap,
  }) {
    final hasUnviewedStories = stories.any((s) => 
        !s.reactions.containsKey(AuthService.currentUser?.uid));
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnviewedStories
                    ? const LinearGradient(
                        colors: [Colors.purple, Colors.pink, Colors.orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: Border.all(
                  color: hasUnviewedStories ? Colors.transparent : Colors.grey[300]!,
                  width: 3,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: story.mediaType == 'image'
                      ? Image.network(
                          story.mediaUrl,
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: AppTheme.talowaGreen.withValues(alpha: 0.2),
                              child: Center(
                                child: Text(
                                  story.authorName.isNotEmpty 
                                      ? story.authorName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppTheme.talowaGreen,
                                    fontSize: 20,
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
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 68,
              child: Text(
                story.authorName.split(' ').first,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hasUnviewedStories ? Colors.black87 : Colors.grey[600],
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

  Widget _buildModernFAB() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: _createPost,
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.edit),
        label: const Text('Post', style: TextStyle(fontWeight: FontWeight.w600)),
        heroTag: "modern_feed_create_post",
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Failed to load feed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _loadFeed();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
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
              'Welcome to TALOWA!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start connecting with your community and sharing your stories.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createPost,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  // Data loading methods
  Future<void> _loadFeed() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      _lastDocument = null; // Reset pagination
    });

    try {
      List<PostModel> posts = [];
      
      switch (_currentTabIndex) {
        case 0: // For You
          posts = await _feedService.getPersonalizedFeed(limit: _postsPerPage);
          break;
        case 1: // Following
          posts = await _feedService.getFeedPosts(
            limit: _postsPerPage,
            sortOption: FeedSortOption.newest,
          );
          break;
        case 2: // Trending
          posts = await _feedService.getFeedPosts(
            limit: _postsPerPage,
            sortOption: FeedSortOption.mostLiked,
          );
          break;
        case 3: // Local
          posts = await _feedService.getFeedPosts(
            limit: _postsPerPage,
            location: 'Telangana', // Get from user preferences
          );
          break;
        default:
          posts = await _feedService.getFeedPosts(
            limit: _postsPerPage,
            category: _selectedCategory,
            searchQuery: _searchQuery,
            sortOption: _sortOption,
          );
      }
      
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          _hasMorePosts = posts.length == _postsPerPage;
        });
      }
      
    } catch (e) {
      final errorMessage = ErrorHandler.handleError(e, context: 'Loading feed');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = errorMessage;
          _posts = []; // Ensure posts list is not null
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _posts.isEmpty || !mounted) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      List<PostModel> morePosts = [];
      
      switch (_currentTabIndex) {
        case 0: // For You
          morePosts = await _feedService.getPersonalizedFeed(
            limit: _postsPerPage,
            lastDocument: _lastDocument,
          );
          break;
        case 1: // Following
          morePosts = await _feedService.getFeedPosts(
            limit: _postsPerPage,
            lastDocument: _lastDocument,
            sortOption: FeedSortOption.newest,
          );
          break;
        case 2: // Trending
          morePosts = await _feedService.getFeedPosts(
            limit: _postsPerPage,
            lastDocument: _lastDocument,
            sortOption: FeedSortOption.mostLiked,
          );
          break;
        case 3: // Local
          morePosts = await _feedService.getFeedPosts(
            limit: _postsPerPage,
            lastDocument: _lastDocument,
            location: 'Telangana',
          );
          break;
        default:
          morePosts = await _feedService.getFeedPosts(
            limit: _postsPerPage,
            lastDocument: _lastDocument,
            category: _selectedCategory,
            searchQuery: _searchQuery,
            sortOption: _sortOption,
          );
      }

      if (mounted && morePosts.isNotEmpty) {
        setState(() {
          _posts.addAll(morePosts);
          _isLoadingMore = false;
          _hasMorePosts = morePosts.length == _postsPerPage;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMorePosts = false;
        });
      }
      
    } catch (e) {
      final errorMessage = ErrorHandler.handleError(e, context: 'Loading more posts');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        
        // Only show error message if it should be shown to user
        if (ErrorHandler.shouldShowToUser(e)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              action: ErrorHandler.isRecoverable(e) ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _loadMorePosts,
              ) : null,
            ),
          );
        }
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

  Future<void> _loadStories() async {
    try {
      final storiesByAuthor = await StoriesService().getStoriesByAuthor(limit: 20);
      if (mounted) {
        setState(() {
          _storiesByAuthor = storiesByAuthor;
        });
      }
    } catch (e) {
      debugPrint('Error loading stories: $e');
    }
  }

  // Event handlers
  void _switchTab(int index) {
    if (_currentTabIndex != index) {
      setState(() {
        _currentTabIndex = index;
        _posts.clear();
      });
      _loadFeed();
    }
  }

  void _onScroll() {
    ErrorHandler.safeExecuteSync(() {
      if (!mounted || 
          !_scrollController.hasClients ||
          _scrollController.position.maxScrollExtent == 0) {
        return;
      }
      
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    }, context: 'Feed scroll handling');
  }

  void _handleLike(PostModel post) async {
    if (!mounted) return;
    
    // Optimistic update
    final originalPost = post;
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index != -1) {
      setState(() {
        final isLiked = post.isLikedByCurrentUser;
        _posts[index] = post.copyWith(
          isLikedByCurrentUser: !isLiked,
          likesCount: isLiked ? post.likesCount - 1 : post.likesCount + 1,
        );
      });
    }
    
    try {
      await _feedService.toggleLike(post.id);
      HapticFeedback.lightImpact();
    } catch (e) {
      // Rollback on error
      if (mounted && index != -1) {
        setState(() {
          _posts[index] = originalPost;
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
      _refreshFeed();
    });
  }

  void _handleShare(PostModel post) {
    _showShareDialog(post);
  }

  void _showShareDialog(PostModel post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share Post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.copy, color: Colors.blue),
              ),
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
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.message, color: Colors.green),
              ),
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
          ],
        ),
      ),
    );
  }

  void _incrementShareCount(PostModel post) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index != -1) {
      setState(() {
        _posts[index] = post.copyWith(
          sharesCount: post.sharesCount + 1,
        );
      });
    }
    
    try {
      await _feedService.sharePost(post.id);
    } catch (e) {
      debugPrint('Error sharing post: $e');
    }
  }

  void _showPostOptions(PostModel post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Save Post'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post saved!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report Post'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post reported')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: ModernFeedSearchDelegate(
        onSearch: (query) {
          setState(() {
            _searchQuery = query;
          });
          _loadFeed();
        },
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

  void _createStory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StoryCreationScreen(),
      ),
    );
    
    if (result != null) {
      _loadStories();
    }
  }

  // Helper methods
  Color _getRoleColor(String? role) {
    return RoleUtils.getColor(role);
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
      case PostCategory.agriculture:
        return {'label': 'Agriculture', 'color': Colors.green[700], 'icon': Icons.agriculture};
      case PostCategory.education:
        return {'label': 'Education', 'color': Colors.teal, 'icon': Icons.school};
      case PostCategory.health:
        return {'label': 'Health', 'color': Colors.pink, 'icon': Icons.health_and_safety};
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
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

// Modern Feed Search Delegate
class ModernFeedSearchDelegate extends SearchDelegate<String> {
  final Function(String) onSearch;

  ModernFeedSearchDelegate({required this.onSearch});

  @override
  String get searchFieldLabel => 'Search posts, people, hashtags...';

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
      'community meeting',
      'education',
      'health tips',
    ];

    final filteredSuggestions = suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = filteredSuggestions[index];
        return ListTile(
          leading: const Icon(Icons.search, color: Colors.grey),
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