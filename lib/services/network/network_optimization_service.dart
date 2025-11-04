import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Network optimization service for improved performance and scalability
class NetworkOptimizationService {
  static NetworkOptimizationService? _instance;
  static NetworkOptimizationService get instance => _instance ??= NetworkOptimizationService._();
  
  NetworkOptimizationService._();
  
  late http.Client _httpClient;
  final Map<String, http.Client> _connectionPools = {};
  
  /// Initialize the network optimization service
  void initialize() {
    // Create optimized HTTP client with connection pooling
    _httpClient = http.Client();
    
    debugPrint('✅ NetworkOptimizationService initialized');
  }
  
  /// Get or create a connection pool for a specific host
  http.Client _getConnectionPool(String host) {
    if (!_connectionPools.containsKey(host)) {
      _connectionPools[host] = http.Client();
      debugPrint('🔗 Created connection pool for host: $host');
    }
    return _connectionPools[host]!;
  }
  
  /// Make an optimized GET request with compression and caching
  Future<http.Response?> optimizedGet(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
    bool enableCompression = true,
    bool enableKeepAlive = true,
  }) async {
    try {
      final uri = Uri.parse(url);
      final client = enableKeepAlive ? _getConnectionPool(uri.host) : _httpClient;
      
      // Prepare optimized headers
      final optimizedHeaders = <String, String>{
        'User-Agent': 'Talowa-Mobile/1.0',
        'Connection': enableKeepAlive ? 'keep-alive' : 'close',
        if (enableCompression) 'Accept-Encoding': 'gzip, deflate, br',
        'Accept': 'application/json, text/plain, */*',
        'Cache-Control': 'max-age=300', // 5 minutes cache
        ...?headers,
      };
      
      debugPrint('🌐 Making optimized GET request to: $url');
      
      final response = await client.get(uri, headers: optimizedHeaders).timeout(timeout);
      
      debugPrint('✅ GET response: ${response.statusCode} (${response.body.length} bytes)');
      return response;
      
    } catch (e) {
      debugPrint('❌ Optimized GET request failed for $url: $e');
      return null;
    }
  }
  
  /// Make an optimized POST request with compression
  Future<http.Response?> optimizedPost(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration timeout = const Duration(seconds: 30),
    bool enableCompression = true,
    bool enableKeepAlive = true,
  }) async {
    try {
      final uri = Uri.parse(url);
      final client = enableKeepAlive ? _getConnectionPool(uri.host) : _httpClient;
      
      // Prepare optimized headers
      final optimizedHeaders = <String, String>{
        'User-Agent': 'Talowa-Mobile/1.0',
        'Connection': enableKeepAlive ? 'keep-alive' : 'close',
        'Content-Type': 'application/json; charset=utf-8',
        if (enableCompression) 'Accept-Encoding': 'gzip, deflate, br',
        'Accept': 'application/json, text/plain, */*',
        ...?headers,
      };
      
      // Compress body if it's large
      String requestBody;
      if (body is Map || body is List) {
        requestBody = jsonEncode(body);
      } else {
        requestBody = body?.toString() ?? '';
      }
      
      // Apply compression for large payloads
      if (enableCompression && requestBody.length > 1024) {
        optimizedHeaders['Content-Encoding'] = 'gzip';
        final compressedBody = gzip.encode(utf8.encode(requestBody));
        debugPrint('📦 Compressed payload: ${requestBody.length} → ${compressedBody.length} bytes');
        
        final response = await client.post(
          uri, 
          headers: optimizedHeaders,
          body: compressedBody,
        ).timeout(timeout);
        
        debugPrint('✅ POST response: ${response.statusCode} (${response.body.length} bytes)');
        return response;
      } else {
        final response = await client.post(
          uri, 
          headers: optimizedHeaders,
          body: requestBody,
        ).timeout(timeout);
        
        debugPrint('✅ POST response: ${response.statusCode} (${response.body.length} bytes)');
        return response;
      }
      
    } catch (e) {
      debugPrint('❌ Optimized POST request failed for $url: $e');
      return null;
    }
  }
  
  /// Batch multiple requests for better performance
  Future<List<http.Response?>> batchRequests(
    List<String> urls, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
    int maxConcurrency = 5,
  }) async {
    try {
      debugPrint('🚀 Starting batch requests for ${urls.length} URLs');
      
      final results = <http.Response?>[];
      
      // Process requests in batches to avoid overwhelming the server
      for (int i = 0; i < urls.length; i += maxConcurrency) {
        final batch = urls.skip(i).take(maxConcurrency);
        final batchFutures = batch.map((url) => optimizedGet(url, headers: headers, timeout: timeout));
        
        final batchResults = await Future.wait(batchFutures);
        results.addAll(batchResults);
        
        debugPrint('✅ Completed batch ${(i / maxConcurrency).floor() + 1}/${(urls.length / maxConcurrency).ceil()}');
      }
      
      debugPrint('🎯 Batch requests completed: ${results.where((r) => r != null).length}/${urls.length} successful');
      return results;
      
    } catch (e) {
      debugPrint('❌ Batch requests failed: $e');
      return List.filled(urls.length, null);
    }
  }
  
  /// Download and cache images with optimization
  Future<Uint8List?> optimizedImageDownload(
    String imageUrl, {
    Duration timeout = const Duration(seconds: 15),
    int? maxWidth,
    int? maxHeight,
    int quality = 85,
  }) async {
    try {
      debugPrint('🖼️ Downloading image: $imageUrl');
      
      final response = await optimizedGet(
        imageUrl,
        timeout: timeout,
        headers: {
          'Accept': 'image/webp,image/avif,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        },
      );
      
      if (response != null && response.statusCode == 200) {
        final imageData = response.bodyBytes;
        debugPrint('✅ Image downloaded: ${imageData.length} bytes');
        
        // TODO: Add image resizing/compression logic here if needed
        // This would require additional image processing libraries
        
        return imageData;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Image download failed for $imageUrl: $e');
      return null;
    }
  }
  
  /// Preload critical resources
  Future<void> preloadResources(List<String> urls) async {
    try {
      debugPrint('⚡ Preloading ${urls.length} critical resources');
      
      final futures = urls.map((url) => optimizedGet(url, headers: {
        'Priority': 'high',
        'Cache-Control': 'max-age=3600', // Cache for 1 hour
      }));
      
      await Future.wait(futures);
      debugPrint('✅ Preloading completed');
      
    } catch (e) {
      debugPrint('❌ Resource preloading failed: $e');
    }
  }
  
  /// Get network performance metrics
  Map<String, dynamic> getNetworkMetrics() {
    return {
      'connectionPools': _connectionPools.length,
      'activeConnections': _connectionPools.keys.toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Clean up connection pools
  void cleanup() {
    try {
      for (final client in _connectionPools.values) {
        client.close();
      }
      _connectionPools.clear();
      _httpClient.close();
      
      debugPrint('🧹 NetworkOptimizationService cleaned up');
    } catch (e) {
      debugPrint('❌ Cleanup failed: $e');
    }
  }
}

/// Request priority levels for optimization
enum RequestPriority {
  critical,
  high,
  normal,
  low,
}

/// Network request configuration
class NetworkRequestConfig {
  final Duration timeout;
  final bool enableCompression;
  final bool enableKeepAlive;
  final RequestPriority priority;
  final Map<String, String>? headers;
  final int retryCount;
  
  const NetworkRequestConfig({
    this.timeout = const Duration(seconds: 30),
    this.enableCompression = true,
    this.enableKeepAlive = true,
    this.priority = RequestPriority.normal,
    this.headers,
    this.retryCount = 3,
  });
  
  /// Create config for critical requests
  factory NetworkRequestConfig.critical() {
    return const NetworkRequestConfig(
      timeout: Duration(seconds: 10),
      priority: RequestPriority.critical,
      retryCount: 5,
    );
  }
  
  /// Create config for background requests
  factory NetworkRequestConfig.background() {
    return const NetworkRequestConfig(
      timeout: Duration(minutes: 2),
      priority: RequestPriority.low,
      retryCount: 1,
    );
  }
}