// Query Optimization Service for TALOWA
// Implements advanced query batching, caching, and optimization strategies

import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class QueryOptimizationService {
  static QueryOptimizationService? _instance;
  static QueryOptimizationService get instance => _instance ??= QueryOptimizationService._internal();
  
  QueryOptimizationService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Query batching configuration
  static const int maxBatchSize = 500;
  static const Duration batchDelay = Duration(milliseconds: 50);
  
  // Query cache configuration
  static const Duration defaultCacheDuration = Duration(minutes: 5);
  static const int maxCacheSize = 1000;
  
  // Query batching queues
  final Map<String, List<BatchedQuery>> _queryBatches = {};
  final Map<String, Timer> _batchTimers = {};
  
  // Query result cache
  final LinkedHashMap<String, CachedQueryResult> _queryCache = LinkedHashMap();
  
  // Performance metrics
  final Map<String, QueryMetrics> _queryMetrics = {};
  
  /// Batch multiple queries together for better performance
  Future<T> batchQuery<T>(
    String batchKey,
    Future<T> Function() queryFunction, {
    Duration? delay,
  }) async {
    final completer = Completer<T>();
    final batchedQuery = BatchedQuery<T>(queryFunction, completer);
    
    // Add to batch
    _queryBatches.putIfAbsent(batchKey, () => []).add(batchedQuery);
    
    // Set up batch timer if not already set
    if (!_batchTimers.containsKey(batchKey)) {
      _batchTimers[batchKey] = Timer(delay ?? batchDelay, () {
        _executeBatch(batchKey);
      });
    }
    
    return completer.future;
  }
  
  /// Execute a batch of queries
  Future<void> _executeBatch(String batchKey) async {
    final batch = _queryBatches.remove(batchKey);
    _batchTimers.remove(batchKey);
    
    if (batch == null || batch.isEmpty) return;
    
    debugPrint('🔄 Executing batch of ${batch.length} queries for key: $batchKey');
    
    // Execute all queries in parallel
    final futures = batch.map((batchedQuery) async {
      try {
        final result = await batchedQuery.queryFunction();
        batchedQuery.completer.complete(result);
      } catch (e) {
        batchedQuery.completer.completeError(e);
      }
    });
    
    await Future.wait(futures);
  }
  
  /// Get cached query result or execute query
  Future<T> getCachedQuery<T>(
    String cacheKey,
    Future<T> Function() queryFunction, {
    Duration? cacheDuration,
  }) async {
    // Check cache first
    final cached = _queryCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('📋 Cache hit for key: $cacheKey');
      _updateQueryMetrics(cacheKey, true);
      return cached.data as T;
    }
    
    // Execute query and cache result
    debugPrint('🔍 Cache miss, executing query for key: $cacheKey');
    final startTime = DateTime.now();
    
    try {
      final result = await queryFunction();
      final duration = cacheDuration ?? defaultCacheDuration;
      
      // Cache the result
      _cacheResult(cacheKey, result, duration);
      
      // Update metrics
      final executionTime = DateTime.now().difference(startTime);
      _updateQueryMetrics(cacheKey, false, executionTime);
      
      return result;
    } catch (e) {
      _updateQueryMetrics(cacheKey, false, DateTime.now().difference(startTime), e);
      rethrow;
    }
  }
  
  /// Cache query result
  void _cacheResult<T>(String key, T data, Duration duration) {
    // Remove oldest entries if cache is full
    while (_queryCache.length >= maxCacheSize) {
      _queryCache.remove(_queryCache.keys.first);
    }
    
    _queryCache[key] = CachedQueryResult(
      data: data,
      expiresAt: DateTime.now().add(duration),
    );
  }
  
  /// Update query performance metrics
  void _updateQueryMetrics(String key, bool cacheHit, [Duration? executionTime, dynamic error]) {
    final metrics = _queryMetrics.putIfAbsent(key, () => QueryMetrics(key));
    
    metrics.totalQueries++;
    if (cacheHit) {
      metrics.cacheHits++;
    } else {
      metrics.cacheMisses++;
      if (executionTime != null) {
        metrics.totalExecutionTime += executionTime.inMilliseconds;
        metrics.averageExecutionTime = metrics.totalExecutionTime / metrics.cacheMisses;
      }
    }
    
    if (error != null) {
      metrics.errors++;
      metrics.lastError = error.toString();
    }
    
    metrics.lastAccessed = DateTime.now();
  }
  
  /// Optimize Firestore query with proper indexing hints
  Query optimizeQuery(Query query, {
    required String operation,
    Map<String, dynamic>? hints,
  }) {
    debugPrint('🔧 Optimizing query for operation: $operation');
    
    // Apply query optimizations based on operation type
    switch (operation) {
      case 'feed_posts':
        // Ensure proper ordering for feed queries
        return query.orderBy('createdAt', descending: true);
      
      case 'user_posts':
        // Optimize for user-specific queries
        return query.orderBy('createdAt', descending: true);
      
      case 'search_posts':
        // Optimize for search queries
        if (hints?['category'] != null) {
          query = query.where('category', isEqualTo: hints!['category']);
        }
        return query.orderBy('createdAt', descending: true);
      
      default:
        return query;
    }
  }
  
  /// Execute optimized paginated query
  Future<QuerySnapshot> executePaginatedQuery(
    Query query, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? cacheKey,
  }) async {
    // Apply pagination
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    query = query.limit(limit);
    
    // Use caching if cache key provided
    if (cacheKey != null) {
      return await getCachedQuery(
        cacheKey,
        () => query.get(),
        cacheDuration: const Duration(minutes: 2), // Shorter cache for paginated queries
      );
    }
    
    return await query.get();
  }
  
  /// Batch multiple document reads
  Future<List<DocumentSnapshot>> batchGetDocuments(List<DocumentReference> refs) async {
    if (refs.isEmpty) return [];
    
    // Split into batches of 10 (Firestore limit)
    const batchSize = 10;
    final batches = <List<DocumentReference>>[];
    
    for (int i = 0; i < refs.length; i += batchSize) {
      final end = (i + batchSize < refs.length) ? i + batchSize : refs.length;
      batches.add(refs.sublist(i, end));
    }
    
    // Execute batches in parallel
    final futures = batches.map((batch) async {
      final snapshots = await Future.wait(batch.map((ref) => ref.get()));
      return snapshots;
    });
    
    final results = await Future.wait(futures);
    return results.expand((batch) => batch).toList();
  }
  
  /// Clear query cache
  void clearCache([String? pattern]) {
    if (pattern != null) {
      _queryCache.removeWhere((key, value) => key.contains(pattern));
      debugPrint('🧹 Cleared cache entries matching pattern: $pattern');
    } else {
      _queryCache.clear();
      debugPrint('🧹 Cleared entire query cache');
    }
  }
  
  /// Get query performance metrics
  Map<String, QueryMetrics> getMetrics() => Map.from(_queryMetrics);
  
  /// Clear performance metrics
  void clearMetrics() {
    _queryMetrics.clear();
    debugPrint('🧹 Cleared query performance metrics');
  }
  
  /// Dispose service and cleanup resources
  void dispose() {
    // Cancel all pending batch timers
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();
    
    // Complete any pending queries with error
    for (final batch in _queryBatches.values) {
      for (final query in batch) {
        if (!query.completer.isCompleted) {
          query.completer.completeError('Service disposed');
        }
      }
    }
    _queryBatches.clear();
    
    // Clear caches
    _queryCache.clear();
    _queryMetrics.clear();
    
    debugPrint('🧹 QueryOptimizationService disposed');
  }
}

/// Batched query container
class BatchedQuery<T> {
  final Future<T> Function() queryFunction;
  final Completer<T> completer;
  
  BatchedQuery(this.queryFunction, this.completer);
}

/// Cached query result
class CachedQueryResult {
  final dynamic data;
  final DateTime expiresAt;
  
  CachedQueryResult({
    required this.data,
    required this.expiresAt,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Query performance metrics
class QueryMetrics {
  final String key;
  int totalQueries = 0;
  int cacheHits = 0;
  int cacheMisses = 0;
  int errors = 0;
  double totalExecutionTime = 0;
  double averageExecutionTime = 0;
  String? lastError;
  DateTime? lastAccessed;
  
  QueryMetrics(this.key);
  
  double get cacheHitRate => totalQueries > 0 ? cacheHits / totalQueries : 0;
  double get errorRate => totalQueries > 0 ? errors / totalQueries : 0;
  
  Map<String, dynamic> toMap() => {
    'key': key,
    'totalQueries': totalQueries,
    'cacheHits': cacheHits,
    'cacheMisses': cacheMisses,
    'cacheHitRate': cacheHitRate,
    'errors': errors,
    'errorRate': errorRate,
    'averageExecutionTime': averageExecutionTime,
    'lastError': lastError,
    'lastAccessed': lastAccessed?.toIso8601String(),
  };
}