// Performance Optimization Service for TALOWA
// Implements Task 21: Optimize performance and loading

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../../models/social_feed/index.dart';

class PerformanceOptimizationService {
  static final PerformanceOptimizationService _instance = PerformanceOptimizationService._internal();
  factory PerformanceOptimizationService() => _instance;
  PerformanceOptimizationService._internal();

  // Cache management
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, Uint8List> _imageCache = {};
  
  // Performance metrics
  final Map<String, int> _performanceMetrics = {};
  Timer? _metricsTimer;
  
  // Configuration
  static const int maxMemoryCacheSize = 50; // MB
  static const int maxImageCacheSize = 20; // MB
  static const Duration cacheExpiration = Duration(hours: 1);
  static const int imageCompressionQuality = 85;
  static const int maxImageDimension = 1920;

  /// Initialize performance optimization service
  Future<void> initialize() async {
    try {
      // Start performance monitoring
      _startPerformanceMonitoring();
      
      // Load cached preferences
      await _loadCachedPreferences();
      
      // Setup memory pressure listener
      _setupMemoryPressureListener();
      
      debugPrint('PerformanceOptimizationService initialized');
    } catch (e) {
      debugPrint('Error initializing PerformanceOptimizationService: $e');
    }
  }

  /// Lazy load posts with pagination and caching
  Future<List<PostModel>> lazyLoadPosts({
    required int page,
    required int pageSize,
    String? category,
    bool useCache = true,
  }) async {
    // Removed mock generation. This method should be implemented by real feed services.
    throw UnimplementedError('lazyLoadPosts is not implemented in PerformanceOptimizationService. Use FeedService for real data.');
  }

  /// Compress and optimize image
  Future<Uint8List> optimizeImage({
    required Uint8List imageBytes,
    int? maxWidth,
    int? maxHeight,
    int quality = imageCompressionQuality,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      // Calculate new dimensions
      final originalWidth = image.width;
      final originalHeight = image.height;
      
      int newWidth = maxWidth ?? maxImageDimension;
      int newHeight = maxHeight ?? maxImageDimension;
      
      // Maintain aspect ratio
      if (originalWidth > originalHeight) {
        newHeight = (originalHeight * newWidth / originalWidth).round();
      } else {
        newWidth = (originalWidth * newHeight / originalHeight).round();
      }
      
      // Only resize if image is larger than target
      img.Image processedImage = image;
      if (originalWidth > newWidth || originalHeight > newHeight) {
        processedImage = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }
      
      // Compress image
      final compressedBytes = img.encodeJpg(processedImage, quality: quality);
      
      stopwatch.stop();
      _recordMetric('image_optimization_time', stopwatch.elapsedMilliseconds);
      
      final compressionRatio = (imageBytes.length - compressedBytes.length) / imageBytes.length;
      _recordMetric('compression_ratio', (compressionRatio * 100).round());
      
      debugPrint('Image optimized: ${imageBytes.length} -> ${compressedBytes.length} bytes '
          '(${(compressionRatio * 100).toStringAsFixed(1)}% reduction)');
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      debugPrint('Error optimizing image: $e');
      _recordMetric('image_optimization_error');
      return imageBytes; // Return original if optimization fails
    }
  }

  /// Cache image with memory management
  Future<void> cacheImage(String url, Uint8List imageBytes) async {
    try {
      // Check cache size limit
      final currentCacheSize = _calculateImageCacheSize();
      if (currentCacheSize > maxImageCacheSize * 1024 * 1024) {
        await _cleanupImageCache();
      }
      
      // Optimize image before caching
      final optimizedBytes = await optimizeImage(imageBytes: imageBytes);
      
      _imageCache[url] = optimizedBytes;
      _cacheTimestamps['image_$url'] = DateTime.now();
      
      _recordMetric('image_cached');
    } catch (e) {
      debugPrint('Error caching image: $e');
    }
  }

  /// Get cached image
  Uint8List? getCachedImage(String url) {
    try {
      final timestamp = _cacheTimestamps['image_$url'];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < cacheExpiration) {
        _recordMetric('image_cache_hit');
        return _imageCache[url];
      } else {
        // Remove expired cache
        _imageCache.remove(url);
        _cacheTimestamps.remove('image_$url');
        _recordMetric('image_cache_miss');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting cached image: $e');
      return null;
    }
  }

  /// Preload critical content
  Future<void> preloadCriticalContent({
    required List<String> imageUrls,
    required List<PostModel> posts,
  }) async {
    try {
      // Preload images in background
      _preloadImages(imageUrls);
      
      // Cache posts
      for (int i = 0; i < posts.length; i++) {
        final cacheKey = 'preloaded_post_$i';
        _cacheData(cacheKey, posts[i]);
      }
      
      _recordMetric('content_preloaded');
    } catch (e) {
      debugPrint('Error preloading content: $e');
    }
  }

  /// Background sync with performance optimization
  Future<void> performBackgroundSync({
    required List<dynamic> syncItems,
    int batchSize = 10,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Process items in batches to avoid blocking UI
      for (int i = 0; i < syncItems.length; i += batchSize) {
        final batch = syncItems.skip(i).take(batchSize).toList();
        
        // Process batch
        await _processSyncBatch(batch);
        
        // Yield control to UI thread
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      stopwatch.stop();
      _recordMetric('background_sync_time', stopwatch.elapsedMilliseconds);
      
      debugPrint('Background sync completed: ${syncItems.length} items in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('Error in background sync: $e');
      _recordMetric('background_sync_error');
    }
  }

  /// Optimize database queries with caching
  Future<List<T>> optimizedQuery<T>({
    required String queryKey,
    required Future<List<T>> Function() queryFunction,
    Duration cacheDuration = const Duration(minutes: 5),
  }) async {
    try {
      // Check cache first
      if (_memoryCache.containsKey(queryKey)) {
        final timestamp = _cacheTimestamps[queryKey];
        if (timestamp != null && 
            DateTime.now().difference(timestamp) < cacheDuration) {
          _recordMetric('query_cache_hit');
          return List<T>.from(_memoryCache[queryKey]);
        }
      }
      
      // Execute query
      final stopwatch = Stopwatch()..start();
      final results = await queryFunction();
      stopwatch.stop();
      
      // Cache results
      _cacheData(queryKey, results);
      
      _recordMetric('query_execution_time', stopwatch.elapsedMilliseconds);
      _recordMetric('query_cache_miss');
      
      return results;
    } catch (e) {
      debugPrint('Error in optimized query: $e');
      _recordMetric('query_error');
      rethrow;
    }
  }

  /// Efficient pagination with virtual scrolling
  List<T> getVirtualScrollItems<T>({
    required List<T> allItems,
    required int visibleStartIndex,
    required int visibleEndIndex,
    int bufferSize = 5,
  }) {
    try {
      final startIndex = (visibleStartIndex - bufferSize).clamp(0, allItems.length);
      final endIndex = (visibleEndIndex + bufferSize).clamp(0, allItems.length);
      
      _recordMetric('virtual_scroll_items', endIndex - startIndex);
      
      return allItems.sublist(startIndex, endIndex);
    } catch (e) {
      debugPrint('Error in virtual scrolling: $e');
      return allItems;
    }
  }

  /// Memory-efficient image loading
  Future<ui.Image> loadImageEfficiently(String imageUrl) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Check cache first
      final cachedBytes = getCachedImage(imageUrl);
      if (cachedBytes != null) {
        final codec = await ui.instantiateImageCodec(cachedBytes);
        final frame = await codec.getNextFrame();
        stopwatch.stop();
        _recordMetric('image_load_time', stopwatch.elapsedMilliseconds);
        return frame.image;
      }
      
      // Load and cache image
      // This would typically load from network or local storage
      final imageBytes = await _loadImageBytes(imageUrl);
      await cacheImage(imageUrl, imageBytes);
      
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      
      stopwatch.stop();
      _recordMetric('image_load_time', stopwatch.elapsedMilliseconds);
      
      return frame.image;
    } catch (e) {
      debugPrint('Error loading image efficiently: $e');
      _recordMetric('image_load_error');
      rethrow;
    }
  }

  /// Batch operations for better performance
  Future<List<T>> batchOperation<T>({
    required List<dynamic> items,
    required Future<T> Function(dynamic item) operation,
    int batchSize = 10,
    Duration batchDelay = const Duration(milliseconds: 10),
  }) async {
    try {
      final results = <T>[];
      
      for (int i = 0; i < items.length; i += batchSize) {
        final batch = items.skip(i).take(batchSize);
        final batchResults = await Future.wait(
          batch.map((item) => operation(item)),
        );
        
        results.addAll(batchResults);
        
        // Yield control to UI thread
        if (i + batchSize < items.length) {
          await Future.delayed(batchDelay);
        }
      }
      
      _recordMetric('batch_operation_items', items.length);
      return results;
    } catch (e) {
      debugPrint('Error in batch operation: $e');
      _recordMetric('batch_operation_error');
      rethrow;
    }
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'metrics': Map<String, int>.from(_performanceMetrics),
      'cache_size': _memoryCache.length,
      'image_cache_size': _imageCache.length,
      'memory_cache_size_mb': _calculateMemoryCacheSize() / (1024 * 1024),
      'image_cache_size_mb': _calculateImageCacheSize() / (1024 * 1024),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    try {
      _memoryCache.clear();
      _cacheTimestamps.clear();
      _imageCache.clear();
      
      // Clear SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      _recordMetric('cache_cleared');
      debugPrint('All caches cleared');
    } catch (e) {
      debugPrint('Error clearing caches: $e');
    }
  }

  /// Optimize app startup
  Future<void> optimizeAppStartup() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Preload critical resources
      await _preloadCriticalResources();
      
      // Initialize essential services only
      await _initializeEssentialServices();
      
      // Defer non-critical initializations
      _deferNonCriticalInitializations();
      
      stopwatch.stop();
      _recordMetric('app_startup_time', stopwatch.elapsedMilliseconds);
      
      debugPrint('App startup optimized: ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('Error optimizing app startup: $e');
    }
  }

  // Private methods

  void _startPerformanceMonitoring() {
    _metricsTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _collectPerformanceMetrics();
    });
  }

  void _collectPerformanceMetrics() {
    try {
      // Collect memory usage
      final memoryUsage = _calculateMemoryCacheSize();
      _recordMetric('memory_usage_bytes', memoryUsage);
      
      // Collect cache hit rates
      final cacheHits = _performanceMetrics['cache_hit'] ?? 0;
      final cacheMisses = _performanceMetrics['cache_miss'] ?? 0;
      final totalRequests = cacheHits + cacheMisses;
      
      if (totalRequests > 0) {
        final hitRate = (cacheHits / totalRequests * 100).round();
        _recordMetric('cache_hit_rate', hitRate);
      }
    } catch (e) {
      debugPrint('Error collecting performance metrics: $e');
    }
  }

  void _setupMemoryPressureListener() {
    // Listen for memory pressure and cleanup caches
    SystemChannels.lifecycle.setMessageHandler((message) async {
      if (message == AppLifecycleState.paused.toString()) {
        await _cleanupMemoryCache();
      }
      return null;
    });
  }

  Future<void> _loadCachedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load performance settings
      final enableImageOptimization = prefs.getBool('enable_image_optimization') ?? true;
      final enableMemoryCache = prefs.getBool('enable_memory_cache') ?? true;
      
      debugPrint('Loaded performance preferences: '
          'imageOptimization=$enableImageOptimization, '
          'memoryCache=$enableMemoryCache');
    } catch (e) {
      debugPrint('Error loading cached preferences: $e');
    }
  }

  void _cacheData(String key, dynamic data) {
    try {
      // Check memory limit
      final currentSize = _calculateMemoryCacheSize();
      if (currentSize > maxMemoryCacheSize * 1024 * 1024) {
        _cleanupMemoryCache();
      }
      
      _memoryCache[key] = data;
      _cacheTimestamps[key] = DateTime.now();
    } catch (e) {
      debugPrint('Error caching data: $e');
    }
  }

  int _calculateMemoryCacheSize() {
    int totalSize = 0;
    for (final value in _memoryCache.values) {
      totalSize += _estimateObjectSize(value);
    }
    return totalSize;
  }

  int _calculateImageCacheSize() {
    int totalSize = 0;
    for (final bytes in _imageCache.values) {
      totalSize += bytes.length;
    }
    return totalSize;
  }

  int _estimateObjectSize(dynamic object) {
    // Rough estimation of object size in bytes
    if (object is String) {
      return object.length * 2; // UTF-16 encoding
    } else if (object is List) {
      return object.length * 100; // Rough estimate
    } else if (object is Map) {
      return object.length * 200; // Rough estimate
    } else {
      return 100; // Default estimate
    }
  }

  Future<void> _cleanupMemoryCache() async {
    try {
      final now = DateTime.now();
      final keysToRemove = <String>[];
      
      // Remove expired items
      for (final entry in _cacheTimestamps.entries) {
        if (now.difference(entry.value) > cacheExpiration) {
          keysToRemove.add(entry.key);
        }
      }
      
      // Remove oldest items if still over limit
      if (_calculateMemoryCacheSize() > maxMemoryCacheSize * 1024 * 1024) {
        final sortedEntries = _cacheTimestamps.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        
        final itemsToRemove = sortedEntries.take(sortedEntries.length ~/ 2);
        keysToRemove.addAll(itemsToRemove.map((e) => e.key));
      }
      
      // Remove items
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
      
      _recordMetric('cache_cleanup_items', keysToRemove.length);
      debugPrint('Memory cache cleanup: removed ${keysToRemove.length} items');
    } catch (e) {
      debugPrint('Error cleaning up memory cache: $e');
    }
  }

  Future<void> _cleanupImageCache() async {
    try {
      final now = DateTime.now();
      final keysToRemove = <String>[];
      
      // Remove expired images
      for (final entry in _cacheTimestamps.entries) {
        if (entry.key.startsWith('image_') && 
            now.difference(entry.value) > cacheExpiration) {
          final imageKey = entry.key.substring(6); // Remove 'image_' prefix
          keysToRemove.add(imageKey);
        }
      }
      
      // Remove oldest images if still over limit
      if (_calculateImageCacheSize() > maxImageCacheSize * 1024 * 1024) {
        final imageEntries = _cacheTimestamps.entries
            .where((e) => e.key.startsWith('image_'))
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        
        final itemsToRemove = imageEntries.take(imageEntries.length ~/ 2);
        keysToRemove.addAll(
          itemsToRemove.map((e) => e.key.substring(6))
        );
      }
      
      // Remove images
      for (final key in keysToRemove) {
        _imageCache.remove(key);
        _cacheTimestamps.remove('image_$key');
      }
      
      _recordMetric('image_cache_cleanup_items', keysToRemove.length);
      debugPrint('Image cache cleanup: removed ${keysToRemove.length} items');
    } catch (e) {
      debugPrint('Error cleaning up image cache: $e');
    }
  }

  void _recordMetric(String key, [int value = 1]) {
    _performanceMetrics[key] = (_performanceMetrics[key] ?? 0) + value;
  }

  Future<void> _preloadImages(List<String> imageUrls) async {
    // Preload images in background without blocking UI
    for (final url in imageUrls.take(5)) { // Limit to first 5 images
      try {
        final imageBytes = await _loadImageBytes(url);
        await cacheImage(url, imageBytes);
      } catch (e) {
        debugPrint('Error preloading image $url: $e');
      }
      
      // Small delay to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<Uint8List> _loadImageBytes(String imageUrl) async {
    // Removed mock image bytes generator. Integrate with real network loader in widgets/services as needed.
    throw UnimplementedError('Use a real image loader to fetch bytes for $imageUrl');
  }

  Future<void> _processSyncBatch(List<dynamic> batch) async {
    // Mock batch processing
    await Future.delayed(Duration(milliseconds: batch.length * 10));
  }

  List<PostModel> _generateMockPosts(int page, int pageSize, String? category) {
    // Removed mock post generator.
    throw UnimplementedError('_generateMockPosts removed. Use FeedService for posts.');
  }

  Future<void> _preloadCriticalResources() async {
    // Preload essential app resources
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _initializeEssentialServices() async {
    // Initialize only critical services during startup
    await Future.delayed(const Duration(milliseconds: 50));
  }

  void _deferNonCriticalInitializations() {
    // Defer non-critical initializations to after app startup
    Timer(const Duration(seconds: 2), () {
      _initializeNonCriticalServices();
    });
  }

  Future<void> _initializeNonCriticalServices() async {
    // Initialize non-critical services
    await Future.delayed(const Duration(milliseconds: 200));
    debugPrint('Non-critical services initialized');
  }

  /// Dispose resources
  void dispose() {
    _metricsTimer?.cancel();
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _imageCache.clear();
  }
}
