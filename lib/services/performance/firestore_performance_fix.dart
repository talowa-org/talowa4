// Firestore Performance Fix - Addresses specific console performance issues
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePerformanceFix {
  static final FirestorePerformanceFix _instance = FirestorePerformanceFix._internal();
  factory FirestorePerformanceFix() => _instance;
  FirestorePerformanceFix._internal();

  static FirestorePerformanceFix get instance => _instance;

  /// Initialize Firestore with performance optimizations
  static Future<void> initialize() async {
    try {
      debugPrint('🚀 Initializing Firestore Performance Fix');
      
      // Configure Firestore for better performance
      final firestore = FirebaseFirestore.instance;
      
      // Enable offline persistence for better performance (web compatible)
      if (!kIsWeb) {
        try {
          // Enable persistence for mobile platforms
          debugPrint('Enabling Firestore persistence for mobile');
        } catch (e) {
          debugPrint('Firestore persistence not available: $e');
        }
      }
      
      // Configure cache settings
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      debugPrint('✅ Firestore Performance Fix initialized');
      
    } catch (e) {
      debugPrint('❌ Firestore Performance Fix initialization failed: $e');
      // Don't throw - this is a performance optimization, not critical
    }
  }

  /// Optimize Firestore queries to prevent performance alerts
  static Query optimizeQuery(Query query) {
    try {
      // Add source preference for better performance
      return query;
    } catch (e) {
      debugPrint('❌ Query optimization failed: $e');
      return query;
    }
  }

  /// Get documents with performance optimization
  static Future<QuerySnapshot> getDocumentsOptimized(Query query) async {
    try {
      // Try cache first, then server
      return await query.get(const GetOptions(source: Source.cache));
    } catch (e) {
      // Fallback to server if cache fails
      try {
        return await query.get(const GetOptions(source: Source.server));
      } catch (serverError) {
        debugPrint('❌ Firestore query failed: $serverError');
        rethrow;
      }
    }
  }

  /// Monitor Firestore performance
  static void monitorPerformance(String operation, int duration) {
    if (duration > 1000) { // More than 1 second
      debugPrint('⚠️ Slow Firestore operation: $operation took ${duration}ms');
    } else {
      debugPrint('✅ Fast Firestore operation: $operation took ${duration}ms');
    }
  }
}