// Database Connection Service for TALOWA Messaging System
// Requirements: 5.1, 5.2, 7.1, 7.3, 7.4, 7.6

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseConnectionService {
  static final DatabaseConnectionService _instance = DatabaseConnectionService._internal();
  factory DatabaseConnectionService() => _instance;
  DatabaseConnectionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, int> _operationCounts = {};
  final Map<String, DateTime> _lastOperationTimes = {};
  final List<DatabaseOperation> _operationQueue = [];
  bool _isProcessingQueue = false;

  // Connection pool settings
  static const int _maxConcurrentOperations = 10;
  static const Duration _operationTimeout = Duration(seconds: 30);
  static const Duration _retryDelay = Duration(seconds: 1);
  static const int _maxRetries = 3;

  /// Initialize database connection service
  Future<void> initialize() async {
    try {
      debugPrint('DatabaseConnectionService: Initializing');
      
      // Configure Firestore settings for optimal performance
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Start queue processor
      _startQueueProcessor();
      
      debugPrint('DatabaseConnectionService: Initialized successfully');
    } catch (e) {
      debugPrint('DatabaseConnectionService: Error initializing: $e');
      rethrow;
    }
  }

  /// Execute database operation with connection pooling and error handling
  /// Requirements: 7.1, 7.3, 7.4
  Future<T> executeOperation<T>({
    required String operationName,
    required Future<T> Function() operation,
    int maxRetries = _maxRetries,
    Duration? timeout,
    bool useQueue = true,
  }) async {
    if (useQueue && _shouldQueue(operationName)) {
      return await _queueOperation(
        operationName: operationName,
        operation: operation,
        maxRetries: maxRetries,
        timeout: timeout ?? _operationTimeout,
      );
    }

    return await _executeWithRetry(
      operationName: operationName,
      operation: operation,
      maxRetries: maxRetries,
      timeout: timeout ?? _operationTimeout,
    );
  }

  /// Execute read operation with caching
  /// Requirements: 5.1, 5.2
  Future<DocumentSnapshot?> getDocument({
    required String collection,
    required String documentId,
    bool useCache = true,
  }) async {
    return await executeOperation(
      operationName: 'getDocument',
      operation: () async {
        final docRef = _firestore.collection(collection).doc(documentId);
        
        if (useCache) {
          // Try cache first
          final cachedDoc = await docRef.get(const GetOptions(source: Source.cache));
          if (cachedDoc.exists) {
            debugPrint('DatabaseConnectionService: Cache hit for $collection/$documentId');
            return cachedDoc;
          }
        }

        // Fetch from server
        final doc = await docRef.get(const GetOptions(source: Source.server));
        debugPrint('DatabaseConnectionService: Server fetch for $collection/$documentId');
        return doc;
      },
    );
  }

  /// Execute query with optimization
  /// Requirements: 5.2, 5.4
  Future<QuerySnapshot> executeQuery({
    required Query query,
    String operationName = 'query',
    bool useCache = false,
  }) async {
    return await executeOperation(
      operationName: operationName,
      operation: () async {
        final source = useCache ? Source.cache : Source.server;
        return await query.get(GetOptions(source: source));
      },
    );
  }

  /// Execute write operation with error handling
  /// Requirements: 5.1, 7.1, 7.3
  Future<void> writeDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    await executeOperation(
      operationName: 'writeDocument',
      operation: () async {
        final docRef = _firestore.collection(collection).doc(documentId);
        if (merge) {
          await docRef.set(data, SetOptions(merge: true));
        } else {
          await docRef.set(data);
        }
      },
    );
  }

  /// Execute batch write operations
  /// Requirements: 5.5, 5.6
  Future<void> executeBatch({
    required List<BatchOperation> operations,
    String operationName = 'batchWrite',
  }) async {
    await executeOperation(
      operationName: operationName,
      operation: () async {
        final batch = _firestore.batch();
        
        for (final operation in operations) {
          final docRef = _firestore.collection(operation.collection).doc(operation.documentId);
          
          switch (operation.type) {
            case BatchOperationType.set:
              batch.set(docRef, operation.data!, SetOptions(merge: operation.merge));
              break;
            case BatchOperationType.update:
              batch.update(docRef, operation.data!);
              break;
            case BatchOperationType.delete:
              batch.delete(docRef);
              break;
          }
        }
        
        await batch.commit();
        debugPrint('DatabaseConnectionService: Batch operation completed with ${operations.length} operations');
      },
    );
  }

  /// Create real-time listener with error handling
  /// Requirements: 5.3, 5.4, 7.1
  StreamSubscription<T> createListener<T>({
    required Stream<T> stream,
    required void Function(T) onData,
    void Function(Object)? onError,
    void Function()? onDone,
    String listenerName = 'listener',
  }) {
    return stream.listen(
      onData,
      onError: (error) {
        debugPrint('DatabaseConnectionService: Listener error in $listenerName: $error');
        _handleStreamError(error, listenerName);
        onError?.call(error);
      },
      onDone: () {
        debugPrint('DatabaseConnectionService: Listener completed: $listenerName');
        onDone?.call();
      },
    );
  }

  /// Get connection health status
  /// Requirements: 7.4, 7.6
  Future<ConnectionHealth> getConnectionHealth() async {
    try {
      final startTime = DateTime.now();
      
      // Test connection with a simple read
      await _firestore.collection('health_check').doc('test').get();
      
      final latency = DateTime.now().difference(startTime);
      
      return ConnectionHealth(
        isConnected: true,
        latency: latency,
        operationCounts: Map.from(_operationCounts),
        queueSize: _operationQueue.length,
        lastError: null,
      );
    } catch (e) {
      return ConnectionHealth(
        isConnected: false,
        latency: Duration.zero,
        operationCounts: Map.from(_operationCounts),
        queueSize: _operationQueue.length,
        lastError: e.toString(),
      );
    }
  }

  /// Get operation statistics
  Map<String, dynamic> getOperationStats() {
    return {
      'operationCounts': Map.from(_operationCounts),
      'queueSize': _operationQueue.length,
      'isProcessingQueue': _isProcessingQueue,
      'lastOperationTimes': _lastOperationTimes.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    };
  }

  /// Clear operation statistics
  void clearStats() {
    _operationCounts.clear();
    _lastOperationTimes.clear();
    debugPrint('DatabaseConnectionService: Statistics cleared');
  }

  // Private helper methods

  /// Execute operation with retry logic
  Future<T> _executeWithRetry<T>({
    required String operationName,
    required Future<T> Function() operation,
    required int maxRetries,
    required Duration timeout,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts <= maxRetries) {
      try {
        _incrementOperationCount(operationName);
        
        final result = await operation().timeout(timeout);
        
        _updateLastOperationTime(operationName);
        debugPrint('DatabaseConnectionService: Operation $operationName completed (attempt ${attempts + 1})');
        
        return result;
      } catch (e) {
        attempts++;
        lastException = e is Exception ? e : Exception(e.toString());
        
        debugPrint('DatabaseConnectionService: Operation $operationName failed (attempt $attempts): $e');
        
        if (attempts <= maxRetries) {
          final delay = _calculateRetryDelay(attempts);
          debugPrint('DatabaseConnectionService: Retrying $operationName in ${delay.inMilliseconds}ms');
          await Future.delayed(delay);
        }
      }
    }

    throw DatabaseException(
      'Operation $operationName failed after $maxRetries retries',
      lastException,
    );
  }

  /// Queue operation for later execution
  Future<T> _queueOperation<T>({
    required String operationName,
    required Future<T> Function() operation,
    required int maxRetries,
    required Duration timeout,
  }) async {
    final completer = Completer<T>();
    
    _operationQueue.add(DatabaseOperation<T>(
      name: operationName,
      operation: operation,
      completer: completer,
      maxRetries: maxRetries,
      timeout: timeout,
    ));

    debugPrint('DatabaseConnectionService: Queued operation $operationName (queue size: ${_operationQueue.length})');
    
    return completer.future;
  }

  /// Check if operation should be queued
  bool _shouldQueue(String operationName) {
    final currentOperations = _operationCounts.values.fold(0, (sum, count) => sum + count);
    return currentOperations >= _maxConcurrentOperations;
  }

  /// Start queue processor
  void _startQueueProcessor() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isProcessingQueue && _operationQueue.isNotEmpty) {
        _processQueue();
      }
    });
  }

  /// Process queued operations
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _operationQueue.isEmpty) return;
    
    _isProcessingQueue = true;
    
    try {
      while (_operationQueue.isNotEmpty) {
        final operation = _operationQueue.removeAt(0);
        
        try {
          final result = await _executeWithRetry(
            operationName: operation.name,
            operation: operation.operation,
            maxRetries: operation.maxRetries,
            timeout: operation.timeout,
          );
          
          operation.completer.complete(result);
        } catch (e) {
          operation.completer.completeError(e);
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Calculate retry delay with exponential backoff
  Duration _calculateRetryDelay(int attempt) {
    final baseDelay = _retryDelay.inMilliseconds;
    final exponentialDelay = baseDelay * pow(2, attempt - 1);
    final jitter = Random().nextInt(1000); // Add jitter to prevent thundering herd
    
    return Duration(milliseconds: exponentialDelay.toInt() + jitter);
  }

  /// Handle stream errors
  void _handleStreamError(Object error, String listenerName) {
    debugPrint('DatabaseConnectionService: Stream error in $listenerName: $error');
    
    // Could implement reconnection logic here
    // For now, just log the error
  }

  /// Increment operation count
  void _incrementOperationCount(String operationName) {
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
  }

  /// Update last operation time
  void _updateLastOperationTime(String operationName) {
    _lastOperationTimes[operationName] = DateTime.now();
  }
}

/// Database operation wrapper for queuing
class DatabaseOperation<T> {
  final String name;
  final Future<T> Function() operation;
  final Completer<T> completer;
  final int maxRetries;
  final Duration timeout;

  DatabaseOperation({
    required this.name,
    required this.operation,
    required this.completer,
    required this.maxRetries,
    required this.timeout,
  });
}

/// Batch operation definition
class BatchOperation {
  final String collection;
  final String documentId;
  final BatchOperationType type;
  final Map<String, dynamic>? data;
  final bool merge;

  BatchOperation({
    required this.collection,
    required this.documentId,
    required this.type,
    this.data,
    this.merge = false,
  });
}

enum BatchOperationType {
  set,
  update,
  delete,
}

/// Connection health information
class ConnectionHealth {
  final bool isConnected;
  final Duration latency;
  final Map<String, int> operationCounts;
  final int queueSize;
  final String? lastError;

  ConnectionHealth({
    required this.isConnected,
    required this.latency,
    required this.operationCounts,
    required this.queueSize,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'isConnected': isConnected,
      'latencyMs': latency.inMilliseconds,
      'operationCounts': operationCounts,
      'queueSize': queueSize,
      'lastError': lastError,
    };
  }
}

/// Database exception wrapper
class DatabaseException implements Exception {
  final String message;
  final Exception? cause;

  DatabaseException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'DatabaseException: $message\nCaused by: $cause';
    }
    return 'DatabaseException: $message';
  }
}