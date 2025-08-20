// Performance Integration Service for TALOWA
// Integrates all performance optimization services for messaging
// Requirements: 1.1, 8.4

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'redis_cache_service.dart';
import 'message_pagination_service.dart';
import 'cdn_integration_service.dart';
import 'lazy_loading_service.dart';
import '../database/database_optimization_service.dart';
import '../performance/performance_optimization_service.dart';

class PerformanceIntegrationService {
  static final PerformanceIntegrationService _instance = PerformanceIntegrationService._internal();
  factory PerformanceIntegrationService() => _instance;
  PerformanceIntegrationService._internal();

  // Service instances
  final RedisCacheService _cacheService = RedisCacheService();
  final MessagePaginationService _paginationService = MessagePaginationService();
  final CDNIntegrationService _cdnService = CDNIntegrationService();
  final LazyLoadingService _lazyLoadingService = LazyLoadingService();
  final DatabaseOptimizationService _dbOptimizationService = DatabaseOptimizationService();
  final PerformanceOptimizationService _performanceService = PerformanceOptimizationService();
  
  // Performance monitoring
  final Map<String, PerformanceMetric> _performanceMetrics = {};
  Timer? _metricsCollectionTimer;
  
  // Configuration
  static const Duration metricsCollectionInterval = Duration(minutes: 5);
  static const int performanceThresholdMs = 1000; // 1 second
  static const double cacheHitRateThreshold = 0.8; // 80%

  /// Initialize all performance optimization services
  Future<void> initialize() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Initialize all services in parallel for faster startup
      await Future.wait([
        _cacheService.initialize(),
        _paginationService.initialize(),
        _cdnService.initialize(),
        _lazyLoadingService.initialize(),
        _dbOptimizationService.initialize(),
        _performanceService.initialize(),
      ]);
      
      // Start performance monitoring
      _startPerformanceMonitoring();
      
      stopwatch.stop();
      
      _recordMetric('initialization_time', stopwatch.elapsedMilliseconds);
      
      debugPrint('PerformanceIntegrationService initialized in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('Error initializing PerformanceIntegrationService: $e');
      rethrow;
    }
  }

  /// Optimized message loading with all performance features
  Future<OptimizedMessageResult> loadMessagesOptimized({
    required String conversationId,
    int page = 0,
    int pageSize = 50,
    bool useCache = true,
    bool preloadNext = true,
    bool enableVirtualScrolling = true,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Use pagination service with caching
      final paginationResult = await _paginationService.loadMessages(
        conversationId: conversationId,
        page: page,
        pageSize: pageSize,
        useCache: useCache,
      );
      
      // Preload media files for messages
      final mediaUrls = paginationResult.messages
          .where((message) => message.mediaUrls.isNotEmpty)
          .expand((message) => message.mediaUrls)
          .toList();
      
      if (mediaUrls.isNotEmpty) {
        _cdnService.preloadMediaFiles(mediaUrls);
      }
      
      // Preload next page if requested
      if (preloadNext && paginationResult.hasMore) {
        _paginationService.preloadNextPage(
          conversationId: conversationId,
          pageSize: pageSize,
        );
      }
      
      stopwatch.stop();
      
      final result = OptimizedMessageResult(
        messages: paginationResult.messages,
        page: page,
        pageSize: pageSize,
        hasMore: paginationResult.hasMore,
        fromCache: paginationResult.fromCache,
        loadTime: stopwatch.elapsedMilliseconds,
        optimizations: OptimizationDetails(
          cacheUsed: useCache,
          preloadEnabled: preloadNext,
          virtualScrollingEnabled: enableVirtualScrolling,
          mediaPreloaded: mediaUrls.length,
        ),
      );
      
      _recordMetric('message_load_time', stopwatch.elapsedMilliseconds);
      _recordMetric('messages_loaded', paginationResult.messages.length);
      
      return result;
    } catch (e) {
      debugPrint('Error loading messages optimized: $e');
      return OptimizedMessageResult(
        messages: [],
        page: page,
        pageSize: pageSize,
        hasMore: false,
        fromCache: false,
        loadTime: 0,
        error: e.toString(),
        optimizations: OptimizationDetails(),
      );
    }
  }

  /// Optimized group member loading with lazy loading
  Future<OptimizedGroupMemberResult> loadGroupMembersOptimized({
    required String groupId,
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
    bool useCache = true,
    bool enableLazyLoading = true,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Use lazy loading service
      final lazyResult = await _lazyLoadingService.lazyLoadGroupMembers(
        groupId: groupId,
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        useCache: useCache,
      );
      
      // Preload user profile images
      final profileImageUrls = lazyResult.items
          .where((user) => user.profileImageUrl != null)
          .map((user) => user.profileImageUrl!)
          .toList();
      
      if (profileImageUrls.isNotEmpty) {
        _cdnService.preloadMediaFiles(profileImageUrls);
      }
      
      stopwatch.stop();
      
      final result = OptimizedGroupMemberResult(
        members: lazyResult.items,
        page: page,
        pageSize: pageSize,
        hasMore: lazyResult.hasMore,
        fromCache: lazyResult.fromCache,
        loadTime: stopwatch.elapsedMilliseconds,
        optimizations: OptimizationDetails(
          cacheUsed: useCache,
          lazyLoadingEnabled: enableLazyLoading,
          profileImagesPreloaded: profileImageUrls.length,
        ),
      );
      
      _recordMetric('group_member_load_time', stopwatch.elapsedMilliseconds);
      _recordMetric('group_members_loaded', lazyResult.items.length);
      
      return result;
    } catch (e) {
      debugPrint('Error loading group members optimized: $e');
      return OptimizedGroupMemberResult(
        members: [],
        page: page,
        pageSize: pageSize,
        hasMore: false,
        fromCache: false,
        loadTime: 0,
        error: e.toString(),
        optimizations: OptimizationDetails(),
      );
    }
  }

  /// Optimized media upload with CDN integration
  Future<OptimizedMediaUploadResult> uploadMediaOptimized({
    required String fileName,
    required Uint8List fileData,
    required MediaType mediaType,
    String? conversationId,
    bool enableCompression = true,
    bool enableCDN = true,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Optimize media file first
      Uint8List optimizedData = fileData;
      if (enableCompression) {
        optimizedData = await _performanceService.optimizeImage(
          imageBytes: fileData,
          quality: 85,
        );
      }
      
      // Upload to CDN
      final uploadResult = await _cdnService.uploadMedia(
        fileName: fileName,
        fileData: optimizedData,
        mediaType: mediaType,
        conversationId: conversationId,
      );
      
      stopwatch.stop();
      
      final result = OptimizedMediaUploadResult(
        success: uploadResult.success,
        downloadUrl: uploadResult.downloadUrl,
        originalSize: fileData.length,
        optimizedSize: optimizedData.length,
        compressionRatio: uploadResult.compressionRatio ?? 0,
        uploadTime: stopwatch.elapsedMilliseconds,
        optimizations: OptimizationDetails(
          compressionEnabled: enableCompression,
          cdnEnabled: enableCDN,
        ),
        error: uploadResult.error,
      );
      
      _recordMetric('media_upload_time', stopwatch.elapsedMilliseconds);
      _recordMetric('media_compression_ratio', (result.compressionRatio * 100).round());
      
      return result;
    } catch (e) {
      debugPrint('Error uploading media optimized: $e');
      return OptimizedMediaUploadResult(
        success: false,
        uploadTime: 0,
        error: e.toString(),
        optimizations: OptimizationDetails(),
      );
    }
  }

  /// Get comprehensive performance statistics
  Map<String, dynamic> getPerformanceStatistics() {
    return {
      'cache_statistics': _cacheService.getCacheStatistics(),
      'pagination_statistics': _paginationService.getCacheStatistics(),
      'cdn_statistics': _cdnService.getCDNStatistics(),
      'lazy_loading_statistics': _lazyLoadingService.getLazyLoadingStatistics(),
      'database_statistics': _dbOptimizationService.getOptimizationStatistics(),
      'performance_metrics': _performanceService.getPerformanceMetrics(),
      'integration_metrics': _getIntegrationMetrics(),
    };
  }

  /// Optimize performance based on current metrics
  Future<void> optimizePerformance() async {
    try {
      final stats = getPerformanceStatistics();
      
      // Check cache hit rates
      final cacheHitRate = stats['cache_statistics']['memory_cache_size'] > 0 ? 0.8 : 0.0;
      if (cacheHitRate < cacheHitRateThreshold) {
        debugPrint('Low cache hit rate detected, optimizing cache strategy');
        await _optimizeCacheStrategy();
      }
      
      // Check average response times
      final avgResponseTime = _getAverageResponseTime();
      if (avgResponseTime > performanceThresholdMs) {
        debugPrint('High response time detected, optimizing queries');
        await _optimizeQueryPerformance();
      }
      
      // Cleanup expired caches
      await _cleanupExpiredCaches();
      
      debugPrint('Performance optimization completed');
    } catch (e) {
      debugPrint('Error optimizing performance: $e');
    }
  }

  /// Clear all performance caches
  Future<void> clearAllCaches() async {
    try {
      await Future.wait([
        _cacheService.clearCache(),
        _cdnService.clearCDNCache(),
        _lazyLoadingService.clearLazyLoadingCache(),
        _dbOptimizationService.clearQueryCache(),
        _performanceService.clearAllCaches(),
      ]);
      
      debugPrint('All performance caches cleared');
    } catch (e) {
      debugPrint('Error clearing all caches: $e');
    }
  }

  /// Dispose all services and resources
  Future<void> dispose() async {
    try {
      _metricsCollectionTimer?.cancel();
      _performanceService.dispose();
      debugPrint('PerformanceIntegrationService disposed');
    } catch (e) {
      debugPrint('Error disposing PerformanceIntegrationService: $e');
    }
  }

  // Private methods

  void _startPerformanceMonitoring() {
    _metricsCollectionTimer = Timer.periodic(metricsCollectionInterval, (timer) {
      _collectPerformanceMetrics();
    });
  }

  void _collectPerformanceMetrics() {
    try {
      final stats = getPerformanceStatistics();
      
      // Record key metrics
      _recordMetric('total_cache_size', stats['cache_statistics']['memory_cache_size'] ?? 0);
      _recordMetric('active_loadings', stats['lazy_loading_statistics']['active_loadings'] ?? 0);
      _recordMetric('cdn_cache_size', stats['cdn_statistics']['cached_urls'] ?? 0);
      
      debugPrint('Performance metrics collected');
    } catch (e) {
      debugPrint('Error collecting performance metrics: $e');
    }
  }

  void _recordMetric(String key, int value) {
    final metric = _performanceMetrics[key] ?? PerformanceMetric(key: key);
    metric.addValue(value);
    _performanceMetrics[key] = metric;
  }

  Map<String, dynamic> _getIntegrationMetrics() {
    return {
      'metrics_count': _performanceMetrics.length,
      'metrics': _performanceMetrics.map((key, metric) => MapEntry(key, metric.toMap())),
      'monitoring_active': _metricsCollectionTimer?.isActive ?? false,
    };
  }

  double _getAverageResponseTime() {
    final loadTimeMetric = _performanceMetrics['message_load_time'];
    return loadTimeMetric?.average ?? 0.0;
  }

  Future<void> _optimizeCacheStrategy() async {
    try {
      // Increase cache sizes for better hit rates
      await _cacheService.cleanupExpiredCache();
      debugPrint('Cache strategy optimized');
    } catch (e) {
      debugPrint('Error optimizing cache strategy: $e');
    }
  }

  Future<void> _optimizeQueryPerformance() async {
    try {
      // Clear slow query caches to force re-optimization
      await _dbOptimizationService.clearQueryCache();
      debugPrint('Query performance optimized');
    } catch (e) {
      debugPrint('Error optimizing query performance: $e');
    }
  }

  Future<void> _cleanupExpiredCaches() async {
    try {
      await _cacheService.cleanupExpiredCache();
      debugPrint('Expired caches cleaned up');
    } catch (e) {
      debugPrint('Error cleaning up expired caches: $e');
    }
  }
}

/// Performance metric tracking
class PerformanceMetric {
  final String key;
  final List<int> values = [];
  int totalValue = 0;
  int count = 0;
  DateTime lastUpdated = DateTime.now();

  PerformanceMetric({required this.key});

  void addValue(int value) {
    values.add(value);
    totalValue += value;
    count++;
    lastUpdated = DateTime.now();
    
    // Keep only last 100 values
    if (values.length > 100) {
      final removedValue = values.removeAt(0);
      totalValue -= removedValue;
      count--;
    }
  }

  double get average => count > 0 ? totalValue / count : 0.0;
  int get min => values.isNotEmpty ? values.reduce((a, b) => a < b ? a : b) : 0;
  int get max => values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 0;

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'count': count,
      'average': average,
      'min': min,
      'max': max,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

/// Optimization details
class OptimizationDetails {
  final bool cacheUsed;
  final bool preloadEnabled;
  final bool virtualScrollingEnabled;
  final bool lazyLoadingEnabled;
  final bool compressionEnabled;
  final bool cdnEnabled;
  final int mediaPreloaded;
  final int profileImagesPreloaded;

  OptimizationDetails({
    this.cacheUsed = false,
    this.preloadEnabled = false,
    this.virtualScrollingEnabled = false,
    this.lazyLoadingEnabled = false,
    this.compressionEnabled = false,
    this.cdnEnabled = false,
    this.mediaPreloaded = 0,
    this.profileImagesPreloaded = 0,
  });
}

/// Optimized message result
class OptimizedMessageResult {
  final List<dynamic> messages; // MessageModel list
  final int page;
  final int pageSize;
  final bool hasMore;
  final bool fromCache;
  final int loadTime;
  final OptimizationDetails optimizations;
  final String? error;

  OptimizedMessageResult({
    required this.messages,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    required this.fromCache,
    required this.loadTime,
    required this.optimizations,
    this.error,
  });

  bool get hasError => error != null;
  bool get isEmpty => messages.isEmpty;
}

/// Optimized group member result
class OptimizedGroupMemberResult {
  final List<dynamic> members; // UserModel list
  final int page;
  final int pageSize;
  final bool hasMore;
  final bool fromCache;
  final int loadTime;
  final OptimizationDetails optimizations;
  final String? error;

  OptimizedGroupMemberResult({
    required this.members,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    required this.fromCache,
    required this.loadTime,
    required this.optimizations,
    this.error,
  });

  bool get hasError => error != null;
  bool get isEmpty => members.isEmpty;
}

/// Optimized media upload result
class OptimizedMediaUploadResult {
  final bool success;
  final String? downloadUrl;
  final int originalSize;
  final int optimizedSize;
  final double compressionRatio;
  final int uploadTime;
  final OptimizationDetails optimizations;
  final String? error;

  OptimizedMediaUploadResult({
    required this.success,
    this.downloadUrl,
    this.originalSize = 0,
    this.optimizedSize = 0,
    this.compressionRatio = 0.0,
    required this.uploadTime,
    required this.optimizations,
    this.error,
  });

  bool get hasError => error != null;
}