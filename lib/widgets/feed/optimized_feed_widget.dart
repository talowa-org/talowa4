// Optimized Feed Widget for TALOWA
// Implements Task 21: Performance optimization - Lazy Loading & Efficient Rendering

import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../services/performance/performance_optimization_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../common/cached_network_image_widget.dart';

class OptimizedFeedWidget extends StatefulWidget {
  final Future<List<PostModel>> Function(int page, int pageSize) onLoadPosts;
  final Function(PostModel post)? onPostTap;
  final Function(PostModel post)? onLikeTap;
  final Function(PostModel post)? onCommentTap;
  final Function(PostModel post)? onShareTap;
  final int pageSize;
  final bool enableVirtualScrolling;

  const OptimizedFeedWidget({
    super.key,
    required this.onLoadPosts,
    this.onPostTap,
    this.onLikeTap,
    this.onCommentTap,
    this.onShareTap,
    this.pageSize = 20,
    this.enableVirtualScrolling = true,
  });

  @override
  State<OptimizedFeedWidget> createState() => _OptimizedFeedWidgetState();
}

class _OptimizedFeedWidgetState extends State<OptimizedFeedWidget>
    with AutomaticKeepAliveClientMixin {
  final PerformanceOptimizationService _performanceService = PerformanceOptimizationService();
  final ScrollController _scrollController = ScrollController();
  
  List<PostModel> _allPosts = [];
  List<PostModel> _visiblePosts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  int _currentPage = 0;
  
  // Virtual scrolling
  int _visibleStartIndex = 0;
  int _visibleEndIndex = 0;
  final int _bufferSize = 5;
  
  // Performance tracking
  final Stopwatch _renderStopwatch = Stopwatch();
  Timer? _scrollDebounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializePerformanceService();
    _setupScrollListener();
    _loadInitialPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePerformanceService() async {
    await _performanceService.initialize();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Debounce scroll events for better performance
      _scrollDebounceTimer?.cancel();
      _scrollDebounceTimer = Timer(const Duration(milliseconds: 50), () {
        _handleScroll();
      });
    });
  }

  void _handleScroll() {
    // Load more posts when near bottom
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 1000) {
      _loadMorePosts();
    }
    
    // Update virtual scrolling if enabled
    if (widget.enableVirtualScrolling) {
      _updateVisibleItems();
    }
  }

  void _updateVisibleItems() {
    if (_allPosts.isEmpty) return;
    
    final scrollOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    const itemHeight = 200.0; // Estimated item height
    
    final startIndex = (scrollOffset / itemHeight).floor();
    final endIndex = ((scrollOffset + viewportHeight) / itemHeight).ceil();
    
    final newVisibleStartIndex = startIndex.clamp(0, _allPosts.length);
    final newVisibleEndIndex = endIndex.clamp(0, _allPosts.length);
    
    if (newVisibleStartIndex != _visibleStartIndex || 
        newVisibleEndIndex != _visibleEndIndex) {
      setState(() {
        _visibleStartIndex = newVisibleStartIndex;
        _visibleEndIndex = newVisibleEndIndex;
        
        if (widget.enableVirtualScrolling) {
          _visiblePosts = _performanceService.getVirtualScrollItems(
            allItems: _allPosts,
            visibleStartIndex: _visibleStartIndex,
            visibleEndIndex: _visibleEndIndex,
            bufferSize: _bufferSize,
          );
        } else {
          _visiblePosts = _allPosts;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    _renderStopwatch.reset();
    _renderStopwatch.start();
    
    final widget = _buildOptimizedList();
    
    _renderStopwatch.stop();
    // Record render time for performance monitoring
    
    return widget;
  }

  Widget _buildOptimizedList() {
    if (_isLoading && _allPosts.isEmpty) {
      return const LoadingWidget(message: 'Loading posts...');
    }

    if (_allPosts.isEmpty) {
      return _buildEmptyState();
    }

    final postsToShow = widget.enableVirtualScrolling ? _visiblePosts : _allPosts;

    return RefreshIndicator(
      onRefresh: _refreshPosts,
      color: AppTheme.talowaGreen,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: postsToShow.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < postsToShow.length) {
            return _buildOptimizedPostItem(postsToShow[index], index);
          } else {
            return _buildLoadingIndicator();
          }
        },
        // Performance optimizations
        cacheExtent: 1000, // Cache items outside viewport
        addAutomaticKeepAlives: false, // Don't keep all items alive
        addRepaintBoundaries: true, // Isolate repaints
      ),
    );
  }

  Widget _buildOptimizedPostItem(PostModel post, int index) {
    return RepaintBoundary(
      key: ValueKey(post.id),
      child: OptimizedPostCard(
        post: post,
        onTap: () => widget.onPostTap?.call(post),
        onLike: () => widget.onLikeTap?.call(post),
        onComment: () => widget.onCommentTap?.call(post),
        onShare: () => widget.onShareTap?.call(post),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No posts available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Pull to refresh or check back later',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final posts = await _performanceService.lazyLoadPosts(
        page: 0,
        pageSize: widget.pageSize,
      );

      setState(() {
        _allPosts = posts;
        _visiblePosts = widget.enableVirtualScrolling 
            ? posts.take(widget.pageSize).toList()
            : posts;
        _currentPage = 0;
        _hasMorePosts = posts.length == widget.pageSize;
        _isLoading = false;
      });

      // Preload next batch in background
      if (_hasMorePosts) {
        _preloadNextBatch();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (kDebugMode) {
        debugPrint('Error loading initial posts: $e');
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final morePosts = await _performanceService.lazyLoadPosts(
        page: nextPage,
        pageSize: widget.pageSize,
      );

      setState(() {
        _allPosts.addAll(morePosts);
        if (!widget.enableVirtualScrolling) {
          _visiblePosts = _allPosts;
        }
        _currentPage = nextPage;
        _hasMorePosts = morePosts.length == widget.pageSize;
        _isLoadingMore = false;
      });

      // Update virtual scrolling
      if (widget.enableVirtualScrolling) {
        _updateVisibleItems();
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      if (kDebugMode) {
        debugPrint('Error loading more posts: $e');
      }
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _allPosts.clear();
      _visiblePosts.clear();
      _currentPage = 0;
      _hasMorePosts = true;
    });

    await _loadInitialPosts();
  }

  Future<void> _preloadNextBatch() async {
    // Preload next batch in background for smoother scrolling
    try {
      await _performanceService.lazyLoadPosts(
        page: _currentPage + 1,
        pageSize: widget.pageSize,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error preloading next batch: $e');
      }
    }
  }
}

class OptimizedPostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  const OptimizedPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
  });

  @override
  State<OptimizedPostCard> createState() => _OptimizedPostCardState();
}

class _OptimizedPostCardState extends State<OptimizedPostCard>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => false; // Don't keep alive for memory efficiency

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildContent(),
              if (widget.post.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildImages(),
              ],
              const SizedBox(height: 12),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.talowaGreen,
          child: Text(
            widget.post.authorName.isNotEmpty 
                ? widget.post.authorName[0].toUpperCase()
                : '?',
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
                widget.post.authorName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                _formatTime(widget.post.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        _buildCategoryBadge(),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.post.title != null) ...[
          Text(
            widget.post.title!,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          widget.post.content,
          style: const TextStyle(fontSize: 16, height: 1.4),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.post.hashtags.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildHashtags(),
        ],
      ],
    );
  }

  Widget _buildImages() {
    if (widget.post.imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: CachedNetworkImageWidget(
            imageUrl: widget.post.imageUrls.first,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: widget.post.imageUrls.length.clamp(0, 3),
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImageWidget(
                  imageUrl: widget.post.imageUrls[index],
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildActions() {
    return Row(
      children: [
        _buildActionButton(
          icon: widget.post.isLikedByCurrentUser 
              ? Icons.favorite 
              : Icons.favorite_border,
          count: widget.post.likesCount,
          color: widget.post.isLikedByCurrentUser ? Colors.red : null,
          onTap: widget.onLike,
        ),
        _buildActionButton(
          icon: Icons.comment_outlined,
          count: widget.post.commentsCount,
          onTap: widget.onComment,
        ),
        _buildActionButton(
          icon: Icons.share_outlined,
          count: widget.post.sharesCount,
          onTap: widget.onShare,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    Color? color,
    VoidCallback? onTap,
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
              Icon(icon, size: 20, color: color ?? Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: color ?? Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge() {
    final categoryInfo = _getCategoryInfo(widget.post.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: categoryInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryInfo['color'].withOpacity(0.3)),
      ),
      child: Text(
        categoryInfo['label'],
        style: TextStyle(
          fontSize: 10,
          color: categoryInfo['color'],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildHashtags() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: widget.post.hashtags.take(3).map((hashtag) => Text(
        '#$hashtag',
        style: const TextStyle(
          color: AppTheme.talowaGreen,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      )).toList(),
    );
  }

  Map<String, dynamic> _getCategoryInfo(PostCategory category) {
    switch (category) {
      case PostCategory.successStory:
        return {'label': 'Success', 'color': Colors.green};
      case PostCategory.legalUpdate:
        return {'label': 'Legal', 'color': Colors.blue};
      case PostCategory.announcement:
        return {'label': 'News', 'color': Colors.orange};
      case PostCategory.emergency:
        return {'label': 'Emergency', 'color': Colors.red};
      default:
        return {'label': 'General', 'color': Colors.grey};
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
    } else {
      return '${difference.inDays}d';
    }
  }
}