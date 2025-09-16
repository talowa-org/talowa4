// Database Optimization Service - Advanced Firestore query optimization
// Comprehensive database performance optimization for TALOWA platform

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'caching_service.dart';

class DatabaseOptimizationService {
  static DatabaseOptimizationService? _instance;
  static DatabaseOptimizationService get instance => _instance ??= DatabaseOptimizationService._internal();
  
  DatabaseOptimizationService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Query optimization settings
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const Duration cacheTimeout = Duration(minutes: 5);
  
  // Query performance tracking
  final Map<String, QueryPerformanceMetrics> _queryMetrics = {};
  
  /// Initialize database optimization
  Future<void> initialize() async {
    try {
      debugPrint('âš¡ Initializing Database Optimization Service...');
      
      // Configure Firestore settings for better performance
      await _configureFirestoreSettings();
      
      // Setup query performance monitoring
      _setupQueryMonitoring();
      
      debugPrint('âœ… Database Optimization Service initialized');
      
    } catch (e) {
      debugPrint('âŒ Failed to initialize database optimization: $e');
    }
  }
  
  /// Optimized paginated query with caching
  Future<OptimizedQueryResult<T>> executeOptimizedQuery<T>({
    required String collection,
    required T Function(Map<String, dynamic>) fromFirestore,
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int limit = defaultPageSize,
    DocumentSnapshot? startAfter,
    bool useCache = true,
    Duration? cacheTimeout,
  }) async {
    try {
      final queryKey = _generateQueryKey(collection, filters, orderBy, limit);
      final startTime = DateTime.now();
      
      debugPrint('ðŸ” Executing optimized query: $collection');
      
      // Check cache first
      if (useCache) {
        final cachedResult = await CachingService.instance.getCachedData<List<Map<String, dynamic>>>(
          queryKey,
          level: CacheLevel.memory,
        );
        
        if (cachedResult != null) {
          debugPrint('ðŸŽ¯ Query cache hit: $collection');
          
          final items = cachedResult.map((data) => fromFirestore(data)).toList();
          return OptimizedQueryResult<T>(
            items: items,
            hasMore: items.length >= limit,
            lastDocument: null,
            fromCache: true,
            queryTime: Duration.zero,
          );
        }
      }
      
      // Build optimized query
      Query query = _firestore.collection(collection);
      
      // Apply filters
      if (filters != null) {
        for (final filter in filters) {
          query = _applyFilter(query, filter);
        }
      }
      
      // Apply ordering
      if (orderBy != null) {
        for (final order in orderBy) {
          query = query.orderBy(order.field, descending: order.descending);
        }
      }
      
      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      query = query.limit(limit);
      
      // Execute query
      final querySnapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      
      final endTime = DateTime.now();
      final queryTime = endTime.difference(startTime);
      
      // Process results
      final items = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return fromFirestore(data);
      }).toList();
      
      final lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
      final hasMore = querySnapshot.docs.length >= limit;
      
      // Cache results
      if (useCache && items.isNotEmpty) {
        final cacheData = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        
        await CachingService.instance.cacheData(
          queryKey,
          cacheData,
          duration: cacheTimeout ?? DatabaseOptimizationService.cacheTimeout,
          level: CacheLevel.memory,
        );
      }
      
      // Track performance
      _trackQueryPerformance(queryKey, queryTime, items.length, querySnapshot.metadata.isFromCache);
      
      debugPrint('âœ… Query completed: ${items.length} items in ${queryTime.inMilliseconds}ms');
      
      return OptimizedQueryResult<T>(
        items: items,
        hasMore: hasMore,
        lastDocument: lastDocument,
        fromCache: querySnapshot.metadata.isFromCache,
        queryTime: queryTime,
      );
      
    } catch (e) {
      debugPrint('âŒ Optimized query failed: $e');
      rethrow;
    }
  }
  
  /// Batch write operations for better performance
  Future<void> executeBatchWrite(List<BatchOperation> operations) async {
    try {
      debugPrint('ðŸ“ Executing batch write: ${operations.length} operations');
      
      final batch = _firestore.batch();
      
      for (final operation in operations) {
        switch (operation.type) {
          case BatchOperationType.create:
            batch.set(operation.reference, operation.data!);
            break;
          case BatchOperationType.update:
            batch.update(operation.reference, operation.data!);
            break;
          case BatchOperationType.delete:
            batch.delete(operation.reference);
            break;
        }
      }
      
      await batch.commit();
      
      debugPrint('âœ… Batch write completed');
      
    } catch (e) {
      debugPrint('âŒ Batch write failed: $e');
      rethrow;
    }
  }
  
  /// Optimized real-time listener with debouncing
  StreamSubscription<List<T>> createOptimizedListener<T>({
    required String collection,
    required T Function(Map<String, dynamic>) fromFirestore,
    required Function(List<T>) onData,
    Function(Object)? onError,
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int limit = defaultPageSize,
    Duration debounceTime = const Duration(milliseconds: 300),
  }) {
    debugPrint('ðŸ‘‚ Creating optimized listener: $collection');
    
    // Build query
    Query query = _firestore.collection(collection);
    
    // Apply filters
    if (filters != null) {
      for (final filter in filters) {
        query = _applyFilter(query, filter);
      }
    }
    
    // Apply ordering
    if (orderBy != null) {
      for (final order in orderBy) {
        query = query.orderBy(order.field, descending: order.descending);
      }
    }
    
    query = query.limit(limit);
    
    // Create debounced stream
    final controller = StreamController<List<T>>();
    Timer? debounceTimer;
    
    final firestoreSubscription = query.snapshots().listen(
      (querySnapshot) {
        // Cancel previous timer
        debounceTimer?.cancel();
        
        // Start new timer
        debounceTimer = Timer(debounceTime, () {
          try {
            final items = querySnapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return fromFirestore(data);
            }).toList();
            
            controller.add(items);
            
          } catch (e) {
            controller.addError(e);
          }
        });
      },
      onError: (error) {
        controller.addError(error);
      },
    );
    
    final subscription = controller.stream.listen(
      onData,
      onError: onError,
    );
    
    // Clean up when subscription is cancelled
    subscription.onDone(() {
      debounceTimer?.cancel();
      firestoreSubscription.cancel();
      controller.close();
    });
    
    return subscription;
  }
  
  /// Get query performance metrics
  Map<String, QueryPerformanceMetrics> getQueryMetrics() {
    return Map.from(_queryMetrics);
  }
  
  /// Clear query performance metrics
  void clearQueryMetrics() {
    _queryMetrics.clear();
    debugPrint('ðŸ§¹ Query metrics cleared');
  }
  
  /// Configure Firestore settings for optimal performance
  Future<void> _configureFirestoreSettings() async {
    try {
      // Configure Firestore settings for better performance
      _firestore.settings = const Settings(
        cacheSizeBytes: 200 * 1024 * 1024, // 200MB cache
        persistenceEnabled: !kIsWeb, // Only enable persistence on non-web platforms
      );
      
      // Configure cache size (100MB)
      _firestore.settings = const Settings(
        cacheSizeBytes: 100 * 1024 * 1024,
        persistenceEnabled: true,
      );
      
      debugPrint('âœ… Firestore settings configured');
      
    } catch (e) {
      debugPrint('âš ï¸ Firestore settings configuration failed: $e');
    }
  }
  
  /// Setup query performance monitoring
  void _setupQueryMonitoring() {
    // Clear old metrics periodically
    Timer.periodic(const Duration(hours: 1), (timer) {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      
      _queryMetrics.removeWhere((key, metrics) => 
          metrics.lastExecuted.isBefore(cutoff));
    });
  }
  
  /// Apply filter to query
  Query _applyFilter(Query query, QueryFilter filter) {
    switch (filter.operator) {
      case FilterOperator.isEqualTo:
        return query.where(filter.field, isEqualTo: filter.value);
      case FilterOperator.isNotEqualTo:
        return query.where(filter.field, isNotEqualTo: filter.value);
      case FilterOperator.isLessThan:
        return query.where(filter.field, isLessThan: filter.value);
      case FilterOperator.isLessThanOrEqualTo:
        return query.where(filter.field, isLessThanOrEqualTo: filter.value);
      case FilterOperator.isGreaterThan:
        return query.where(filter.field, isGreaterThan: filter.value);
      case FilterOperator.isGreaterThanOrEqualTo:
        return query.where(filter.field, isGreaterThanOrEqualTo: filter.value);
      case FilterOperator.arrayContains:
        return query.where(filter.field, arrayContains: filter.value);
      case FilterOperator.arrayContainsAny:
        return query.where(filter.field, arrayContainsAny: filter.value);
      case FilterOperator.whereIn:
        return query.where(filter.field, whereIn: filter.value);
      case FilterOperator.whereNotIn:
        return query.where(filter.field, whereNotIn: filter.value);
      case FilterOperator.isNull:
        return query.where(filter.field, isNull: true);
      case FilterOperator.isNotNull:
        return query.where(filter.field, isNull: false);
    }
  }
  
  /// Generate query cache key
  String _generateQueryKey(
    String collection,
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int limit,
  ) {
    final parts = [collection, limit.toString()];
    
    if (filters != null) {
      for (final filter in filters) {
        parts.add('${filter.field}_${filter.operator.name}_${filter.value}');
      }
    }
    
    if (orderBy != null) {
      for (final order in orderBy) {
        parts.add('${order.field}_${order.descending}');
      }
    }
    
    return parts.join('_');
  }
  
  /// Track query performance
  void _trackQueryPerformance(
    String queryKey,
    Duration queryTime,
    int resultCount,
    bool fromCache,
  ) {
    final existing = _queryMetrics[queryKey];
    
    if (existing != null) {
      _queryMetrics[queryKey] = existing.copyWith(
        executionCount: existing.executionCount + 1,
        totalTime: existing.totalTime + queryTime,
        lastExecuted: DateTime.now(),
        lastResultCount: resultCount,
        cacheHitCount: fromCache ? existing.cacheHitCount + 1 : existing.cacheHitCount,
      );
    } else {
      _queryMetrics[queryKey] = QueryPerformanceMetrics(
        queryKey: queryKey,
        executionCount: 1,
        totalTime: queryTime,
        averageTime: queryTime,
        lastExecuted: DateTime.now(),
        lastResultCount: resultCount,
        cacheHitCount: fromCache ? 1 : 0,
      );
    }
  }
}

// Data Classes and Enums

class OptimizedQueryResult<T> {
  final List<T> items;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final bool fromCache;
  final Duration queryTime;

  const OptimizedQueryResult({
    required this.items,
    required this.hasMore,
    this.lastDocument,
    required this.fromCache,
    required this.queryTime,
  });
}

class QueryFilter {
  final String field;
  final FilterOperator operator;
  final dynamic value;

  const QueryFilter({
    required this.field,
    required this.operator,
    required this.value,
  });
}

class QueryOrder {
  final String field;
  final bool descending;

  const QueryOrder({
    required this.field,
    this.descending = false,
  });
}

class BatchOperation {
  final BatchOperationType type;
  final DocumentReference reference;
  final Map<String, dynamic>? data;

  const BatchOperation({
    required this.type,
    required this.reference,
    this.data,
  });
}

class QueryPerformanceMetrics {
  final String queryKey;
  final int executionCount;
  final Duration totalTime;
  final Duration averageTime;
  final DateTime lastExecuted;
  final int lastResultCount;
  final int cacheHitCount;

  const QueryPerformanceMetrics({
    required this.queryKey,
    required this.executionCount,
    required this.totalTime,
    required this.averageTime,
    required this.lastExecuted,
    required this.lastResultCount,
    required this.cacheHitCount,
  });

  QueryPerformanceMetrics copyWith({
    int? executionCount,
    Duration? totalTime,
    DateTime? lastExecuted,
    int? lastResultCount,
    int? cacheHitCount,
  }) {
    final newExecutionCount = executionCount ?? this.executionCount;
    final newTotalTime = totalTime ?? this.totalTime;
    
    return QueryPerformanceMetrics(
      queryKey: queryKey,
      executionCount: newExecutionCount,
      totalTime: newTotalTime,
      averageTime: Duration(
        microseconds: newTotalTime.inMicroseconds ~/ newExecutionCount,
      ),
      lastExecuted: lastExecuted ?? this.lastExecuted,
      lastResultCount: lastResultCount ?? this.lastResultCount,
      cacheHitCount: cacheHitCount ?? this.cacheHitCount,
    );
  }
}

enum FilterOperator {
  isEqualTo,
  isNotEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  arrayContains,
  arrayContainsAny,
  whereIn,
  whereNotIn,
  isNull,
  isNotNull,
}

enum BatchOperationType {
  create,
  update,
  delete,
}

