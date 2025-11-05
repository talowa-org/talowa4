// Database Optimization Service for TALOWA
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseOptimizationService {
  static final DatabaseOptimizationService _instance = DatabaseOptimizationService._internal();
  factory DatabaseOptimizationService() => _instance;
  DatabaseOptimizationService._internal();

  static DatabaseOptimizationService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;

  /// Initialize the database optimization service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Configure Firestore settings
      configureFirestore();
      
      // Enable offline persistence
      await enableOfflinePersistence();
      
      _isInitialized = true;
      debugPrint('✅ Database Optimization Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Database Optimization Service: $e');
    }
  }

  /// Execute an optimized Firestore query
  Future<QuerySnapshot> executeOptimizedQuery(Query query) async {
    try {
      // Try cache first for better performance
      return await query.get(const GetOptions(source: Source.cache));
    } catch (e) {
      // Fallback to server if cache fails
      return await query.get(const GetOptions(source: Source.server));
    }
  }

  /// Batch get multiple documents for better performance
  Future<List<DocumentSnapshot>> batchGetDocuments(List<DocumentReference> refs) async {
    if (refs.isEmpty) return [];
    
    try {
      // Firestore batch get (up to 500 documents)
      final chunks = <List<DocumentReference>>[];
      for (int i = 0; i < refs.length; i += 500) {
        chunks.add(refs.sublist(i, i + 500 > refs.length ? refs.length : i + 500));
      }
      
      final List<DocumentSnapshot> results = [];
      for (final chunk in chunks) {
        final futures = chunk.map((ref) => ref.get()).toList();
        final snapshots = await Future.wait(futures);
        results.addAll(snapshots);
      }
      
      return results;
    } catch (e) {
      debugPrint('Error in batch get documents: $e');
      return [];
    }
  }

  /// Optimize query with proper indexing hints
  Query optimizeQuery(Query query, {
    String? orderByField,
    bool descending = false,
    Map<String, dynamic>? whereConditions,
  }) {
    Query optimizedQuery = query;
    
    // Apply where conditions first for better index usage
    if (whereConditions != null) {
      whereConditions.forEach((field, value) {
        if (value is List) {
          optimizedQuery = optimizedQuery.where(field, whereIn: value);
        } else {
          optimizedQuery = optimizedQuery.where(field, isEqualTo: value);
        }
      });
    }
    
    // Apply ordering last
    if (orderByField != null) {
      optimizedQuery = optimizedQuery.orderBy(orderByField, descending: descending);
    }
    
    return optimizedQuery;
  }

  /// Enable offline persistence (mobile only)
  Future<void> enableOfflinePersistence() async {
    if (!kIsWeb) {
      try {
        // Persistence is enabled by default in newer versions
        debugPrint('✅ Firestore offline persistence is available');
      } catch (e) {
        debugPrint('⚠️ Firestore persistence error: $e');
      }
    }
  }

  /// Configure Firestore settings for optimal performance
  void configureFirestore() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}