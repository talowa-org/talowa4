import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for optimizing Firestore queries and database operations
class QueryOptimizationService {
  static QueryOptimizationService? _instance;
  static QueryOptimizationService get instance => _instance ??= QueryOptimizationService._();

  QueryOptimizationService._();

  final Map<String, QuerySnapshot> _queryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _defaultCacheDuration = Duration(minutes: 5);

  /// Initialize the query optimization service
  Future<void> initialize() async {
    try {
      debugPrint('✅ QueryOptimizationService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize QueryOptimizationService: $e');
    }
  }

  /// Execute an optimized query with caching
  Future<QuerySnapshot> executeOptimizedQuery(
    Query query, {
    String? cacheKey,
    Duration? cacheDuration,
    bool useCache = true,
  }) async {
    try {
      final key = cacheKey ?? _generateCacheKey(query);
      final duration = cacheDuration ?? _defaultCacheDuration;

      // Check cache first
      if (useCache && _isCacheValid(key, duration)) {
        debugPrint('🎯 Query cache hit for: $key');
        return _queryCache[key]!;
      }

      // Execute query
      debugPrint('🔍 Executing query: $key');
      final result = await query.get();

      // Cache result
      if (useCache) {
        _queryCache[key] = result;
        _cacheTimestamps[key] = DateTime.now();
        _manageCacheSize();
      }

      return result;
    } catch (e) {
      debugPrint('❌ Query execution failed: $e');
      rethrow;
    }
  }

  /// Execute a paginated query with optimization
  Future<QuerySnapshot> executePaginatedQuery(
    Query query, {
    DocumentSnapshot? startAfter,
    int limit = 20,
    String? cacheKey,
  }) async {
    try {
      Query paginatedQuery = query.limit(limit);
      
      if (startAfter != null) {
        paginatedQuery = paginatedQuery.startAfterDocument(startAfter);
      }

      return await executeOptimizedQuery(
        paginatedQuery,
        cacheKey: cacheKey != null ? '${cacheKey}_page_${startAfter?.id ?? 'first'}' : null,
      );
    } catch (e) {
      debugPrint('❌ Paginated query failed: $e');
      rethrow;
    }
  }

  /// Batch multiple queries for better performance
  Future<List<QuerySnapshot>> executeBatchQueries(
    List<Query> queries, {
    List<String>? cacheKeys,
    bool useCache = true,
  }) async {
    try {
      final futures = <Future<QuerySnapshot>>[];
      
      for (int i = 0; i < queries.length; i++) {
        final query = queries[i];
        final cacheKey = cacheKeys != null && i < cacheKeys.length ? cacheKeys[i] : null;
        
        futures.add(executeOptimizedQuery(
          query,
          cacheKey: cacheKey,
          useCache: useCache,
        ));
      }

      return await Future.wait(futures);
    } catch (e) {
      debugPrint('❌ Batch queries failed: $e');
      rethrow;
    }
  }

  /// Clear query cache
  void clearCache([String? specificKey]) {
    if (specificKey != null) {
      _queryCache.remove(specificKey);
      _cacheTimestamps.remove(specificKey);
      debugPrint('🗑️ Cleared cache for: $specificKey');
    } else {
      _queryCache.clear();
      _cacheTimestamps.clear();
      debugPrint('🗑️ Cleared all query cache');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _queryCache.length,
      'cachedQueries': _queryCache.keys.toList(),
      'oldestCacheEntry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
      'newestCacheEntry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    };
  }

  /// Generate cache key from query
  String _generateCacheKey(Query query) {
    // This is a simplified cache key generation
    // In a real implementation, you'd want to include query parameters
    return 'query_${query.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Check if cache entry is valid
  bool _isCacheValid(String key, Duration maxAge) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null || !_queryCache.containsKey(key)) {
      return false;
    }
    
    return DateTime.now().difference(timestamp) <= maxAge;
  }

  /// Manage cache size to prevent memory issues
  void _manageCacheSize() {
    const maxCacheSize = 50;
    
    if (_queryCache.length > maxCacheSize) {
      // Remove oldest entries
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final entriesToRemove = sortedEntries.take(_queryCache.length - maxCacheSize);
      
      for (final entry in entriesToRemove) {
        _queryCache.remove(entry.key);
        _cacheTimestamps.remove(entry.key);
      }
      
      debugPrint('🗑️ Cleaned up ${entriesToRemove.length} old cache entries');
    }
  }

  /// Create optimized compound query
  Query createCompoundQuery(
    CollectionReference collection,
    List<QueryFilter> filters, {
    List<QueryOrder>? orderBy,
    int? limit,
  }) {
    Query query = collection;

    // Apply filters
    for (final filter in filters) {
      query = query.where(filter.field, isEqualTo: filter.value);
    }

    // Apply ordering
    if (orderBy != null) {
      for (final order in orderBy) {
        query = query.orderBy(order.field, descending: order.descending);
      }
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    return query;
  }
}

/// Query filter helper class
class QueryFilter {
  final String field;
  final dynamic value;
  final String operator;

  const QueryFilter({
    required this.field,
    required this.value,
    this.operator = '==',
  });
}

/// Query order helper class
class QueryOrder {
  final String field;
  final bool descending;

  const QueryOrder({
    required this.field,
    this.descending = false,
  });
}