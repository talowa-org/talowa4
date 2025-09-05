// Enterprise Feed Widget for TALOWA
// High-performance feed widget with advanced optimizations

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../models/social_feed/index.dart';
import '../../services/performance/enterprise_performance_service.dart';
import '../../services/performance/performance_optimization_service.dart';
import '../social_feed/post_widget.dart';

class EnterpriseFeedWidget extends StatefulWidget {
  final Future<List<PostModel>> Function(int page, int pageSize)? onLoadPosts;
  final int pageSize;
  final bool enableVirtualScrolling;
  final bool enablePredictivePrefetch;
  final String? category;
  final String? userId;
  final VoidCallback? onRefresh;

  const EnterpriseFeedWidget({
    Key? key,
    this.onLoadPosts,
    this.pageSize = 10,
    this.enableVirtualScrolling = true,
    this.enablePredictivePrefetch = true,
    this.category,
    this.userId,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<EnterpriseFeedWidget> createState() => _EnterpriseFeedWidgetState();
}

class _EnterpriseFeedWidgetState extends State<EnterpriseFeedWidget>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  // Services
  final EnterprisePerformanceService _enterpriseService = EnterprisePerformanceService();
  final PerformanceOptimizationService _performanceService = PerformanceOptimizationService();
  
  // Controllers
  late ScrollController _scrollController;
  late AnimationController _refreshAnimationController;
  late Animation<double> _refreshAnimation;
  
  // State management
  List<PostModel> _posts = [];
  List<PostModel> _visiblePosts = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  String? _error;
  
  // Virtual scrolling
  final Map<int, double> _itemHeights = {};
  final Map<int, GlobalKey> _itemKeys = {};
  double _averageItemHeight = 200.0;
  int _firstVisibleIndex = 0;
  int _lastVisibleIndex = 0;
  
  // Performance monitoring
  final Stopwatch _renderStopwatch = Stopwatch();
  Timer? _performanceTimer;
  
  // Viewport management
  final int _bufferSize = 5;
  final double _preloadThreshold = 0.8;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeServices();
    _loadInitialData();
    _startPerformanceMonitoring();
  }

  void _initializeControllers() {
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _refreshAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _refreshAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeServices() async {
    await _enterpriseService.initialize();
    await _performanceService.initialize();
  }

  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _optimizePerformance();
    });
    
    // Listen to performance reports
    _enterpriseService.performanceReportStream.listen((report) {
      debugPrint('Performance Report: $report');
    });
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final posts = await _enterpriseService.advancedLazyLoad(
        page: 0,
        pageSize: widget.pageSize,
        category: widget.category,
        userId: widget.userId,
        enablePrefetch: widget.enablePredictivePrefetch,
      );

      setState(() {
        _posts = posts;
        _currentPage = 0;
        _hasMoreData = posts.length == widget.pageSize;
        _updateVisiblePosts();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load posts: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final newPosts = await _enterpriseService.advancedLazyLoad(
        page: nextPage,
        pageSize: widget.pageSize,
        category: widget.category,
        userId: widget.userId,
        enablePrefetch: widget.enablePredictivePrefetch,
      );

      setState(() {
        _posts.addAll(newPosts);
        _currentPage = nextPage;
        _hasMoreData = newPosts.length == widget.pageSize;
        _updateVisiblePosts();
      });
    } catch (e) {
      debugPrint('Error loading more data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    _refreshAnimationController.forward();

    try {
      // Clear cache for fresh data
      await _enterpriseService.intelligentCacheCleanup();
      
      final posts = await _enterpriseService.advancedLazyLoad(
        page: 0,
        pageSize: widget.pageSize,
        category: widget.category,
        userId: widget.userId,
        enablePrefetch: widget.enablePredictivePrefetch,
      );

      setState(() {
        _posts = posts;
        _currentPage = 0;
        _hasMoreData = posts.length == widget.pageSize;
        _error = null;
        _updateVisiblePosts();
      });

      widget.onRefresh?.call();
    } catch (e) {
      setState(() {
        _error = 'Failed to refresh: $e';
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
      
      _refreshAnimationController.reverse();
    }
  }

  void _onScroll() {
    if (!widget.enableVirtualScrolling) return;

    final scrollOffset = _scrollController.offset;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    
    // Update visible range
    _updateVisibleRange(scrollOffset);
    
    // Load more data when approaching end
    if (scrollOffset >= maxScrollExtent * _preloadThreshold) {
      _loadMoreData();
    }
  }

  void _updateVisibleRange(double scrollOffset) {
    final viewportHeight = MediaQuery.of(context).size.height;
    
    // Calculate visible range with buffer
    final startOffset = scrollOffset - (_averageItemHeight * _bufferSize);
    final endOffset = scrollOffset + viewportHeight + (_averageItemHeight * _bufferSize);
    
    int firstIndex = (startOffset / _averageItemHeight).floor().clamp(0, _posts.length - 1);
    int lastIndex = (endOffset / _averageItemHeight).ceil().clamp(0, _posts.length - 1);
    
    if (firstIndex != _firstVisibleIndex || lastIndex != _lastVisibleIndex) {
      setState(() {
        _firstVisibleIndex = firstIndex;
        _lastVisibleIndex = lastIndex;
        _updateVisiblePosts();
      });
    }
  }

  void _updateVisiblePosts() {
    if (!widget.enableVirtualScrolling) {
      _visiblePosts = _posts;
      return;
    }

    final startIndex = _firstVisibleIndex.clamp(0, _posts.length);
    final endIndex = (_lastVisibleIndex + 1).clamp(0, _posts.length);
    
    _visiblePosts = _posts.sublist(startIndex, endIndex);
  }

  void _optimizePerformance() {
    // Cleanup unused item keys
    final keysToRemove = <int>[];
    for (final key in _itemKeys.keys) {
      if (key < _firstVisibleIndex - _bufferSize || key > _lastVisibleIndex + _bufferSize) {
        keysToRemove.add(key);
      }
    }
    
    for (final key in keysToRemove) {
      _itemKeys.remove(key);
    }

    // Update average item height
    if (_itemHeights.isNotEmpty) {
      final totalHeight = _itemHeights.values.reduce((a, b) => a + b);
      _averageItemHeight = totalHeight / _itemHeights.length;
    }

    // Trigger cache cleanup
    _enterpriseService.intelligentCacheCleanup();
  }

  Widget _buildPost(PostModel post, int index) {
    final globalIndex = widget.enableVirtualScrolling ? _firstVisibleIndex + index : index;
    
    // Ensure we have a key for this item
    _itemKeys[globalIndex] ??= GlobalKey();
    
    return VisibilityDetector(
      key: Key('post_visibility_$globalIndex'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          // Track item height for virtual scrolling
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final renderBox = _itemKeys[globalIndex]?.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              _itemHeights[globalIndex] = renderBox.size.height;
            }
          });
        }
      },
      child: Container(
        key: _itemKeys[globalIndex],
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: PostWidget(
          post: post,
          onLike: (postId) => _handlePostInteraction('like', postId),
          onComment: (postId) => _handlePostInteraction('comment', postId),
          onShare: (postId) => _handlePostInteraction('share', postId),
        ),
      ),
    );
  }

  void _handlePostInteraction(String action, String postId) {
    // Handle post interactions with performance tracking
    final stopwatch = Stopwatch()..start();
    
    // Implement interaction logic here
    debugPrint('Post $action: $postId');
    
    stopwatch.stop();
    debugPrint('Interaction $action took ${stopwatch.elapsedMilliseconds}ms');
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feed_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No posts available',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull to refresh or check back later',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    _renderStopwatch.start();

    if (_error != null && _posts.isEmpty) {
      return _buildErrorWidget();
    }

    if (_posts.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Refresh indicator
          if (_isRefreshing)
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _refreshAnimation,
                builder: (context, child) {
                  return Container(
                    height: 60 * _refreshAnimation.value,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      value: _refreshAnimation.value,
                    ),
                  );
                },
              ),
            ),
          
          // Posts list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < _visiblePosts.length) {
                  return _buildPost(_visiblePosts[index], index);
                } else if (_hasMoreData && index == _visiblePosts.length) {
                  return _buildLoadingIndicator();
                }
                return null;
              },
              childCount: _visiblePosts.length + (_hasMoreData ? 1 : 0),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshAnimationController.dispose();
    _performanceTimer?.cancel();
    _enterpriseService.dispose();
    super.dispose();
  }
}
