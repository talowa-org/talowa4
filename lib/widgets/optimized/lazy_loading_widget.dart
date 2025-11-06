import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../services/performance/cache_service.dart';
import '../../services/network/network_optimization_service.dart';
import '../../services/performance/performance_monitoring_service.dart';

/// Lazy loading widget for images with advanced optimization
class LazyLoadingImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final bool enableMemoryCache;
  final bool enableDiskCache;
  final int? cacheWidth;
  final int? cacheHeight;
  
  const LazyLoadingImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableMemoryCache = true,
    this.enableDiskCache = true,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  State<LazyLoadingImage> createState() => _LazyLoadingImageState();
}

class _LazyLoadingImageState extends State<LazyLoadingImage>
    with SingleTickerProviderStateMixin {
  
  Uint8List? _imageData;
  bool _isLoading = false;
  bool _hasError = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only load image when widget is visible
        return VisibilityDetector(
          key: Key('lazy_image_${widget.imageUrl}'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction > 0.1 && !_isLoading && _imageData == null && !_hasError) {
              _loadImage();
            }
          },
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: _buildImageWidget(),
          ),
        );
      },
    );
  }
  
  Widget _buildImageWidget() {
    if (_hasError) {
      return widget.errorWidget ?? _buildErrorWidget();
    }
    
    if (_imageData != null) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Image.memory(
          _imageData!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
        ),
      );
    }
    
    return widget.placeholder ?? _buildPlaceholderWidget();
  }
  
  Widget _buildPlaceholderWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: _isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : const Center(
              child: Icon(Icons.image, color: Colors.grey),
            ),
    );
  }
  
  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[100],
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.grey),
            SizedBox(height: 4),
            Text('Failed to load', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
  
  Future<void> _loadImage() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final startTime = DateTime.now();
    
    try {
      // Check memory cache first
      if (widget.enableMemoryCache) {
        final cachedImage = await CacheService.instance.getCachedImage(widget.imageUrl);
        if (cachedImage != null) {
          setState(() {
            _imageData = cachedImage;
            _isLoading = false;
          });
          _animationController.forward();
          
          // Record cache hit
          PerformanceMonitoringService.instance.recordCacheHit(true, 'image_memory');
          return;
        }
      }
      
      // Check disk cache
      if (widget.enableDiskCache) {
        final cachedData = await CacheService.instance.getCache<List<int>>(
          'image_${widget.imageUrl.hashCode}',
          maxAge: const Duration(hours: 24),
        );
        
        if (cachedData != null) {
          final imageData = Uint8List.fromList(cachedData);
          setState(() {
            _imageData = imageData;
            _isLoading = false;
          });
          
          // Cache in memory for faster future access
          if (widget.enableMemoryCache) {
            await CacheService.instance.cacheImage(widget.imageUrl, imageData);
          }
          
          _animationController.forward();
          
          // Record cache hit
          PerformanceMonitoringService.instance.recordCacheHit(true, 'image_disk');
          return;
        }
      }
      
      // Download image
      final imageData = await NetworkOptimizationService.instance.optimizedImageDownload(
        widget.imageUrl,
        maxWidth: widget.cacheWidth,
        maxHeight: widget.cacheHeight,
      );
      
      if (imageData != null && mounted) {
        setState(() {
          _imageData = imageData;
          _isLoading = false;
        });
        
        // Cache the image
        if (widget.enableMemoryCache) {
          await CacheService.instance.cacheImage(widget.imageUrl, imageData);
        }
        
        if (widget.enableDiskCache) {
          await CacheService.instance.setCache(
            'image_${widget.imageUrl.hashCode}',
            imageData.toList(),
            expiration: const Duration(hours: 24),
          );
        }
        
        _animationController.forward();
        
        // Record performance metrics
        final loadTime = DateTime.now().difference(startTime);
        PerformanceMonitoringService.instance.recordMetric(
          'image_load_time',
          loadTime.inMilliseconds.toDouble(),
          metadata: {
            'url': widget.imageUrl,
            'size_bytes': imageData.length,
            'from_cache': false,
          },
        );
        
        // Record cache miss
        PerformanceMonitoringService.instance.recordCacheHit(false, 'image');
        
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      
      debugPrint('❌ Failed to load image ${widget.imageUrl}: $e');
    }
  }
}

/// Lazy loading list widget for better performance with large datasets
class LazyLoadingListView extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;
  final Widget? loadingWidget;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final double loadMoreThreshold;
  
  const LazyLoadingListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onLoadMore,
    this.hasMore = true,
    this.loadingWidget,
    this.controller,
    this.padding,
    this.loadMoreThreshold = 200.0, // Load more when 200px from bottom
  });

  @override
  State<LazyLoadingListView> createState() => _LazyLoadingListViewState();
}

class _LazyLoadingListViewState extends State<LazyLoadingListView> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;
  
  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - widget.loadMoreThreshold) {
      _loadMore();
    }
  }
  
  Future<void> _loadMore() async {
    if (_isLoadingMore || !widget.hasMore || widget.onLoadMore == null) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    final startTime = DateTime.now();
    
    try {
      await widget.onLoadMore!();
      
      // Record load more performance
      final loadTime = DateTime.now().difference(startTime);
      PerformanceMonitoringService.instance.recordMetric(
        'list_load_more_time',
        loadTime.inMilliseconds.toDouble(),
        metadata: {
          'current_item_count': widget.itemCount,
        },
      );
      
    } catch (e) {
      debugPrint('❌ Failed to load more items: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: widget.itemCount + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.itemCount) {
          // Loading indicator at the end
          return widget.loadingWidget ?? _buildLoadingWidget();
        }
        
        return widget.itemBuilder(context, index);
      },
    );
  }
  
  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: _isLoadingMore
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Visibility detector for lazy loading
class VisibilityDetector extends StatefulWidget {
  @override
  final Key key;
  final Widget child;
  final Function(VisibilityInfo) onVisibilityChanged;
  
  const VisibilityDetector({
    required this.key,
    required this.child,
    required this.onVisibilityChanged,
  }) : super(key: key);

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkVisibility();
        });
        return false;
      },
      child: widget.child,
    );
  }
  
  void _checkVisibility() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      final viewport = RenderAbstractViewport.of(renderObject);
      final revealedOffset = viewport.getOffsetToReveal(renderObject, 0.0);
      final size = renderObject.size;
      final position = renderObject.localToGlobal(Offset.zero);
      
      // Calculate visibility fraction (simplified)
      final visibleFraction = _calculateVisibilityFraction(position, size);
      
      widget.onVisibilityChanged(VisibilityInfo(
        key: widget.key,
        size: size,
        visibleFraction: visibleFraction,
      ));
        }
  }
  
  double _calculateVisibilityFraction(Offset position, Size size) {
    final screenSize = MediaQuery.of(context).size;
    
    // Simple visibility calculation
    if (position.dy + size.height < 0 || position.dy > screenSize.height) {
      return 0.0; // Completely outside viewport
    }
    
    if (position.dy >= 0 && position.dy + size.height <= screenSize.height) {
      return 1.0; // Completely visible
    }
    
    // Partially visible
    final visibleHeight = (position.dy < 0) 
        ? size.height + position.dy
        : screenSize.height - position.dy;
    
    return (visibleHeight / size.height).clamp(0.0, 1.0);
  }
}

/// Visibility information
class VisibilityInfo {
  final Key key;
  final Size size;
  final double visibleFraction;
  
  VisibilityInfo({
    required this.key,
    required this.size,
    required this.visibleFraction,
  });
}