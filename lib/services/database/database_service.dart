import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Database service for Firestore operations with performance optimization
class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();

  DatabaseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, DocumentSnapshot> _documentCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  static const Duration _defaultCacheDuration = Duration(minutes: 5);

  /// Initialize the database service
  Future<void> initialize() async {
    try {
      // Configure Firestore settings for better performance
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      debugPrint('✅ Database service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize database service: $e');
    }
  }

  /// Get document with caching
  Future<DocumentSnapshot?> getDocument(
    String collection,
    String documentId, {
    bool useCache = true,
    Duration? cacheDuration,
  }) async {
    try {
      final cacheKey = '${collection}_$documentId';
      final duration = cacheDuration ?? _defaultCacheDuration;

      // Check cache first
      if (useCache && _isCacheValid(cacheKey, duration)) {
        debugPrint('🎯 Document cache hit: $cacheKey');
        return _documentCache[cacheKey];
      }

      // Fetch from Firestore
      final doc = await _firestore.collection(collection).doc(documentId).get();

      // Cache the result
      if (useCache && doc.exists) {
        _documentCache[cacheKey] = doc;
        _cacheTimestamps[cacheKey] = DateTime.now();
        _manageCacheSize();
      }

      debugPrint('📄 Fetched document: $cacheKey');
      return doc;
    } catch (e) {
      debugPrint('❌ Failed to get document: $e');
      return null;
    }
  }

  /// Get collection with optimization
  Future<QuerySnapshot?> getCollection(
    String collection, {
    Query Function(Query)? queryBuilder,
    bool useCache = false,
    String? cacheKey,
  }) async {
    try {
      Query query = _firestore.collection(collection);
      
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }

      final result = await query.get();
      debugPrint('📚 Fetched collection: $collection (${result.docs.length} docs)');
      
      return result;
    } catch (e) {
      debugPrint('❌ Failed to get collection: $e');
      return null;
    }
  }

  /// Create document
  Future<bool> createDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(collection).doc(documentId).set(data);
      
      // Invalidate cache
      final cacheKey = '${collection}_$documentId';
      _documentCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      
      debugPrint('✅ Created document: $cacheKey');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to create document: $e');
      return false;
    }
  }

  /// Update document
  Future<bool> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(data);
      
      // Invalidate cache
      final cacheKey = '${collection}_$documentId';
      _documentCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      
      debugPrint('✅ Updated document: $cacheKey');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update document: $e');
      return false;
    }
  }

  /// Delete document
  Future<bool> deleteDocument(String collection, String documentId) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
      
      // Remove from cache
      final cacheKey = '${collection}_$documentId';
      _documentCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      
      debugPrint('🗑️ Deleted document: $cacheKey');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete document: $e');
      return false;
    }
  }

  /// Batch write operations
  Future<bool> batchWrite(List<BatchOperation> operations) async {
    try {
      final batch = _firestore.batch();
      
      for (final operation in operations) {
        final docRef = _firestore.collection(operation.collection).doc(operation.documentId);
        
        switch (operation.type) {
          case BatchOperationType.create:
          case BatchOperationType.set:
            batch.set(docRef, operation.data!);
            break;
          case BatchOperationType.update:
            batch.update(docRef, operation.data!);
            break;
          case BatchOperationType.delete:
            batch.delete(docRef);
            break;
        }
        
        // Invalidate cache for affected documents
        final cacheKey = '${operation.collection}_${operation.documentId}';
        _documentCache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
      }
      
      await batch.commit();
      debugPrint('✅ Batch write completed: ${operations.length} operations');
      return true;
    } catch (e) {
      debugPrint('❌ Batch write failed: $e');
      return false;
    }
  }

  /// Listen to document changes
  Stream<DocumentSnapshot> listenToDocument(String collection, String documentId) {
    return _firestore.collection(collection).doc(documentId).snapshots();
  }

  /// Listen to collection changes
  Stream<QuerySnapshot> listenToCollection(
    String collection, {
    Query Function(Query)? queryBuilder,
  }) {
    Query query = _firestore.collection(collection);
    
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    
    return query.snapshots();
  }

  /// Clear document cache
  void clearCache([String? specificKey]) {
    if (specificKey != null) {
      _documentCache.remove(specificKey);
      _cacheTimestamps.remove(specificKey);
      debugPrint('🗑️ Cleared cache for: $specificKey');
    } else {
      _documentCache.clear();
      _cacheTimestamps.clear();
      debugPrint('🗑️ Cleared all document cache');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _documentCache.length,
      'cachedDocuments': _documentCache.keys.toList(),
      'oldestCacheEntry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
    };
  }

  /// Check if cache entry is valid
  bool _isCacheValid(String key, Duration maxAge) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null || !_documentCache.containsKey(key)) {
      return false;
    }
    
    return DateTime.now().difference(timestamp) <= maxAge;
  }

  /// Manage cache size to prevent memory issues
  void _manageCacheSize() {
    const maxCacheSize = 100;
    
    if (_documentCache.length > maxCacheSize) {
      // Remove oldest entries
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final entriesToRemove = sortedEntries.take(_documentCache.length - maxCacheSize);
      
      for (final entry in entriesToRemove) {
        _documentCache.remove(entry.key);
        _cacheTimestamps.remove(entry.key);
      }
      
      debugPrint('🗑️ Cleaned up ${entriesToRemove.length} old cache entries');
    }
  }
}

/// Batch operation helper class
class BatchOperation {
  final String collection;
  final String documentId;
  final BatchOperationType type;
  final Map<String, dynamic>? data;

  const BatchOperation({
    required this.collection,
    required this.documentId,
    required this.type,
    this.data,
  });
}

/// Batch operation types
enum BatchOperationType {
  create,
  set,
  update,
  delete,
}