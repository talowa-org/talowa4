// API Gateway - Microservices Request Routing and Management
// Handles rate limiting, authentication, validation, and caching
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Authentication levels
enum AuthenticationLevel {
  none,
  optional,
  required,
}

/// Rate limiting configuration
class RateLimit {
  final int requests;
  final Duration window;

  const RateLimit({
    required this.requests,
    required this.window,
  });
}

/// Cache policy configuration
class CachePolicy {
  final Duration duration;
  final bool varyByUser;
  final List<String> varyByHeaders;

  const CachePolicy({
    required this.duration,
    this.varyByUser = false,
    this.varyByHeaders = const [],
  });
}

/// Request validation schema
abstract class ValidationSchema {
  Map<String, String>? validate(Map<String, dynamic> data);
}

/// Post validation schema
class PostValidationSchema extends ValidationSchema {
  @override
  Map<String, String>? validate(Map<String, dynamic> data) {
    final errors = <String, String>{};

    // Validate content
    final content = data['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      errors['content'] = 'Content is required';
    } else if (content.length > 5000) {
      errors['content'] = 'Content cannot exceed 5000 characters';
    }

    // Validate title
    final title = data['title'] as String?;
    if (title != null && title.length > 200) {
      errors['title'] = 'Title cannot exceed 200 characters';
    }

    // Validate category
    final category = data['category'] as String?;
    if (category == null || category.trim().isEmpty) {
      errors['category'] = 'Category is required';
    }

    return errors.isEmpty ? null : errors;
  }
}

/// API endpoint configuration
class ApiEndpoint {
  final String path;
  final String method;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) handler;
  final RateLimit? rateLimit;
  final AuthenticationLevel authentication;
  final CachePolicy? caching;
  final ValidationSchema? validation;
  final Duration? timeout;

  ApiEndpoint({
    required this.path,
    required this.method,
    required this.handler,
    this.rateLimit,
    this.authentication = AuthenticationLevel.none,
    this.caching,
    this.validation,
    this.timeout,
  });
}

/// Rate limiting tracker
class RateLimitTracker {
  final Map<String, List<DateTime>> _requests = {};

  bool isAllowed(String key, RateLimit rateLimit) {
    final now = DateTime.now();
    final windowStart = now.subtract(rateLimit.window);

    // Clean old requests
    _requests[key]?.removeWhere((time) => time.isBefore(windowStart));

    final requestCount = _requests[key]?.length ?? 0;
    if (requestCount >= rateLimit.requests) {
      return false;
    }

    // Add current request
    _requests[key] ??= [];
    _requests[key]!.add(now);

    return true;
  }

  void cleanup() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 1));

    _requests.removeWhere((key, requests) {
      requests.removeWhere((time) => time.isBefore(cutoff));
      return requests.isEmpty;
    });
  }
}

/// API Gateway for microservices
class ApiGateway {
  static ApiGateway? _instance;
  static ApiGateway get instance => _instance ??= ApiGateway._internal();
  
  ApiGateway._internal();

  // Registered endpoints
  final Map<String, ApiEndpoint> _endpoints = {};
  final RateLimitTracker _rateLimitTracker = RateLimitTracker();
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheExpiry = {};

  // Cleanup timer
  Timer? _cleanupTimer;

  /// Initialize API Gateway
  Future<void> initialize() async {
    // Start cleanup timer
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _cleanup();
    });

    debugPrint('✅ API Gateway initialized');
  }

  /// Register API endpoints
  Future<void> registerEndpoints(Map<String, ApiEndpoint> endpoints) async {
    _endpoints.addAll(endpoints);
    
    for (final endpoint in endpoints.values) {
      debugPrint('📡 Registered endpoint: ${endpoint.method} ${endpoint.path}');
    }
  }

  /// Process API request
  Future<Map<String, dynamic>> processRequest({
    required String method,
    required String path,
    required Map<String, dynamic> data,
    String? userId,
    Map<String, String>? headers,
  }) async {
    final endpointKey = '$method $path';
    final endpoint = _endpoints[endpointKey];

    if (endpoint == null) {
      throw Exception('Endpoint not found: $endpointKey');
    }

    try {
      // Check rate limiting
      if (endpoint.rateLimit != null) {
        final rateLimitKey = userId ?? 'anonymous';
        if (!_rateLimitTracker.isAllowed(rateLimitKey, endpoint.rateLimit!)) {
          throw Exception('Rate limit exceeded');
        }
      }

      // Check authentication
      if (endpoint.authentication == AuthenticationLevel.required && userId == null) {
        throw Exception('Authentication required');
      }

      // Validate request data
      if (endpoint.validation != null) {
        final validationErrors = endpoint.validation!.validate(data);
        if (validationErrors != null) {
          throw Exception('Validation failed: ${jsonEncode(validationErrors)}');
        }
      }

      // Check cache
      if (endpoint.caching != null && method == 'GET') {
        final cacheKey = _generateCacheKey(path, data, userId, headers, endpoint.caching!);
        final cachedResponse = _getFromCache(cacheKey);
        if (cachedResponse != null) {
          debugPrint('📦 Cache hit for $endpointKey');
          return cachedResponse;
        }
      }

      // Execute request with timeout
      final timeout = endpoint.timeout ?? const Duration(seconds: 30);
      final response = await endpoint.handler(data).timeout(timeout);

      // Cache response if applicable
      if (endpoint.caching != null && method == 'GET') {
        final cacheKey = _generateCacheKey(path, data, userId, headers, endpoint.caching!);
        _setCache(cacheKey, response, endpoint.caching!.duration);
      }

      return response;

    } catch (error) {
      debugPrint('❌ API Gateway error for $endpointKey: $error');
      rethrow;
    }
  }

  /// Validate request against endpoint schema
  Future<void> validateRequest(String endpointKey, Map<String, dynamic> data) async {
    final endpoint = _endpoints[endpointKey];
    if (endpoint?.validation != null) {
      final validationErrors = endpoint!.validation!.validate(data);
      if (validationErrors != null) {
        throw Exception('Validation failed: ${jsonEncode(validationErrors)}');
      }
    }
  }

  /// Generate cache key
  String _generateCacheKey(
    String path,
    Map<String, dynamic> data,
    String? userId,
    Map<String, String>? headers,
    CachePolicy cachePolicy,
  ) {
    final keyParts = [path];

    // Add data to key
    if (data.isNotEmpty) {
      keyParts.add(jsonEncode(data));
    }

    // Add user ID if cache varies by user
    if (cachePolicy.varyByUser && userId != null) {
      keyParts.add('user:$userId');
    }

    // Add headers if cache varies by headers
    if (headers != null) {
      for (final headerName in cachePolicy.varyByHeaders) {
        final headerValue = headers[headerName];
        if (headerValue != null) {
          keyParts.add('$headerName:$headerValue');
        }
      }
    }

    return keyParts.join('|');
  }

  /// Get response from cache
  Map<String, dynamic>? _getFromCache(String key) {
    final expiry = _cacheExpiry[key];
    if (expiry == null || DateTime.now().isAfter(expiry)) {
      _cache.remove(key);
      _cacheExpiry.remove(key);
      return null;
    }

    return _cache[key] as Map<String, dynamic>?;
  }

  /// Set response in cache
  void _setCache(String key, Map<String, dynamic> response, Duration duration) {
    _cache[key] = response;
    _cacheExpiry[key] = DateTime.now().add(duration);
  }

  /// Cleanup expired cache entries and rate limit data
  void _cleanup() {
    final now = DateTime.now();

    // Clean expired cache entries
    final expiredKeys = <String>[];
    for (final entry in _cacheExpiry.entries) {
      if (now.isAfter(entry.value)) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheExpiry.remove(key);
    }

    // Clean rate limit tracker
    _rateLimitTracker.cleanup();

    if (expiredKeys.isNotEmpty) {
      debugPrint('🧹 Cleaned ${expiredKeys.length} expired cache entries');
    }
  }

  /// Get API Gateway statistics
  Map<String, dynamic> getStatistics() {
    return {
      'endpoints': _endpoints.length,
      'cacheEntries': _cache.length,
      'endpointList': _endpoints.keys.toList(),
      'lastCleanup': DateTime.now().toIso8601String(),
    };
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    _cacheExpiry.clear();
    debugPrint('🧹 API Gateway cache cleared');
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
    _cacheExpiry.clear();
    _endpoints.clear();
  }
}