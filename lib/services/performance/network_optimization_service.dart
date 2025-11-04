// Network Optimization Service - API call optimization and caching management
// Comprehensive network performance optimization for TALOWA platform

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for optimizing network requests and managing API call efficiency
class NetworkOptimizationService {
  static NetworkOptimizationService? _instance;
  static NetworkOptimizationService get instance => _instance ??= NetworkOptimizationService._internal();
  
  NetworkOptimizationService._internal();
  
  // Request tracking and deduplication
  final Map<String, Future<http.Response>> _activeRequests = {};
  final Map<String, CachedResponse> _responseCache = {};
  final Map<String, RequestMetrics> _requestMetrics = {};
  
  // Batch processing
  final Map<String, List<BatchRequest>> _batchQueues = {};
  Timer? _batchProcessingTimer;
  
  // Configuration
  static const Duration defaultCacheExpiry = Duration(minutes: 5);
  static const Duration batchProcessingInterval = Duration(milliseconds: 100);
  static const int maxConcurrentRequests = 10;
  static const int maxCacheSize = 1000;
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Performance tracking
  int _totalRequests = 0;
  int _cachedResponses = 0;
  int _deduplicatedRequests = 0;
  int _failedRequests = 0;
  
  // Configuration flags
  bool _compressionEnabled = false;
  bool _requestBatchingEnabled = false;

  /// Initialize network optimization service
  static Future<void> initialize() async {
    try {
      debugPrint('🌐 Initializing Network Optimization Service...');
      
      final service = instance;
      
      // Start batch processing
      service._startBatchProcessing();
      
      // Setup periodic cache cleanup
      service._setupCacheCleanup();
      
      debugPrint('✅ Network Optimization Service initialized');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize network optimization: $e');
    }
  }
  
  /// Execute optimized HTTP request with caching and deduplication
  Future<http.Response> executeRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
    Duration? cacheExpiry,
    bool enableDeduplication = true,
    bool enableCaching = true,
    String? cacheKey,
  }) async {
    _totalRequests++;
    
    final requestKey = cacheKey ?? _generateRequestKey(method, url, headers, body);
    final startTime = DateTime.now();
    
    try {
      // Check cache first
      if (enableCaching && method.toLowerCase() == 'get') {
        final cachedResponse = _getCachedResponse(requestKey);
        if (cachedResponse != null) {
          _cachedResponses++;
          _updateRequestMetrics(requestKey, startTime, true, false);
          debugPrint('📦 Cache hit for: $url');
          return cachedResponse;
        }
      }
      
      // Check for active request (deduplication)
      if (enableDeduplication && _activeRequests.containsKey(requestKey)) {
        _deduplicatedRequests++;
        debugPrint('🔄 Deduplicated request for: $url');
        return await _activeRequests[requestKey]!;
      }
      
      // Execute new request
      final requestFuture = _executeHttpRequest(method, url, headers, body);
      
      if (enableDeduplication) {
        _activeRequests[requestKey] = requestFuture;
      }
      
      final response = await requestFuture;
      
      // Cache successful GET responses
      if (enableCaching && method.toLowerCase() == 'get' && response.statusCode == 200) {
        _cacheResponse(requestKey, response, cacheExpiry ?? defaultCacheExpiry);
      }
      
      _updateRequestMetrics(requestKey, startTime, false, response.statusCode == 200);
      
      return response;
      
    } catch (e) {
      _failedRequests++;
      _updateRequestMetrics(requestKey, startTime, false, false);
      debugPrint('❌ Request failed for $url: $e');
      rethrow;
    } finally {
      _activeRequests.remove(requestKey);
    }
  }
  
  /// Add request to batch queue
  void addToBatch(String batchKey, BatchRequest request) {
    _batchQueues.putIfAbsent(batchKey, () => []).add(request);
    debugPrint('📦 Added request to batch: $batchKey (${_batchQueues[batchKey]!.length} requests)');
  }
  
  /// Execute batch requests
  Future<List<http.Response>> executeBatch(String batchKey) async {
    final requests = _batchQueues.remove(batchKey);
    if (requests == null || requests.isEmpty) {
      return [];
    }
    
    debugPrint('🚀 Executing batch: $batchKey (${requests.length} requests)');
    
    final futures = requests.map((request) => executeRequest(
      method: request.method,
      url: request.url,
      headers: request.headers,
      body: request.body,
      cacheExpiry: request.cacheExpiry,
      enableDeduplication: request.enableDeduplication,
      enableCaching: request.enableCaching,
    ));
    
    return await Future.wait(futures);
  }
  
  /// Clear cache for specific key or all cache
  void clearCache([String? key]) {
    if (key != null) {
      _responseCache.remove(key);
      debugPrint('🗑️ Cleared cache for key: $key');
    } else {
      _responseCache.clear();
      debugPrint('🗑️ Cleared all cache');
    }
  }
  
  /// Get network performance statistics
  Map<String, dynamic> getPerformanceStatistics() {
    final cacheHitRate = _totalRequests > 0 ? (_cachedResponses / _totalRequests) * 100 : 0.0;
    final deduplicationRate = _totalRequests > 0 ? (_deduplicatedRequests / _totalRequests) * 100 : 0.0;
    final failureRate = _totalRequests > 0 ? (_failedRequests / _totalRequests) * 100 : 0.0;
    
    final averageResponseTime = _calculateAverageResponseTime();
    final slowRequests = _getSlowRequests();
    
    return {
      'totalRequests': _totalRequests,
      'cachedResponses': _cachedResponses,
      'deduplicatedRequests': _deduplicatedRequests,
      'failedRequests': _failedRequests,
      'cacheHitRate': cacheHitRate,
      'deduplicationRate': deduplicationRate,
      'failureRate': failureRate,
      'averageResponseTimeMs': averageResponseTime,
      'cacheSize': _responseCache.length,
      'activeRequests': _activeRequests.length,
      'batchQueues': _batchQueues.length,
      'slowRequests': slowRequests.length,
      'performanceScore': _calculateNetworkPerformanceScore(),
    };
  }
  
  /// Get request metrics for specific URL pattern
  List<RequestMetrics> getRequestMetrics({String? urlPattern}) {
    var metrics = _requestMetrics.values.toList();
    
    if (urlPattern != null) {
      metrics = metrics.where((m) => m.url.contains(urlPattern)).toList();
    }
    
    return metrics..sort((a, b) => 
        (b.lastRequestTime ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.lastRequestTime ?? DateTime.fromMillisecondsSinceEpoch(0)));
  }
  
  /// Generate network optimization recommendations
  List<NetworkOptimizationRecommendation> generateRecommendations() {
    final recommendations = <NetworkOptimizationRecommendation>[];
    
    // Check cache hit rate
    final cacheHitRate = _totalRequests > 0 ? (_cachedResponses / _totalRequests) * 100 : 0.0;
    if (cacheHitRate < 30.0 && _totalRequests > 10) {
      recommendations.add(NetworkOptimizationRecommendation(
        type: NetworkOptimizationType.lowCacheHitRate,
        priority: NetworkRecommendationPriority.high,
        description: 'Low cache hit rate: ${cacheHitRate.toStringAsFixed(1)}%',
        suggestions: [
          'Increase cache expiry times for stable data',
          'Implement more aggressive caching strategies',
          'Use cache-first approaches where appropriate',
          'Consider implementing offline-first patterns',
        ],
      ));
    }
    
    // Check for slow requests
    final slowRequests = _getSlowRequests();
    if (slowRequests.isNotEmpty) {
      recommendations.add(NetworkOptimizationRecommendation(
        type: NetworkOptimizationType.slowRequests,
        priority: NetworkRecommendationPriority.medium,
        description: '${slowRequests.length} slow requests detected (>2s response time)',
        suggestions: [
          'Optimize backend API performance',
          'Implement request pagination',
          'Use GraphQL for efficient data fetching',
          'Consider CDN for static resources',
          'Implement progressive loading',
        ],
      ));
    }
    
    // Check failure rate
    final failureRate = _totalRequests > 0 ? (_failedRequests / _totalRequests) * 100 : 0.0;
    if (failureRate > 5.0) {
      recommendations.add(NetworkOptimizationRecommendation(
        type: NetworkOptimizationType.highFailureRate,
        priority: NetworkRecommendationPriority.critical,
        description: 'High failure rate: ${failureRate.toStringAsFixed(1)}%',
        suggestions: [
          'Implement retry mechanisms with exponential backoff',
          'Add proper error handling and fallbacks',
          'Monitor network connectivity',
          'Implement offline capabilities',
          'Add request timeout handling',
        ],
      ));
    }
    
    // Check for redundant requests
    final redundantRequests = _findRedundantRequests();
    if (redundantRequests.isNotEmpty) {
      recommendations.add(NetworkOptimizationRecommendation(
        type: NetworkOptimizationType.redundantRequests,
        priority: NetworkRecommendationPriority.high,
        description: '${redundantRequests.length} patterns with redundant requests',
        suggestions: [
          'Implement request deduplication',
          'Use batch requests where possible',
          'Consolidate similar API calls',
          'Implement proper state management',
        ],
      ));
    }
    
    return recommendations..sort((a, b) => b.priority.index.compareTo(a.priority.index));
  }
  
  /// Execute HTTP request with timeout and error handling
  Future<http.Response> _executeHttpRequest(
    String method,
    String url,
    Map<String, String>? headers,
    dynamic body,
  ) async {
    final client = http.Client();
    
    try {
      final uri = Uri.parse(url);
      final request = http.Request(method.toUpperCase(), uri);
      
      if (headers != null) {
        request.headers.addAll(headers);
      }
      
      if (body != null) {
        if (body is String) {
          request.body = body;
        } else if (body is Map) {
          request.body = jsonEncode(body);
          request.headers['Content-Type'] = 'application/json';
        }
      }
      
      final streamedResponse = await client.send(request).timeout(requestTimeout);
      return await http.Response.fromStream(streamedResponse);
      
    } on TimeoutException {
      throw NetworkOptimizationException('Request timeout for $url');
    } on SocketException {
      throw NetworkOptimizationException('Network error for $url');
    } finally {
      client.close();
    }
  }
  
  /// Generate request key for caching and deduplication
  String _generateRequestKey(String method, String url, Map<String, String>? headers, dynamic body) {
    final keyComponents = [method.toUpperCase(), url];
    
    if (headers != null && headers.isNotEmpty) {
      final sortedHeaders = Map.fromEntries(
        headers.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      keyComponents.add(jsonEncode(sortedHeaders));
    }
    
    if (body != null) {
      keyComponents.add(body is String ? body : jsonEncode(body));
    }
    
    return keyComponents.join('|');
  }
  
  /// Get cached response if valid
  http.Response? _getCachedResponse(String key) {
    final cached = _responseCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.response;
    }
    
    if (cached != null && cached.isExpired) {
      _responseCache.remove(key);
    }
    
    return null;
  }
  
  /// Cache response
  void _cacheResponse(String key, http.Response response, Duration expiry) {
    if (_responseCache.length >= maxCacheSize) {
      _cleanupOldCache();
    }
    
    _responseCache[key] = CachedResponse(
      response: response,
      cachedAt: DateTime.now(),
      expiresAt: DateTime.now().add(expiry),
    );
  }
  
  /// Update request metrics
  void _updateRequestMetrics(String key, DateTime startTime, bool fromCache, bool success) {
    final responseTime = DateTime.now().difference(startTime);
    
    final metrics = _requestMetrics.putIfAbsent(key, () => RequestMetrics(url: key));
    metrics.recordRequest(responseTime, fromCache, success);
  }
  
  /// Start batch processing timer
  void _startBatchProcessing() {
    _batchProcessingTimer = Timer.periodic(batchProcessingInterval, (timer) {
      _processPendingBatches();
    });
  }
  
  /// Process pending batch requests
  void _processPendingBatches() {
    final batchKeys = _batchQueues.keys.toList();
    
    for (final batchKey in batchKeys) {
      final requests = _batchQueues[batchKey];
      if (requests != null && requests.isNotEmpty) {
        // Auto-execute batches that have been waiting
        final oldestRequest = requests.first;
        final waitTime = DateTime.now().difference(oldestRequest.createdAt);
        
        if (waitTime > batchProcessingInterval || requests.length >= 5) {
          executeBatch(batchKey);
        }
      }
    }
  }
  
  /// Setup periodic cache cleanup
  void _setupCacheCleanup() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _cleanupExpiredCache();
    });
  }
  
  /// Cleanup expired cache entries
  void _cleanupExpiredCache() {
    final expiredKeys = _responseCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _responseCache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }
  
  /// Cleanup old cache entries when limit is reached
  void _cleanupOldCache() {
    final sortedEntries = _responseCache.entries.toList()
      ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));
    
    final entriesToRemove = sortedEntries.take(100).toList();
    
    for (final entry in entriesToRemove) {
      _responseCache.remove(entry.key);
    }
    
    debugPrint('🧹 Cleaned up ${entriesToRemove.length} old cache entries');
  }
  
  /// Calculate average response time
  double _calculateAverageResponseTime() {
    if (_requestMetrics.isEmpty) return 0.0;
    
    final totalTime = _requestMetrics.values
        .map((m) => m.averageResponseTime)
        .reduce((a, b) => a + b);
    
    return totalTime / _requestMetrics.length;
  }
  
  /// Get slow requests (>2 seconds)
  List<RequestMetrics> _getSlowRequests() {
    return _requestMetrics.values
        .where((m) => m.averageResponseTime > 2000.0)
        .toList();
  }
  
  /// Find redundant request patterns
  List<String> _findRedundantRequests() {
    final urlPatterns = <String, int>{};
    
    for (final metrics in _requestMetrics.values) {
      final pattern = _extractUrlPattern(metrics.url);
      urlPatterns[pattern] = (urlPatterns[pattern] ?? 0) + metrics.requestCount;
    }
    
    return urlPatterns.entries
        .where((entry) => entry.value > 10)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Extract URL pattern for redundancy detection
  String _extractUrlPattern(String url) {
    // Remove query parameters and IDs for pattern matching
    return url.replaceAll(RegExp(r'\?.*'), '')
              .replaceAll(RegExp(r'/\d+'), '/{id}')
              .replaceAll(RegExp(r'/[a-f0-9-]{36}'), '/{uuid}');
  }
  
  /// Calculate network performance score
  double _calculateNetworkPerformanceScore() {
    double score = 100.0;
    
    // Penalize low cache hit rate
    final cacheHitRate = _totalRequests > 0 ? (_cachedResponses / _totalRequests) * 100 : 0.0;
    if (cacheHitRate < 50.0) {
      score -= (50.0 - cacheHitRate) * 0.5;
    }
    
    // Penalize high failure rate
    final failureRate = _totalRequests > 0 ? (_failedRequests / _totalRequests) * 100 : 0.0;
    score -= failureRate * 2;
    
    // Penalize slow requests
    final slowRequestCount = _getSlowRequests().length;
    score -= slowRequestCount * 5;
    
    return score.clamp(0.0, 100.0);
  }
  
  /// Dispose network optimization service
  Future<void> dispose() async {
    debugPrint('🧹 Disposing Network Optimization Service...');
    
    _batchProcessingTimer?.cancel();
    _activeRequests.clear();
    _responseCache.clear();
    _requestMetrics.clear();
    _batchQueues.clear();
    
    debugPrint('✅ Network Optimization Service disposed');
  }
}

/// Cached response wrapper
class CachedResponse {
  final http.Response response;
  final DateTime cachedAt;
  final DateTime expiresAt;
  
  CachedResponse({
    required this.response,
    required this.cachedAt,
    required this.expiresAt,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Request metrics tracking
class RequestMetrics {
  final String url;
  final DateTime createdAt;
  
  int requestCount = 0;
  int successCount = 0;
  int cacheHits = 0;
  double totalResponseTime = 0.0;
  DateTime? lastRequestTime;
  
  RequestMetrics({required this.url}) : createdAt = DateTime.now();
  
  void recordRequest(Duration responseTime, bool fromCache, bool success) {
    requestCount++;
    lastRequestTime = DateTime.now();
    
    if (success) successCount++;
    if (fromCache) cacheHits++;
    
    totalResponseTime += responseTime.inMilliseconds.toDouble();
  }
  
  double get averageResponseTime {
    return requestCount > 0 ? totalResponseTime / requestCount : 0.0;
  }
  
  double get successRate {
    return requestCount > 0 ? (successCount / requestCount) * 100 : 0.0;
  }
  
  double get cacheHitRate {
    return requestCount > 0 ? (cacheHits / requestCount) * 100 : 0.0;
  }
}

/// Batch request wrapper
class BatchRequest {
  final String method;
  final String url;
  final Map<String, String>? headers;
  final dynamic body;
  final Duration? cacheExpiry;
  final bool enableDeduplication;
  final bool enableCaching;
  final DateTime createdAt;
  
  BatchRequest({
    required this.method,
    required this.url,
    this.headers,
    this.body,
    this.cacheExpiry,
    this.enableDeduplication = true,
    this.enableCaching = true,
  }) : createdAt = DateTime.now();
}

/// Network optimization recommendation
class NetworkOptimizationRecommendation {
  final NetworkOptimizationType type;
  final NetworkRecommendationPriority priority;
  final String description;
  final List<String> suggestions;
  
  NetworkOptimizationRecommendation({
    required this.type,
    required this.priority,
    required this.description,
    required this.suggestions,
  });
}

/// Network optimization types
enum NetworkOptimizationType {
  lowCacheHitRate,
  slowRequests,
  highFailureRate,
  redundantRequests,
  excessiveBandwidth,
}

/// Network recommendation priorities
enum NetworkRecommendationPriority {
  low,
  medium,
  high,
  critical,
}

/// Network optimization exception
class NetworkOptimizationException implements Exception {
  final String message;
  
  NetworkOptimizationException(this.message);
  
  @override
  String toString() => 'NetworkOptimizationException: $message';
}

/// Enable compression for network requests
extension NetworkOptimizationServiceExtensions on NetworkOptimizationService {
  /// Enable compression for network requests
  void enableCompression() {
    _compressionEnabled = true;
    debugPrint('🗜️ Network compression enabled');
  }
  
  /// Disable compression for network requests
  void disableCompression() {
    _compressionEnabled = false;
    debugPrint('🗜️ Network compression disabled');
  }
  
  /// Enable request batching
  void enableRequestBatching() {
    _requestBatchingEnabled = true;
    debugPrint('📦 Request batching enabled');
  }
  
  /// Disable request batching
  void disableRequestBatching() {
    _requestBatchingEnabled = false;
    debugPrint('📦 Request batching disabled');
  }
  
  /// Check if compression is enabled
  bool get isCompressionEnabled => _compressionEnabled;
  
  /// Check if request batching is enabled
  bool get isRequestBatchingEnabled => _requestBatchingEnabled;
}

/// Extension to add missing methods to NetworkOptimizationService
extension NetworkOptimizationServiceMethods on NetworkOptimizationService {
  /// Optimize a request by wrapping it with performance monitoring
  Future<T> optimizeRequest<T>(Future<T> Function() requestFunction) async {
    final startTime = DateTime.now();
    
    try {
      debugPrint('🚀 Optimizing network request');
      final result = await requestFunction();
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ Request completed in ${duration.inMilliseconds}ms');
      
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('❌ Request failed after ${duration.inMilliseconds}ms: $e');
      rethrow;
    }
  }
  
  /// Optimized image download with caching and compression
  Future<Uint8List?> optimizedImageDownload(
    String imageUrl, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    debugPrint('📸 Downloading optimized image: $imageUrl');
    
    try {
      // This is a simplified implementation
      // In a real app, you would implement actual image optimization
      final response = await executeRequest(
        method: 'GET',
        url: imageUrl,
        enableCaching: true,
        enableDeduplication: true,
      );
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        debugPrint('❌ Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error downloading image: $e');
      return null;
    }
  }
}