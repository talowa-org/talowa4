// Optimized ListView - High-performance list widget with virtualization
// Comprehensive list optimization for TALOWA platform performance

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../mixins/performance_tracking_mixin.dart';

/// High-performance ListView with automatic virtualization and optimization
class OptimizedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Future<List<T>> Function()? onRefresh;
  final Future<List<T>> Function()? onLoadMore;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool enableVirtualization;
  final int? maxCacheExtent;
  final double? itemExtent;
  final Widget? separator;
  final bool enablePerformanceTracking;
  final String? performanceTag;
  
  const OptimizedListView({
    Key? key,
    required this.items,
    required this.itemBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.onRefresh,
    this.onLoadMore,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.enableVirtualization = true,
    this.maxCacheExtent,
    this.itemExtent,
    this.separator,
    this.enablePerformanceTracking = kDebugMode,
    this.performanceTag,
  }) : super(key: key);
  
  @override
  State<OptimizedListView<T>> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>>
    with PerformanceTrackingMixin, AutomaticKeepAliveClientMixin {
  
  late ScrollController _scrollController;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  
  // Performance optimization
  final Map<int, Widget> _widgetCache = {};
  final Set<int> _visibleIndices = {};
  Timer? _scrollEndTimer;
  double _lastScrollPosition = 0.0;
  
  // Configuration
  static const Duration scrollEndDelay = Duration(milliseconds: 150);
  static const double loadMoreThreshold = 200.0;
  static const int maxCacheSize = 100;
  
  @override
  String get performanceWidgetName => 
      'OptimizedListView${widget.performanceTag != null ? '_${widget.performanceTag}' : ''}';
  
  @override
  Map<String, dynamic>? get performanceContext => {
    'itemCount': widget.items.length,
    'enableVirtualization': widget.enableVirtualization,
    'cacheSize': _widgetCache.length,
    'visibleItems': _visibleIndices.length,
  };
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    
    _scrollController = widget.controller ?? ScrollController();
    _setupScrollListener();
    
    if (widget.enablePerformanceTracking) {
      trackRebuild('initState', context: {
        'initialItemCount': widget.items.length,
      });
    }
  }
  
  @override
  void didUpdateWidget(OptimizedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Clear cache if items changed significantly
    if (widget.items.length != oldWidget.items.length ||
        widget.items.hashCode != oldWidget.items.hashCode) {
      _clearWidgetCache();
      
      if (widget.enablePerformanceTracking) {
        trackRebuild('items_changed', context: {
          'oldItemCount': oldWidget.items.length,
          'newItemCount': widget.items.length,
        });
      }
    }
  }
  
  @override
  Widget performanceBuild(BuildContext context) {
    super.build(context);
    
    // Handle empty state
    if (widget.items.isEmpty && !_isLoading) {
      return widget.emptyBuilder?.call(context) ?? 
          const Center(child: Text('No items available'));
    }
    
    // Handle error state
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ??
          Center(child: Text('Error: $_error'));
    }
    
    // Handle loading state
    if (_isLoading && widget.items.isEmpty) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }
    
    return _buildOptimizedList();
  }
  
  /// Build the optimized list view
  Widget _buildOptimizedList() {
    Widget listView;
    
    if (widget.enableVirtualization && widget.itemExtent != null) {
      // Use ListView.builder with fixed extent for maximum performance
      listView = ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        itemExtent: widget.itemExtent,
        cacheExtent: widget.maxCacheExtent?.toDouble(),
        itemCount: widget.items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: _buildOptimizedItem,
      );
    } else if (widget.separator != null) {
      // Use ListView.separated for items with separators
      listView = ListView.separated(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        cacheExtent: widget.maxCacheExtent?.toDouble(),
        itemCount: widget.items.length,
        itemBuilder: (context, index) => _buildOptimizedItem(context, index),
        separatorBuilder: (context, index) => widget.separator!,
      );
    } else {
      // Use standard ListView.builder
      listView = ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        cacheExtent: widget.maxCacheExtent?.toDouble(),
        itemCount: widget.items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: _buildOptimizedItem,
      );
    }
    
    // Wrap with RefreshIndicator if refresh is supported
    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: listView,
      );
    }
    
    return listView;
  }
  
  /// Build optimized list item with caching
  Widget _buildOptimizedItem(BuildContext context, int index) {
    // Handle load more indicator
    if (index >= widget.items.length) {
      return _buildLoadMoreIndicator();
    }
    
    // Track visible indices for performance monitoring
    _visibleIndices.add(index);
    
    // Use cached widget if available and virtualization is disabled
    if (!widget.enableVirtualization && _widgetCache.containsKey(index)) {
      return _widgetCache[index]!;
    }
    
    final item = widget.items[index];
    Widget itemWidget;
    
    try {
      itemWidget = widget.itemBuilder(context, item, index);
      
      // Add performance boundary for complex items
      if (widget.enablePerformanceTracking) {
        itemWidget = RepaintBoundary(
          child: itemWidget.withPerformanceTracking(
            name: '${performanceWidgetName}_Item_$index',
            context: {
              'itemIndex': index,
              'itemType': item.runtimeType.toString(),
            },
          ),
        );
      } else {
        itemWidget = RepaintBoundary(child: itemWidget);
      }
      
      // Cache widget if virtualization is disabled
      if (!widget.enableVirtualization) {
        _cacheWidget(index, itemWidget);
      }
      
    } catch (e) {
      debugPrint('❌ Error building item at index $index: $e');
      itemWidget = Container(
        height: 50,
        child: Center(
          child: Text('Error loading item', style: TextStyle(color: Colors.red)),
        ),
      );
    }
    
    return itemWidget;
  }
  
  /// Build load more indicator
  Widget _buildLoadMoreIndicator() {
    return Container(
      height: 60,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  /// Setup scroll listener for load more and performance tracking
  void _setupScrollListener() {
    _scrollController.addListener(() {
      final position = _scrollController.position;
      
      // Track scroll performance
      if (widget.enablePerformanceTracking) {
        _trackScrollPerformance(position);
      }
      
      // Handle load more
      if (widget.onLoadMore != null && !_isLoadingMore) {
        final distanceToEnd = position.maxScrollExtent - position.pixels;
        
        if (distanceToEnd < loadMoreThreshold) {
          _handleLoadMore();
        }
      }
      
      // Clear scroll end timer
      _scrollEndTimer?.cancel();
      _scrollEndTimer = Timer(scrollEndDelay, () {
        _onScrollEnd();
      });
    });
  }
  
  /// Track scroll performance
  void _trackScrollPerformance(ScrollPosition position) {
    final currentPosition = position.pixels;
    final scrollDelta = (currentPosition - _lastScrollPosition).abs();
    
    if (scrollDelta > 100) { // Only track significant scrolls
      trackRebuild('scroll_performance', context: {
        'scrollPosition': currentPosition,
        'scrollDelta': scrollDelta,
        'visibleItems': _visibleIndices.length,
        'cacheSize': _widgetCache.length,
      });
    }
    
    _lastScrollPosition = currentPosition;
  }
  
  /// Handle scroll end event
  void _onScrollEnd() {
    // Clear visible indices tracking
    _visibleIndices.clear();
    
    // Cleanup cache if it's too large
    if (_widgetCache.length > maxCacheSize) {
      _cleanupWidgetCache();
    }
    
    if (widget.enablePerformanceTracking) {
      trackRebuild('scroll_ended', context: {
        'finalPosition': _scrollController.position.pixels,
        'cacheSize': _widgetCache.length,
      });
    }
  }
  
  /// Handle refresh
  Future<void> _handleRefresh() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final newItems = await widget.onRefresh!();
      
      setState(() {
        _isLoading = false;
      });
      
      // Clear cache since items changed
      _clearWidgetCache();
      
      if (widget.enablePerformanceTracking) {
        trackRebuild('refresh_completed', context: {
          'newItemCount': newItems.length,
        });
      }
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      
      debugPrint('❌ Refresh failed: $e');
    }
  }
  
  /// Handle load more
  Future<void> _handleLoadMore() async {
    if (_isLoadingMore || _isLoading) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final moreItems = await widget.onLoadMore!();
      
      setState(() {
        _isLoadingMore = false;
      });
      
      if (widget.enablePerformanceTracking) {
        trackRebuild('load_more_completed', context: {
          'loadedItemCount': moreItems.length,
          'totalItemCount': widget.items.length,
        });
      }
      
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _error = e.toString();
      });
      
      debugPrint('❌ Load more failed: $e');
    }
  }
  
  /// Cache widget for reuse
  void _cacheWidget(int index, Widget widget) {
    if (_widgetCache.length >= maxCacheSize) {
      _cleanupWidgetCache();
    }
    
    _widgetCache[index] = widget;
  }
  
  /// Clear all cached widgets
  void _clearWidgetCache() {
    _widgetCache.clear();
    
    if (widget.enablePerformanceTracking) {
      debugPrint('🧹 Cleared widget cache for $performanceWidgetName');
    }
  }
  
  /// Cleanup old cached widgets
  void _cleanupWidgetCache() {
    if (_widgetCache.length <= maxCacheSize ~/ 2) return;
    
    // Remove widgets that are far from current scroll position
    final currentIndex = _getCurrentVisibleIndex();
    final keysToRemove = <int>[];
    
    for (final index in _widgetCache.keys) {
      if ((index - currentIndex).abs() > 20) {
        keysToRemove.add(index);
      }
    }
    
    for (final key in keysToRemove) {
      _widgetCache.remove(key);
    }
    
    if (widget.enablePerformanceTracking && keysToRemove.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${keysToRemove.length} cached widgets');
    }
  }
  
  /// Get current visible index based on scroll position
  int _getCurrentVisibleIndex() {
    if (!_scrollController.hasClients) return 0;
    
    final position = _scrollController.position.pixels;
    final itemHeight = widget.itemExtent ?? 100.0; // Estimate if not provided
    
    return math.max(0, (position / itemHeight).floor());
  }
  
  @override
  void dispose() {
    _scrollEndTimer?.cancel();
    _clearWidgetCache();
    
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    
    super.dispose();
  }
}

/// Optimized grid view with similar performance enhancements
class OptimizedGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Future<List<T>> Function()? onRefresh;
  final Future<List<T>> Function()? onLoadMore;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool enablePerformanceTracking;
  final String? performanceTag;
  
  const OptimizedGridView({
    Key? key,
    required this.items,
    required this.itemBuilder,
    required this.gridDelegate,
    this.loadingBuilder,
    this.emptyBuilder,
    this.onRefresh,
    this.onLoadMore,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.enablePerformanceTracking = kDebugMode,
    this.performanceTag,
  }) : super(key: key);
  
  @override
  State<OptimizedGridView<T>> createState() => _OptimizedGridViewState<T>();
}

class _OptimizedGridViewState<T> extends State<OptimizedGridView<T>>
    with PerformanceTrackingMixin {
  
  late ScrollController _scrollController;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  
  @override
  String get performanceWidgetName => 
      'OptimizedGridView${widget.performanceTag != null ? '_${widget.performanceTag}' : ''}';
  
  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _setupScrollListener();
  }
  
  @override
  Widget performanceBuild(BuildContext context) {
    if (widget.items.isEmpty && !_isLoading) {
      return widget.emptyBuilder?.call(context) ?? 
          const Center(child: Text('No items available'));
    }
    
    if (_isLoading && widget.items.isEmpty) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }
    
    Widget gridView = GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      gridDelegate: widget.gridDelegate,
      itemCount: widget.items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final item = widget.items[index];
        Widget itemWidget = widget.itemBuilder(context, item, index);
        
        if (widget.enablePerformanceTracking) {
          itemWidget = RepaintBoundary(
            child: itemWidget.withPerformanceTracking(
              name: '${performanceWidgetName}_Item_$index',
            ),
          );
        } else {
          itemWidget = RepaintBoundary(child: itemWidget);
        }
        
        return itemWidget;
      },
    );
    
    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: gridView,
      );
    }
    
    return gridView;
  }
  
  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (widget.onLoadMore != null && !_isLoadingMore) {
        final position = _scrollController.position;
        final distanceToEnd = position.maxScrollExtent - position.pixels;
        
        if (distanceToEnd < 200.0) {
          _handleLoadMore();
        }
      }
    });
  }
  
  Future<void> _handleRefresh() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await widget.onRefresh!();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('❌ Grid refresh failed: $e');
    }
  }
  
  Future<void> _handleLoadMore() async {
    if (_isLoadingMore || _isLoading) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      await widget.onLoadMore!();
      setState(() {
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      debugPrint('❌ Grid load more failed: $e');
    }
  }
  
  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }
}