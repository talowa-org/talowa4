// Database Optimization Service for TALOWA
// Implements connection pooling and query optimization
// Requirements: 1.1, 8.4

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../messaging/redis_cache_service.dart';

class DatabaseOptimizationService {
  static final DatabaseOptimizationService _instance = DatabaseOptimizationService._internal();
  factory DatabaseOptimizationService() => _instance;
  DatabaseOptimizationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RedisCacheService _cacheService = RedisCacheService();
  
  // Connection pool simulation (Firestore handles this internally)
  final Map<String, FirebaseFirestore> _connectionPool = {};
  final Map<String, DateTime> _connectionLastUsed = {};
  
  // Query optimization
  final Map<String, QueryResult> _queryCache = {};
  final Map<String, DateTime> _queryCacheTimestamps = {};
  final Map<String, QueryOptimizationStats> _queryStats = {};
  
  // Configuration
  static const int maxConnections = 10;
  static const Duration connectionTimeout = Duration(minutes: 5);
  static const Duration queryCacheExpiration = Duration(minutes: 10);
  static const int maxQueryCacheSize = 100;
  static const int batchSize = 500;

  /// Initialize database optimization service
  Future<void> initialize() async {
    try {
      await _cacheService.initialize();
      await _setupFirestoreSettings();
      _startConnectionPoolCleanup();
      debugPrint('DatabaseOptimizationService initialized');
    } catch (e) {
      debugPrint('Error initializing DatabaseOptimizationService: $e');
    }
  }

  /// Execute optimized query with caching and connection pooling
  Future<QueryResult<T>> executeOptimizedQuery<T>({
    required String queryKey,
    required Future<QuerySnapshot> Function() queryFunction,
    required T Function(DocumentSnapshot) documentMapper,
    Duration? cacheExpiration,
    bool useCache = true,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Check cache first
      if (useCache) {
        final cachedResult = _getCachedQuery<T>(queryKey);
        if (cachedResult != null) {
          _updateQueryStats(queryKey, stopwatch.elapsedMilliseconds, true);
          return cachedResult;
        }
      }
      
      // Execute query with connection pooling
      final connection = _getOptimizedConnection();
      final querySnapshot = await queryFunction();
      
      // Process results
      final documents = querySnapshot.docs.map(documentMapper).toList();
      
      final result = QueryResult<T>(
        data: documents,
        queryKey: queryKey,
        executionTime: stopwatch.elapsedMilliseconds,
        fromCache: false,
        documentCount: documents.length,
        timestamp: DateTime.now(),
      );
      
      // Cache the result
      if (useCache) {
        _cacheQuery(queryKey, result, cacheExpiration ?? queryCacheExpiration);
      }
      
      stopwatch.stop();
      _updateQueryStats(queryKey, stopwatch.elapsedMilliseconds, false);
      
      return result;
    } catch (e) {
      debugPrint('Error executing optimized query: $e');
      return QueryResult<T>(
        data: [],
        queryKey: queryKey,
        executionTime: 0,
        fromCache: false,
        documentCount: 0,
        timestamp: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Execute batch operations with optimization
  Future<BatchOperationResult> executeBatchOperation({
    required String operationKey,
    required List<BatchOperation> operations,
    int? customBatchSize,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final effectiveBatchSize = customBatchSize ?? batchSize;
      
      final results = <String, dynamic>{};
      final errors = <String>[];
      int processedCount = 0;
      
      // Process operations in batches
      for (int i = 0; i < operations.length; i += effectiveBatchSize) {
        final batch = operations.skip(i).take(effectiveBatchSize).toList();
        
        try {
          final batchResult = await _executeBatch(batch);
          results.addAll(batchResult);
          processedCount += batch.length;
          
          // Small delay to prevent overwhelming Firestore
          if (i + effectiveBatchSize < operations.length) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        } catch (e) {
          errors.add('Batch ${i ~/ effectiveBatchSize}: $e');
        }
      }
      
      stopwatch.stop();
      
      return BatchOperationResult(
        success: errors.isEmpty,
        operationKey: operationKey,
        processedCount: processedCount,
        totalCount: operations.length,
        executionTime: stopwatch.elapsedMilliseconds,
        results: results,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error executing batch operation: $e');
      return BatchOperationResult(
        success: false,
        operationKey: operationKey,
        processedCount: 0,
        totalCount: operations.length,
        executionTime: 0,
        results: {},
        errors: [e.toString()],
      );
    }
  }

  /// Execute paginated query with optimization
  Future<PaginatedQueryResult<T>> executePaginatedQuery<T>({
    required String queryKey,
    required Query Function() queryBuilder,
    required T Function(DocumentSnapshot) documentMapper,
    DocumentSnapshot? startAfter,
    int limit = 50,
    bool useCache = true,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Build cache key with pagination info
      final paginatedKey = '${queryKey}_${startAfter?.id ?? 'start'}_$limit';
      
      // Check cache
      if (useCache) {
        final cachedResult = _getCachedQuery<T>(paginatedKey);
        if (cachedResult != null) {
          return PaginatedQueryResult<T>(
            data: cachedResult.data,
            queryKey: paginatedKey,
            executionTime: stopwatch.elapsedMilliseconds,
            fromCache: true,
            documentCount: cachedResult.data.length,
            timestamp: DateTime.now(),
            hasMore: cachedResult.data.length == limit,
            lastDocument: null, // Would need to be stored in cache
          );
        }
      }
      
      // Build and execute query
      Query query = queryBuilder();
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      query = query.limit(limit + 1); // Get one extra to check if there are more
      
      final querySnapshot = await query.get();
      final docs = querySnapshot.docs;
      
      // Check if there are more documents
      final hasMore = docs.length > limit;
      final documentsToReturn = hasMore ? docs.take(limit).toList() : docs;
      
      // Map documents
      final data = documentsToReturn.map(documentMapper).toList();
      
      final result = PaginatedQueryResult<T>(
        data: data,
        queryKey: paginatedKey,
        executionTime: stopwatch.elapsedMilliseconds,
        fromCache: false,
        documentCount: data.length,
        timestamp: DateTime.now(),
        hasMore: hasMore,
        lastDocument: documentsToReturn.isNotEmpty ? documentsToReturn.last : null,
      );
      
      // Cache the result
      if (useCache) {
        final cacheResult = QueryResult<T>(
          data: data,
          queryKey: paginatedKey,
          executionTime: result.executionTime,
          fromCache: false,
          documentCount: data.length,
          timestamp: result.timestamp,
        );
        _cacheQuery(paginatedKey, cacheResult, queryCacheExpiration);
      }
      
      stopwatch.stop();
      _updateQueryStats(queryKey, stopwatch.elapsedMilliseconds, false);
      
      return result;
    } catch (e) {
      debugPrint('Error executing paginated query: $e');
      return PaginatedQueryResult<T>(
        data: [],
        queryKey: queryKey,
        executionTime: 0,
        fromCache: false,
        documentCount: 0,
        timestamp: DateTime.now(),
        hasMore: false,
        lastDocument: null,
        error: e.toString(),
      );
    }
  }

  /// Execute aggregation query with optimization
  Future<AggregationResult> executeAggregationQuery({
    required String queryKey,
    required Query query,
    required List<AggregationType> aggregations,
    bool useCache = true,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Check cache
      if (useCache) {
        final cachedResult = _getCachedAggregation(queryKey);
        if (cachedResult != null) {
          return cachedResult;
        }
      }
      
      // Execute aggregation query
      final aggregateQuery = query.count();
      final aggregateSnapshot = await aggregateQuery.get();
      
      final result = AggregationResult(
        queryKey: queryKey,
        count: aggregateSnapshot.count ?? 0,
        executionTime: stopwatch.elapsedMilliseconds,
        fromCache: false,
        timestamp: DateTime.now(),
      );
      
      // Cache the result
      if (useCache) {
        _cacheAggregation(queryKey, result);
      }
      
      stopwatch.stop();
      _updateQueryStats(queryKey, stopwatch.elapsedMilliseconds, false);
      
      return result;
    } catch (e) {
      debugPrint('Error executing aggregation query: $e');
      return AggregationResult(
        queryKey: queryKey,
        count: 0,
        executionTime: 0,
        fromCache: false,
        timestamp: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Get query optimization statistics
  Map<String, dynamic> getOptimizationStatistics() {
    final totalQueries = _queryStats.values.fold(0, (sum, stats) => sum + stats.executionCount);
    final totalCacheHits = _queryStats.values.fold(0, (sum, stats) => sum + stats.cacheHits);
    final averageExecutionTime = _queryStats.values.isNotEmpty
        ? _queryStats.values.fold(0.0, (sum, stats) => sum + stats.averageExecutionTime) / _queryStats.length
        : 0.0;
    
    return {
      'total_queries': totalQueries,
      'cache_hit_rate': totalQueries > 0 ? (totalCacheHits / totalQueries) : 0,
      'average_execution_time': averageExecutionTime,
      'cached_queries': _queryCache.length,
      'active_connections': _connectionPool.length,
      'query_stats': _queryStats.map((key, stats) => MapEntry(key, stats.toMap())),
    };
  }

  /// Clear query cache
  Future<void> clearQueryCache() async {
    try {
      _queryCache.clear();
      _queryCacheTimestamps.clear();
      debugPrint('Query cache cleared');
    } catch (e) {
      debugPrint('Error clearing query cache: $e');
    }
  }

  /// Invalidate specific query cache
  void invalidateQueryCache(String queryKey) {
    _queryCache.removeWhere((key, _) => key.startsWith(queryKey));
    _queryCacheTimestamps.removeWhere((key, _) => key.startsWith(queryKey));
  }

  // Private methods

  Future<void> _setupFirestoreSettings() async {
    try {
      // Configure Firestore settings for optimization
      const settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      _firestore.settings = settings;
      
      // Enable offline persistence
      await _firestore.enablePersistence();
      
      debugPrint('Firestore settings configured for optimization');
    } catch (e) {
      debugPrint('Error setting up Firestore settings: $e');
    }
  }

  FirebaseFirestore _getOptimizedConnection() {
    // For Firestore, we use the singleton instance
    // In a real database connection pool, this would return an available connection
    _connectionLastUsed['default'] = DateTime.now();
    return _firestore;
  }

  void _startConnectionPoolCleanup() {
    Timer.periodic(connectionTimeout, (timer) {
      _cleanupConnections();
    });
  }

  void _cleanupConnections() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _connectionLastUsed.entries) {
      if (now.difference(entry.value) > connectionTimeout) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _connectionPool.remove(key);
      _connectionLastUsed.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      debugPrint('Cleaned up ${keysToRemove.length} idle connections');
    }
  }

  QueryResult<T>? _getCachedQuery<T>(String queryKey) {
    final result = _queryCache[queryKey];
    final timestamp = _queryCacheTimestamps[queryKey];
    
    if (result != null && timestamp != null) {
      if (DateTime.now().difference(timestamp) < queryCacheExpiration) {
        return result as QueryResult<T>;
      } else {
        // Remove expired cache
        _queryCache.remove(queryKey);
        _queryCacheTimestamps.remove(queryKey);
      }
    }
    
    return null;
  }

  void _cacheQuery<T>(String queryKey, QueryResult<T> result, Duration expiration) {
    // Manage cache size
    if (_queryCache.length >= maxQueryCacheSize) {
      _evictOldestCacheEntry();
    }
    
    _queryCache[queryKey] = result;
    _queryCacheTimestamps[queryKey] = DateTime.now();
  }

  AggregationResult? _getCachedAggregation(String queryKey) {
    // Similar to _getCachedQuery but for aggregation results
    final result = _queryCache[queryKey];
    final timestamp = _queryCacheTimestamps[queryKey];
    
    if (result != null && timestamp != null) {
      if (DateTime.now().difference(timestamp) < queryCacheExpiration) {
        return result as AggregationResult;
      } else {
        _queryCache.remove(queryKey);
        _queryCacheTimestamps.remove(queryKey);
      }
    }
    
    return null;
  }

  void _cacheAggregation(String queryKey, AggregationResult result) {
    if (_queryCache.length >= maxQueryCacheSize) {
      _evictOldestCacheEntry();
    }
    
    // Store aggregation results separately or cast appropriately
    _queryCache[queryKey] = result as dynamic;
    _queryCacheTimestamps[queryKey] = DateTime.now();
  }

  void _evictOldestCacheEntry() {
    if (_queryCacheTimestamps.isEmpty) return;
    
    final oldestEntry = _queryCacheTimestamps.entries
        .reduce((a, b) => a.value.isBefore(b.value) ? a : b);
    
    _queryCache.remove(oldestEntry.key);
    _queryCacheTimestamps.remove(oldestEntry.key);
  }

  void _updateQueryStats(String queryKey, int executionTime, bool fromCache) {
    final stats = _queryStats[queryKey] ?? QueryOptimizationStats(queryKey: queryKey);
    
    stats.executionCount++;
    stats.totalExecutionTime += executionTime;
    stats.averageExecutionTime = stats.totalExecutionTime / stats.executionCount;
    
    if (fromCache) {
      stats.cacheHits++;
    }
    
    _queryStats[queryKey] = stats;
  }

  Future<Map<String, dynamic>> _executeBatch(List<BatchOperation> operations) async {
    final batch = _firestore.batch();
    final results = <String, dynamic>{};
    
    for (final operation in operations) {
      switch (operation.type) {
        case BatchOperationType.create:
          batch.set(operation.documentRef, operation.data!);
          break;
        case BatchOperationType.update:
          batch.update(operation.documentRef, operation.data!);
          break;
        case BatchOperationType.delete:
          batch.delete(operation.documentRef);
          break;
      }
    }
    
    await batch.commit();
    
    return results;
  }
}

/// Query result wrapper
class QueryResult<T> {
  final List<T> data;
  final String queryKey;
  final int executionTime;
  final bool fromCache;
  final int documentCount;
  final DateTime timestamp;
  final String? error;

  QueryResult({
    required this.data,
    required this.queryKey,
    required this.executionTime,
    required this.fromCache,
    required this.documentCount,
    required this.timestamp,
    this.error,
  });

  bool get hasError => error != null;
  bool get isEmpty => data.isEmpty;
}

/// Paginated query result
class PaginatedQueryResult<T> extends QueryResult<T> {
  final bool hasMore;
  final DocumentSnapshot? lastDocument;

  PaginatedQueryResult({
    required super.data,
    required super.queryKey,
    required super.executionTime,
    required super.fromCache,
    required super.documentCount,
    required super.timestamp,
    required this.hasMore,
    required this.lastDocument,
    super.error,
  });
}

/// Aggregation result
class AggregationResult {
  final String queryKey;
  final int count;
  final int executionTime;
  final bool fromCache;
  final DateTime timestamp;
  final String? error;

  AggregationResult({
    required this.queryKey,
    required this.count,
    required this.executionTime,
    required this.fromCache,
    required this.timestamp,
    this.error,
  });

  bool get hasError => error != null;
}

/// Batch operation
class BatchOperation {
  final BatchOperationType type;
  final DocumentReference documentRef;
  final Map<String, dynamic>? data;

  BatchOperation({
    required this.type,
    required this.documentRef,
    this.data,
  });
}

/// Batch operation types
enum BatchOperationType {
  create,
  update,
  delete,
}

/// Batch operation result
class BatchOperationResult {
  final bool success;
  final String operationKey;
  final int processedCount;
  final int totalCount;
  final int executionTime;
  final Map<String, dynamic> results;
  final List<String> errors;

  BatchOperationResult({
    required this.success,
    required this.operationKey,
    required this.processedCount,
    required this.totalCount,
    required this.executionTime,
    required this.results,
    required this.errors,
  });

  double get successRate => totalCount > 0 ? processedCount / totalCount : 0;
}

/// Query optimization statistics
class QueryOptimizationStats {
  final String queryKey;
  int executionCount = 0;
  int totalExecutionTime = 0;
  double averageExecutionTime = 0;
  int cacheHits = 0;

  QueryOptimizationStats({required this.queryKey});

  Map<String, dynamic> toMap() {
    return {
      'queryKey': queryKey,
      'executionCount': executionCount,
      'totalExecutionTime': totalExecutionTime,
      'averageExecutionTime': averageExecutionTime,
      'cacheHits': cacheHits,
      'cacheHitRate': executionCount > 0 ? cacheHits / executionCount : 0,
    };
  }
}

/// Aggregation types
enum AggregationType {
  count,
  sum,
  average,
}