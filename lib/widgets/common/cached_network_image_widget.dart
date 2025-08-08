// Cached Network Image Widget for TALOWA
// Implements Task 21: Performance optimization - Efficient Image Loading

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/performance/performance_optimization_service.dart';
import '../../core/theme/app_theme.dart';

class CachedNetworkImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableOptimization;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const CachedNetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.enableOptimization = true,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  State<CachedNetworkImageWidget> createState() => _CachedNetworkImageWidgetState();
}

class _CachedNetworkImageWidgetState extends State<CachedNetworkImageWidget> {
  final PerformanceOptimizationService _performanceService = PerformanceOptimizationService();
  
  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      placeholder: (context, url) => widget.placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => widget.errorWidget ?? _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
      useOldImageOnUrlChange: true,
      // Performance optimizations
      cacheManager: CustomCacheManager(),
      maxWidthDiskCache: 1920,
      maxHeightDiskCache: 1080,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            size: 32,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.talowaGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 32,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom cache manager for better performance
class CustomCacheManager extends CacheManager {
  static const key = 'talowa_image_cache';
  
  static CustomCacheManager? _instance;
  
  factory CustomCacheManager() {
    _instance ??= CustomCacheManager._();
    return _instance!;
  }
  
  CustomCacheManager._() : super(
    Config(
      key,
      stalePeriod: const Duration(days: 7), // Cache for 7 days
      maxNrOfCacheObjects: 200, // Maximum 200 cached images
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

// Optimized image widget with lazy loading
class LazyLoadImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const LazyLoadImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<LazyLoadImageWidget> createState() => _LazyLoadImageWidgetState();
}

class _LazyLoadImageWidgetState extends State<LazyLoadImageWidget> {
  bool _isVisible = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.imageUrl),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.1 && !_isVisible) {
          setState(() {
            _isVisible = true;
          });
        }
      },
      child: _isVisible
          ? CachedNetworkImageWidget(
              imageUrl: widget.imageUrl,
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              placeholder: widget.placeholder,
              errorWidget: widget.errorWidget,
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image,
        size: 32,
        color: Colors.grey[400],
      ),
    );
  }
}

// Visibility detector for lazy loading
class VisibilityDetector extends StatefulWidget {
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
        _checkVisibility();
        return false;
      },
      child: widget.child,
    );
  }

  void _checkVisibility() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    final visibleHeight = (screenSize.height - position.dy).clamp(0.0, size.height);
    final visibleFraction = visibleHeight / size.height;

    widget.onVisibilityChanged(VisibilityInfo(
      key: widget.key,
      size: size,
      visibleFraction: visibleFraction,
    ));
  }
}

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

// Progressive image loading widget
class ProgressiveImageWidget extends StatefulWidget {
  final String imageUrl;
  final String? thumbnailUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ProgressiveImageWidget({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<ProgressiveImageWidget> createState() => _ProgressiveImageWidgetState();
}

class _ProgressiveImageWidgetState extends State<ProgressiveImageWidget> {
  bool _showFullImage = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Thumbnail (low quality, fast loading)
        if (widget.thumbnailUrl != null)
          CachedNetworkImageWidget(
            imageUrl: widget.thumbnailUrl!,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
          ),
        
        // Full quality image
        AnimatedOpacity(
          opacity: _showFullImage ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: CachedNetworkImageWidget(
            imageUrl: widget.imageUrl,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _preloadFullImage();
  }

  void _preloadFullImage() {
    precacheImage(
      CachedNetworkImageProvider(widget.imageUrl),
      context,
    ).then((_) {
      if (mounted) {
        setState(() {
          _showFullImage = true;
        });
      }
    }).catchError((error) {
      debugPrint('Error preloading full image: $error');
    });
  }
}

// Image grid widget with optimized loading
class OptimizedImageGrid extends StatelessWidget {
  final List<String> imageUrls;
  final double aspectRatio;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Function(String imageUrl)? onImageTap;

  const OptimizedImageGrid({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 1.0,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        final imageUrl = imageUrls[index];
        return GestureDetector(
          onTap: () => onImageTap?.call(imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LazyLoadImageWidget(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}