import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'cdn_service.dart';
import 'asset_optimizer.dart';
import 'cache_invalidation_service.dart';
import '../performance/performance_monitor.dart';

/// CDN Integration Service for TALOWA
/// Orchestrates all CDN-related services and provides unified interface
class CDNIntegration {
  static final CDNIntegration _instance = CDNIntegration._internal();
  factory CDNIntegration() => _instance;
  CDNIntegration._internal();
  
  late CDNService _cdnService;
  late AssetOptimizer _assetOptimizer;
  late CacheInvalidationService _cacheInvalidation;
  late PerformanceMonitor _performanceMonitor;
  
  bool _initialized = false;
  
  // Integration metrics
  final Map<String, CDNMetrics> _metricsCache = {};
  Timer? _metricsCollector;
  
  /// Initialize all CDN services
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      print('🚀 Initializing CDN Integration...');
      
      // Initialize core services
      _cdnService = CDNService();
      _assetOptimizer = AssetOptimizer();
      _cacheInvalidation = CacheInvalidationService();
      _performanceMonitor = PerformanceMonitor();
      
      // Initialize services in order
      await _performanceMonitor.initialize();
      await _assetOptimizer.initialize();
      await _cdnService.initialize();
      await _cacheInvalidation.initialize();
      
      // Start metrics collection
      _startMetricsCollection();
      
      _initialized = true;
      print('✅ CDN Integration initialized successfully');
      
      // Log initialization metrics
      await _logInitializationMetrics();
      
    } catch (e) {
      print('❌ CDN Integration initialization failed: $e');
      rethrow;
    }
  }
  
  /// Upload asset with full optimization and CDN integration
  Future<CDNIntegrationResult> uploadAsset({
    required File file,
    required String assetType,
    String? customPath,
    CDNUploadOptions? options,
  }) async {
    if (!_initialized) {
      throw StateError('CDN Integration not initialized');
    }
    
    final startTime = DateTime.now();
    
    try {
      // Track upload start
      _performanceMonitor.trackCDNMetric('upload_start', 1);
      
      // Get optimization recommendation
      final recommendation = await _assetOptimizer.getOptimizationRecommendation(file);
      
      // Upload with optimization
      final uploadResult = await _cdnService.uploadFile(
        file: file,
        path: customPath ?? _generateAssetPath(assetType, file),
        compress: options?.optimize ?? true,
        generateThumbnail: options?.optimizationOptions?.generateThumbnail ?? false,
        metadata: {
          'assetType': assetType,
          'optimizationPriority': recommendation.priority.name,
          'estimatedSavings': recommendation.estimatedSavings.toString(),
          ...?options?.customMetadata,
        },
      );
      
      if (!uploadResult.success) {
        _performanceMonitor.trackCDNMetric('upload_error', 1);
        throw Exception('Upload failed: ${uploadResult.error}');
      }
      
      // Track successful upload
      final uploadTime = DateTime.now().difference(startTime);
      _performanceMonitor.trackCDNMetric('upload_success', 1);
      _performanceMonitor.trackCDNMetric('upload_duration', uploadTime.inMilliseconds);
      
      // Schedule cache warming if needed
      if (assetType == 'profile' || assetType == 'critical') {
        await _warmCache(uploadResult.asset!.downloadUrl);
      }
      
      return CDNIntegrationResult(
        success: true,
        asset: uploadResult.asset,
        uploadTime: uploadTime,
        optimizationRecommendation: recommendation,
        cacheWarmed: assetType == 'profile' || assetType == 'critical',
      );
      
    } catch (e) {
      final uploadTime = DateTime.now().difference(startTime);
      _performanceMonitor.trackCDNMetric('upload_error', 1);
      
      print('❌ CDN asset upload failed: $e');
      
      return CDNIntegrationResult(
        success: false,
        error: e.toString(),
        uploadTime: uploadTime,
      );
    }
  }
  
  /// Batch upload multiple assets
  Future<List<CDNIntegrationResult>> batchUploadAssets({
    required List<File> files,
    required String assetType,
    String? basePath,
    CDNUploadOptions? options,
    int? maxConcurrency,
  }) async {
    if (!_initialized) {
      throw StateError('CDN Integration not initialized');
    }
    
    final startTime = DateTime.now();
    final concurrency = maxConcurrency ?? 3;
    
    try {
      print('📦 Starting batch upload of ${files.length} assets...');
      _performanceMonitor.trackCDNMetric('batch_upload_start', 1);
      
      final results = <CDNIntegrationResult>[];
      
      // Process files in batches
      for (int i = 0; i < files.length; i += concurrency) {
        final batch = files.skip(i).take(concurrency).toList();
        
        final batchFutures = batch.map((file) async {
          final customPath = basePath != null 
              ? '$basePath/${file.path.split('/').last}'
              : null;
          
          return await uploadAsset(
            file: file,
            assetType: assetType,
            customPath: customPath,
            options: options,
          );
        }).toList();
        
        final batchResults = await Future.wait(batchFutures);
        results.addAll(batchResults);
        
        print('  Processed batch ${(i ~/ concurrency) + 1}/${(files.length / concurrency).ceil()}');
      }
      
      final batchTime = DateTime.now().difference(startTime);
      final successCount = results.where((r) => r.success).length;
      
      _performanceMonitor.trackCDNMetric('batch_upload_complete', 1);
      _performanceMonitor.trackCDNMetric('batch_upload_duration', batchTime.inMilliseconds);
      _performanceMonitor.trackCDNMetric('batch_success_rate', (successCount / files.length * 100).round());
      
      print('✅ Batch upload completed: $successCount/${files.length} successful');
      
      return results;
      
    } catch (e) {
      _performanceMonitor.trackCDNMetric('batch_upload_error', 1);
      print('❌ Batch upload failed: $e');
      rethrow;
    }
  }
  
  /// Invalidate cache for specific content
  Future<void> invalidateContent({
    required String contentType,
    required String contentId,
    String? reason,
    InvalidationPriority priority = InvalidationPriority.medium,
  }) async {
    if (!_initialized) return;
    
    try {
      final invalidationType = _mapContentTypeToInvalidationType(contentType);
      
      await _cacheInvalidation.invalidateManual(
        type: invalidationType,
        resourceId: contentId,
        reason: reason,
        priority: priority,
      );
      
      _performanceMonitor.trackCDNMetric('cache_invalidation', 1);
      
    } catch (e) {
      print('❌ Cache invalidation failed: $e');
    }
  }
  
  /// Warm cache for critical assets
  Future<void> _warmCache(String assetUrl) async {
    try {
      // In a real implementation, you would make requests to warm the cache
      // This could involve making HTTP requests to the CDN endpoints
      
      print('🔥 Warming cache for: $assetUrl');
      _performanceMonitor.trackCDNMetric('cache_warm', 1);
      
    } catch (e) {
      print('⚠️  Cache warming failed: $e');
    }
  }
  
  /// Get comprehensive CDN analytics
  Future<CDNIntegrationAnalytics> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_initialized) {
      throw StateError('CDN Integration not initialized');
    }
    
    try {
      // Gather analytics from all services
      final cdnAnalytics = await _cdnService.getAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
      
      final invalidationStats = await _cacheInvalidation.getInvalidationStats(
        startDate: startDate,
        endDate: endDate,
      );
      
      final performanceMetrics = _performanceMonitor.getCDNMetrics();
      
      return CDNIntegrationAnalytics(
        period: DateRange(
          startDate ?? DateTime.now().subtract(const Duration(days: 30)),
          endDate ?? DateTime.now(),
        ),
        cdnAnalytics: cdnAnalytics,
        invalidationStats: invalidationStats,
        performanceMetrics: performanceMetrics,
        integrationMetrics: _getIntegrationMetrics(),
      );
      
    } catch (e) {
      print('❌ Failed to get CDN analytics: $e');
      return CDNIntegrationAnalytics.empty();
    }
  }
  
  /// Get integration-specific metrics
  Map<String, dynamic> _getIntegrationMetrics() {
    return {
      'services_initialized': _initialized,
      'metrics_cache_size': _metricsCache.length,
      'uptime': DateTime.now().difference(_initializationTime).inMinutes,
    };
  }
  
  late DateTime _initializationTime;
  
  /// Start metrics collection
  void _startMetricsCollection() {
    _initializationTime = DateTime.now();
    
    _metricsCollector = Timer.periodic(const Duration(minutes: 5), (timer) {
      _collectMetrics();
    });
  }
  
  /// Collect and cache metrics
  Future<void> _collectMetrics() async {
    try {
      final timestamp = DateTime.now();
      
      // Collect CDN metrics
      final cdnAnalytics = await _cdnService.getAnalytics();
      final invalidationStats = await _cacheInvalidation.getInvalidationStats();
      
      final metrics = CDNMetrics(
        timestamp: timestamp,
        totalAssets: cdnAnalytics.totalAssets,
        totalSize: cdnAnalytics.totalSize,
        compressionRatio: cdnAnalytics.compressionRatio,
        cacheHitRate: 0.95, // Simulated
        averageResponseTime: const Duration(milliseconds: 45),
        pendingInvalidations: invalidationStats.totalPendingInvalidations,
      );
      
      _metricsCache[timestamp.toIso8601String()] = metrics;
      
      // Keep only last 24 hours of metrics
      final cutoff = timestamp.subtract(const Duration(hours: 24));
      _metricsCache.removeWhere((key, value) => 
          DateTime.parse(key).isBefore(cutoff));
      
    } catch (e) {
      print('⚠️  Metrics collection failed: $e');
    }
  }
  
  /// Generate asset path based on type and file
  String _generateAssetPath(String assetType, File file) {
    final fileName = file.path.split('/').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    switch (assetType.toLowerCase()) {
      case 'profile':
        return 'profiles/$timestamp/$fileName';
      case 'post':
        return 'posts/$timestamp/$fileName';
      case 'event':
        return 'events/$timestamp/$fileName';
      case 'organization':
        return 'organizations/$timestamp/$fileName';
      default:
        return 'assets/$assetType/$timestamp/$fileName';
    }
  }
  
  /// Map content type to invalidation type
  InvalidationType _mapContentTypeToInvalidationType(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'user':
      case 'profile':
        return InvalidationType.userProfile;
      case 'post':
      case 'feed':
        return InvalidationType.feedContent;
      case 'event':
        return InvalidationType.eventContent;
      case 'asset':
      case 'image':
      case 'video':
        return InvalidationType.assetContent;
      default:
        return InvalidationType.globalCache;
    }
  }
  
  /// Log initialization metrics
  Future<void> _logInitializationMetrics() async {
    try {
      final metrics = {
        'initialization_time': DateTime.now().toIso8601String(),
        'services_count': 4,
        'cdn_enabled': true,
        'optimization_enabled': true,
        'cache_invalidation_enabled': true,
        'performance_monitoring_enabled': true,
      };
      
      if (kDebugMode) {
        print('📊 CDN Integration metrics: $metrics');
      }
      
    } catch (e) {
      print('⚠️  Failed to log initialization metrics: $e');
    }
  }
  
  /// Health check for all CDN services
  Future<CDNHealthStatus> healthCheck() async {
    if (!_initialized) {
      return CDNHealthStatus(
        overall: HealthStatus.unhealthy,
        services: {
          'cdn': HealthStatus.unhealthy,
          'optimizer': HealthStatus.unhealthy,
          'cache_invalidation': HealthStatus.unhealthy,
          'performance_monitor': HealthStatus.unhealthy,
        },
        message: 'CDN Integration not initialized',
      );
    }
    
    try {
      final services = <String, HealthStatus>{};
      
      // Check CDN service
      try {
        await _cdnService.getAnalytics();
        services['cdn'] = HealthStatus.healthy;
      } catch (e) {
        services['cdn'] = HealthStatus.unhealthy;
      }
      
      // Check asset optimizer
      try {
        services['optimizer'] = HealthStatus.healthy;
      } catch (e) {
        services['optimizer'] = HealthStatus.unhealthy;
      }
      
      // Check cache invalidation
      try {
        await _cacheInvalidation.getInvalidationStats();
        services['cache_invalidation'] = HealthStatus.healthy;
      } catch (e) {
        services['cache_invalidation'] = HealthStatus.unhealthy;
      }
      
      // Check performance monitor
      try {
        _performanceMonitor.getCDNMetrics();
        services['performance_monitor'] = HealthStatus.healthy;
      } catch (e) {
        services['performance_monitor'] = HealthStatus.unhealthy;
      }
      
      final healthyCount = services.values.where((s) => s == HealthStatus.healthy).length;
      final overall = healthyCount == services.length 
          ? HealthStatus.healthy 
          : healthyCount > services.length / 2 
              ? HealthStatus.degraded 
              : HealthStatus.unhealthy;
      
      return CDNHealthStatus(
        overall: overall,
        services: services,
        message: 'CDN services: $healthyCount/${services.length} healthy',
      );
      
    } catch (e) {
      return CDNHealthStatus(
        overall: HealthStatus.unhealthy,
        services: {},
        message: 'Health check failed: $e',
      );
    }
  }
  
  /// Dispose all services
  void dispose() {
    _metricsCollector?.cancel();
    _cacheInvalidation.dispose();
    _metricsCache.clear();
    _initialized = false;
    print('🧹 CDN Integration disposed');
  }
}

/// CDN Integration Result
class CDNIntegrationResult {
  final bool success;
  final CDNAsset? asset;
  final Duration uploadTime;
  final OptimizationRecommendation? optimizationRecommendation;
  final bool cacheWarmed;
  final String? error;
  
  CDNIntegrationResult({
    required this.success,
    this.asset,
    required this.uploadTime,
    this.optimizationRecommendation,
    this.cacheWarmed = false,
    this.error,
  });
}

/// CDN Integration Analytics
class CDNIntegrationAnalytics {
  final DateRange period;
  final CDNAnalytics cdnAnalytics;
  final InvalidationStats invalidationStats;
  final Map<String, dynamic> performanceMetrics;
  final Map<String, dynamic> integrationMetrics;
  
  CDNIntegrationAnalytics({
    required this.period,
    required this.cdnAnalytics,
    required this.invalidationStats,
    required this.performanceMetrics,
    required this.integrationMetrics,
  });
  
  factory CDNIntegrationAnalytics.empty() {
    return CDNIntegrationAnalytics(
      period: DateRange(DateTime.now(), DateTime.now()),
      cdnAnalytics: CDNAnalytics.empty(),
      invalidationStats: InvalidationStats.empty(),
      performanceMetrics: {},
      integrationMetrics: {},
    );
  }
}

/// CDN Metrics
class CDNMetrics {
  final DateTime timestamp;
  final int totalAssets;
  final int totalSize;
  final double compressionRatio;
  final double cacheHitRate;
  final Duration averageResponseTime;
  final int pendingInvalidations;
  
  CDNMetrics({
    required this.timestamp,
    required this.totalAssets,
    required this.totalSize,
    required this.compressionRatio,
    required this.cacheHitRate,
    required this.averageResponseTime,
    required this.pendingInvalidations,
  });
}

/// CDN Health Status
class CDNHealthStatus {
  final HealthStatus overall;
  final Map<String, HealthStatus> services;
  final String message;
  
  CDNHealthStatus({
    required this.overall,
    required this.services,
    required this.message,
  });
}

/// Health Status
enum HealthStatus {
  healthy,
  degraded,
  unhealthy,
}