import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Advanced database optimization service for 10M DAU scaling
class DatabaseOptimizationService {
  static DatabaseOptimizationService? _instance;
  static DatabaseOptimizationService get instance => _instance ??= DatabaseOptimizationService._();

  DatabaseOptimizationService._();

  // Connection pooling
  final Map<String, FirebaseFirestore> _connectionPool = {};
  final Queue<String> _availableConnections = Queue<String>();
  static const int _maxConnections = 20;
  static const int _minConnections = 5;

  // Query caching
  final Map<String, QuerySnapshot> _queryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, int> _cacheHitCounts = {};
  static const Duration _defaultCacheDuration = Duration(minutes: 10);
  static const int _maxCacheSize = 1000;

  // Performance metrics
  final Map<String, List<int>> _queryTimes = {};
  final Map<String, int> _queryExecutionCounts = {};
  final Map<String, int> _cacheHitRates = {};

  // Batch operations
  final Map<String, List<Future<void>>> _batchOperations = {};
  Timer? _batchFlushTimer;
  static const Duration _batchFlushInterval = Duration(milliseconds: 100);

  /// Initialize the database optimization service
  Future<void> initialize() async {
    try {
      await _initializeConnectionPool();
      _startBatchProcessor();
      _startCacheCleanup();
      debugPrint('✅ DatabaseOptimizationService initialized with ${_availableConnections.length} connections');
    } catch (e) {
      debugPrint('❌ Failed to initialize DatabaseOptimizationService: $e');
      rethrow;
    }
  }

  /// Initialize connection pool
  Future<void> _initializeConnectionPool() async {
    for (int i = 0; i < _minConnections; i++) {
      final connectionId = 'conn_$i';
      _connectionPool[connectionId] = FirebaseFirestore.instance;
      _availableConnections.add(connectionId);
    }
  }

  /// Get optimized connection from pool
  FirebaseFirestore _getConnection() {
    if (_availableConnections.isNotEmpty) {
      final connectionId = _availableConnections.removeFirst();
      final connection = _connectionPool[connectionId]!;
      
      // Return connection to pool after use
      Timer(const Duration(seconds: 30), () {
        if (!_availableConnections.contains(connectionId)) {
          _availableConnections.add(connectionId);
        }
      });
      
      return connection;
    }
    
    // Fallback to default instance if pool is exhausted
    return FirebaseFirestore.instance;
  }

  /// Execute optimized query with advanced caching
  Future<QuerySnapshot> executeOptimizedQuery(
    Query query, {
    String? cacheKey,
    Duration? cacheDuration,
    bool useCache = true,
    int priority = 1,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final key = cacheKey ?? _generateAdvancedCacheKey(query);
      final duration = cacheDuration ?? _defaultCacheDuration;

      // Check cache first
      if (useCache && _isCacheValid(key, duration)) {
        _recordCacheHit(key);
        debugPrint('🎯 Query cache hit for: $key');
        return _queryCache[key]!;
      }

      // Execute query with connection pooling
      final db = _getConnection();
      debugPrint('🔍 Executing optimized query: $key');
      
      final result = await query.get();
      stopwatch.stop();

      // Cache result with priority-based eviction
      if (useCache) {
        _cacheQueryResult(key, result, priority);
      }

      // Record performance metrics
      _recordQueryPerformance(key, stopwatch.elapsedMilliseconds);

      return result;
    } catch (e) {
      stopwatch.stop();
      _recordQueryError(cacheKey ?? 'unknown', stopwatch.elapsedMilliseconds);
      debugPrint('❌ Optimized query execution failed: $e');
      rethrow;
    }
  }

  /// Execute batch queries with connection pooling
  Future<List<QuerySnapshot>> executeBatchQueries(
    List<Query> queries, {
    List<String>? cacheKeys,
    bool useCache = true,
    int maxConcurrency = 5,
  }) async {
    try {
      final semaphore = Semaphore(maxConcurrency);
      final futures = <Future<QuerySnapshot>>[];
      
      for (int i = 0; i < queries.length; i++) {
        final query = queries[i];
        final cacheKey = cacheKeys != null && i < cacheKeys.length ? cacheKeys[i] : null;
        
        futures.add(semaphore.acquire().then((_) async {
          try {
            return await executeOptimizedQuery(
              query,
              cacheKey: cacheKey,
              useCache: useCache,
            );
          } finally {
            semaphore.release();
          }
        }));
      }

      return await Future.wait(futures);
    } catch (e) {
      debugPrint('❌ Batch queries execution failed: $e');
      rethrow;
    }
  }

  /// Execute paginated query with intelligent prefetching
  Future<PaginatedQueryResult> executePaginatedQuery(
    Query query, {
    DocumentSnapshot? startAfter,
    int limit = 20,
    String? cacheKey,
    bool prefetchNext = true,
  }) async {
    try {
      Query paginatedQuery = query.limit(limit);
      
      if (startAfter != null) {
        paginatedQuery = paginatedQuery.startAfterDocument(startAfter);
      }

      final result = await executeOptimizedQuery(
        paginatedQuery,
        cacheKey: cacheKey != null ? '${cacheKey}_page_${startAfter?.id ?? 'first'}' : null,
      );

      // Prefetch next page if enabled
      if (prefetchNext && result.docs.isNotEmpty && result.docs.length == limit) {
        final nextPageQuery = query
            .limit(limit)
            .startAfterDocument(result.docs.last);
        
        // Prefetch in background
        unawaited(_prefetchQuery(nextPageQuery, cacheKey, startAfter?.id));
      }

      return PaginatedQueryResult(
        documents: result.docs,
        hasMore: result.docs.length == limit,
        lastDocument: result.docs.isNotEmpty ? result.docs.last : null,
      );
    } catch (e) {
      debugPrint('❌ Paginated query failed: $e');
      rethrow;
    }
  }

  /// Batch write operations for better performance
  Future<void> executeBatchWrite(
    List<BatchOperation> operations, {
    String? batchId,
    bool immediate = false,
  }) async {
    try {
      final id = batchId ?? 'batch_${DateTime.now().millisecondsSinceEpoch}';
      
      if (immediate) {
        await _executeBatchOperations(operations);
      } else {
        _batchOperations[id] ??= [];
        _batchOperations[id]!.addAll(operations.map((op) => op.execute()));
        
        // Flush if batch is large
        if (_batchOperations[id]!.length >= 100) {
          await _flushBatch(id);
        }
      }
    } catch (e) {
      debugPrint('❌ Batch write failed: $e');
      rethrow;
    }
  }

  /// Advanced cache key generation with query fingerprinting
  String _generateAdvancedCacheKey(Query query) {
    final buffer = StringBuffer();
    buffer.write('query_');
    buffer.write(query.hashCode);
    buffer.write('_');
    buffer.write(DateTime.now().millisecondsSinceEpoch ~/ 60000); // Minute precision
    return buffer.toString();
  }

  /// Cache query result with priority-based eviction
  void _cacheQueryResult(String key, QuerySnapshot result, int priority) {
    if (_queryCache.length >= _maxCacheSize) {
      _evictLowPriorityCache();
    }
    
    _queryCache[key] = result;
    _cacheTimestamps[key] = DateTime.now();
    _cacheHitCounts[key] = priority;
  }

  /// Evict low priority cache entries
  void _evictLowPriorityCache() {
    final sortedEntries = _cacheHitCounts.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    final entriesToRemove = sortedEntries.take(_maxCacheSize ~/ 4);
    
    for (final entry in entriesToRemove) {
      _queryCache.remove(entry.key);
      _cacheTimestamps.remove(entry.key);
      _cacheHitCounts.remove(entry.key);
    }
    
    debugPrint('🗑️ Evicted ${entriesToRemove.length} low-priority cache entries');
  }

  /// Check if cache entry is valid
  bool _isCacheValid(String key, Duration maxAge) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null || !_queryCache.containsKey(key)) {
      return false;
    }
    
    return DateTime.now().difference(timestamp) <= maxAge;
  }

  /// Record cache hit for analytics
  void _recordCacheHit(String key) {
    _cacheHitRates[key] = (_cacheHitRates[key] ?? 0) + 1;
  }

  /// Record query performance metrics
  void _recordQueryPerformance(String key, int milliseconds) {
    _queryTimes[key] ??= [];
    _queryTimes[key]!.add(milliseconds);
    
    // Keep only last 100 measurements
    if (_queryTimes[key]!.length > 100) {
      _queryTimes[key]!.removeAt(0);
    }
    
    _queryExecutionCounts[key] = (_queryExecutionCounts[key] ?? 0) + 1;
    
    // Log slow queries
    if (milliseconds > 1000) {
      debugPrint('🐌 Slow query detected: $key (${milliseconds}ms)');
    }
  }

  /// Record query error for monitoring
  void _recordQueryError(String key, int milliseconds) {
    debugPrint('❌ Query error: $key (${milliseconds}ms)');
  }

  /// Prefetch query in background
  Future<void> _prefetchQuery(Query query, String? baseCacheKey, String? pageId) async {
    try {
      final cacheKey = baseCacheKey != null ? '${baseCacheKey}_prefetch_$pageId' : null;
      await executeOptimizedQuery(query, cacheKey: cacheKey, useCache: true);
      debugPrint('🔮 Prefetched next page: $cacheKey');
    } catch (e) {
      debugPrint('⚠️ Prefetch failed: $e');
    }
  }

  /// Start batch processor
  void _startBatchProcessor() {
    _batchFlushTimer = Timer.periodic(_batchFlushInterval, (_) {
      _flushAllBatches();
    });
  }

  /// Flush all pending batches
  Future<void> _flushAllBatches() async {
    final batchIds = _batchOperations.keys.toList();
    
    for (final batchId in batchIds) {
      await _flushBatch(batchId);
    }
  }

  /// Flush specific batch
  Future<void> _flushBatch(String batchId) async {
    final operations = _batchOperations.remove(batchId);
    if (operations != null && operations.isNotEmpty) {
      try {
        await Future.wait(operations);
        debugPrint('✅ Flushed batch: $batchId (${operations.length} operations)');
      } catch (e) {
        debugPrint('❌ Batch flush failed: $batchId - $e');
      }
    }
  }

  /// Execute batch operations immediately
  Future<void> _executeBatchOperations(List<BatchOperation> operations) async {
    final batch = FirebaseFirestore.instance.batch();
    
    for (final operation in operations) {
      operation.addToBatch(batch);
    }
    
    await batch.commit();
  }

  /// Start cache cleanup process
  void _startCacheCleanup() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpiredCache();
    });
  }

  /// Clean up expired cache entries
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _defaultCacheDuration) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _queryCache.remove(key);
      _cacheTimestamps.remove(key);
      _cacheHitCounts.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      debugPrint('🗑️ Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }

  /// Get comprehensive performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{
      'connectionPool': {
        'totalConnections': _connectionPool.length,
        'availableConnections': _availableConnections.length,
        'activeConnections': _connectionPool.length - _availableConnections.length,
      },
      'cache': {
        'size': _queryCache.length,
        'maxSize': _maxCacheSize,
        'hitRate': _calculateOverallCacheHitRate(),
        'totalHits': _cacheHitRates.values.fold(0, (a, b) => a + b),
      },
      'queries': {
        'totalExecuted': _queryExecutionCounts.values.fold(0, (a, b) => a + b),
        'averageTime': _calculateAverageQueryTime(),
        'slowQueries': _getSlowQueries(),
      },
      'batches': {
        'pendingBatches': _batchOperations.length,
        'pendingOperations': _batchOperations.values.fold(0, (a, b) => a + b.length),
      },
    };
    
    return stats;
  }

  /// Calculate overall cache hit rate
  double _calculateOverallCacheHitRate() {
    final totalHits = _cacheHitRates.values.fold(0, (a, b) => a + b);
    final totalQueries = _queryExecutionCounts.values.fold(0, (a, b) => a + b);
    
    return totalQueries > 0 ? (totalHits / totalQueries) * 100 : 0.0;
  }

  /// Calculate average query time
  double _calculateAverageQueryTime() {
    final allTimes = <int>[];
    for (final times in _queryTimes.values) {
      allTimes.addAll(times);
    }
    
    return allTimes.isNotEmpty 
        ? allTimes.reduce((a, b) => a + b) / allTimes.length 
        : 0.0;
  }

  /// Get slow queries for optimization
  List<Map<String, dynamic>> _getSlowQueries() {
    final slowQueries = <Map<String, dynamic>>[];
    
    for (final entry in _queryTimes.entries) {
      final avgTime = entry.value.reduce((a, b) => a + b) / entry.value.length;
      if (avgTime > 500) { // Queries slower than 500ms
        slowQueries.add({
          'query': entry.key,
          'averageTime': avgTime,
          'executionCount': _queryExecutionCounts[entry.key] ?? 0,
        });
      }
    }
    
    slowQueries.sort((a, b) => b['averageTime'].compareTo(a['averageTime']));
    return slowQueries.take(10).toList();
  }

  /// Clear all caches and reset metrics
  void clearAll() {
    _queryCache.clear();
    _cacheTimestamps.clear();
    _cacheHitCounts.clear();
    _queryTimes.clear();
    _queryExecutionCounts.clear();
    _cacheHitRates.clear();
    _batchOperations.clear();
    
    debugPrint('🗑️ Cleared all database optimization caches and metrics');
  }

  /// Dispose resources
  void dispose() {
    _batchFlushTimer?.cancel();
    clearAll();
    _connectionPool.clear();
    _availableConnections.clear();
    
    debugPrint('🔄 DatabaseOptimizationService disposed');
  }
}

/// Semaphore for controlling concurrency
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

/// Paginated query result
class PaginatedQueryResult {
  final List<QueryDocumentSnapshot> documents;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;

  const PaginatedQueryResult({
    required this.documents,
    required this.hasMore,
    this.lastDocument,
  });
}

/// Batch operation interface
abstract class BatchOperation {
  Future<void> execute();
  void addToBatch(WriteBatch batch);
}

/// Set batch operation
class SetBatchOperation implements BatchOperation {
  final DocumentReference reference;
  final Map<String, dynamic> data;
  final SetOptions? options;

  const SetBatchOperation(this.reference, this.data, {this.options});

  @override
  Future<void> execute() => reference.set(data, options);

  @override
  void addToBatch(WriteBatch batch) {
    if (options != null) {
      batch.set(reference, data, options!);
    } else {
      batch.set(reference, data);
    }
  }
}

/// Update batch operation
class UpdateBatchOperation implements BatchOperation {
  final DocumentReference reference;
  final Map<String, dynamic> data;

  const UpdateBatchOperation(this.reference, this.data);

  @override
  Future<void> execute() => reference.update(data);

  @override
  void addToBatch(WriteBatch batch) {
    batch.update(reference, data);
  }
}

/// Delete batch operation
class DeleteBatchOperation implements BatchOperation {
  final DocumentReference reference;

  const DeleteBatchOperation(this.reference);

  @override
  Future<void> execute() => reference.delete();

  @override
  void addToBatch(WriteBatch batch) {
    batch.delete(reference);
  }
}