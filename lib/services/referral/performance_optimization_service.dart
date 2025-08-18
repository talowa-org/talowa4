import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Exception thrown when performance optimization operations fail
class PerformanceOptimizationException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const PerformanceOptimizationException(this.message, [this.code = 'PERFORMANCE_OPTIMIZATION_FAILED', this.context]);
  
  @override
  String toString() => 'PerformanceOptimizationException: $message';
}

/// Cache entry with expiration
class CacheEntry<T> {
  final T data;
  final DateTime expiresAt;
  
  CacheEntry(this.data, this.expiresAt);
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Service for performance optimization and scalability
class PerformanceOptimizationService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // In-memory cache for frequently accessed data
  static final Map<String, CacheEntry> _cache = {};
  static final Map<String, Completer<dynamic>> _pendingRequests = {};
  
  // Cache configuration
  static const Duration DEFAULT_CACHE_DURATION = Duration(minutes: 5);
  static const Duration USER_STATS_CACHE_DURATION = Duration(minutes: 2);
  static const Duration ROLE_DEFINITIONS_CACHE_DURATION = Duration(hours: 1);
  static const int MAX_CACHE_SIZE = 1000;
  
  // Batch processing configuration
  static const int DEFAULT_BATCH_SIZE = 100;
  static const Duration BATCH_PROCESSING_INTERVAL = Duration(seconds: 30);
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Get cached data or fetch from source
  static Future<T> getCachedData<T>(
    String key,
    Future<T> Function() fetchFunction, {
    Duration? cacheDuration,
  }) async {
    // Check if request is already pending
    if (_pendingRequests.containsKey(key)) {
      return await _pendingRequests[key]!.future as T;
    }
    
    // Check cache first
    final cacheEntry = _cache[key];
    if (cacheEntry != null && !cacheEntry.isExpired) {
      return cacheEntry.data as T;
    }
    
    // Create completer for pending request
    final completer = Completer<T>();
    _pendingRequests[key] = completer;
    
    try {
      // Fetch data
      final data = await fetchFunction();
      
      // Cache the result
      final duration = cacheDuration ?? DEFAULT_CACHE_DURATION;
      _cache[key] = CacheEntry(data, DateTime.now().add(duration));
      
      // Clean cache if it's getting too large
      _cleanCacheIfNeeded();
      
      completer.complete(data);
      return data;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingRequests.remove(key);
    }
  }
  
  /// Clean cache if it exceeds maximum size
  static void _cleanCacheIfNeeded() {
    if (_cache.length <= MAX_CACHE_SIZE) return;
    
    // Remove expired entries first
    _cache.removeWhere((key, entry) => entry.isExpired);
    
    // If still too large, remove oldest entries
    if (_cache.length > MAX_CACHE_SIZE) {
      final sortedEntries = _cache.entries.toList()
        ..sort((a, b) => a.value.expiresAt.compareTo(b.value.expiresAt));
      
      final entriesToRemove = sortedEntries.take(_cache.length - MAX_CACHE_SIZE);
      for (final entry in entriesToRemove) {
        _cache.remove(entry.key);
      }
    }
  }
  
  /// Clear cache for specific key or pattern
  static void clearCache([String? keyPattern]) {
    if (keyPattern == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((key, _) => key.contains(keyPattern));
    }
  }
  
  /// Get user statistics with caching
  static Future<Map<String, dynamic>> getCachedUserStatistics(String userId) async {
    final cacheKey = 'user_stats_$userId';
    
    return await getCachedData(
      cacheKey,
      () async {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          throw PerformanceOptimizationException(
            'User not found: $userId',
            'USER_NOT_FOUND',
            {'userId': userId}
          );
        }
        
        final userData = userDoc.data()!;
        return {
          'userId': userId,
          'directReferrals': userData['directReferrals'] ?? 0,
          'activeDirectReferrals': userData['activeDirectReferrals'] ?? 0,
          'teamSize': userData['teamSize'] ?? 0,
          'activeTeamSize': userData['activeTeamSize'] ?? 0,
          'currentRole': userData['currentRole'] ?? 'member',
          'membershipPaid': userData['membershipPaid'] ?? false,
          'lastStatsUpdate': userData['lastStatsUpdate'],
        };
      },
      cacheDuration: USER_STATS_CACHE_DURATION,
    );
  }
  
  /// Batch update user statistics efficiently
  static Future<void> batchUpdateUserStatistics(List<String> userIds) async {
    try {
      // Process in batches to avoid overwhelming Firestore
      for (int i = 0; i < userIds.length; i += DEFAULT_BATCH_SIZE) {
        final batchUserIds = userIds.skip(i).take(DEFAULT_BATCH_SIZE).toList();
        
        // Use Firestore batch for atomic updates
        final batch = _firestore.batch();
        
        for (final userId in batchUserIds) {
          try {
            // Check if user exists first
            final userDoc = await _firestore.collection('users').doc(userId).get();
            if (!userDoc.exists) {
              print('Warning: User $userId not found, skipping stats update');
              continue;
            }

            // Calculate fresh statistics
            final stats = await _calculateUserStatistics(userId);

            // Update user document
            final userRef = _firestore.collection('users').doc(userId);
            batch.update(userRef, {
              'directReferrals': stats['directReferrals'],
              'activeDirectReferrals': stats['activeDirectReferrals'],
              'teamSize': stats['teamSize'],
              'activeTeamSize': stats['activeTeamSize'],
              'lastStatsUpdate': FieldValue.serverTimestamp(),
            });

            // Invalidate cache
            clearCache('user_stats_$userId');

          } catch (e) {
            // Log error but continue with other users
            print('Warning: Failed to update stats for user $userId: $e');
          }
        }
        
        await batch.commit();
        
        // Small delay between batches to avoid rate limiting
        if (i + DEFAULT_BATCH_SIZE < userIds.length) {
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      throw PerformanceOptimizationException(
        'Failed to batch update user statistics: $e',
        'BATCH_UPDATE_FAILED',
        {'userIds': userIds}
      );
    }
  }
  
  /// Calculate user statistics efficiently
  static Future<Map<String, dynamic>> _calculateUserStatistics(String userId) async {
    // Use parallel queries for better performance
    final futures = await Future.wait([
      _countDirectReferrals(userId),
      _countActiveDirectReferrals(userId),
      _calculateTeamSize(userId),
      _calculateActiveTeamSize(userId),
    ]);
    
    return {
      'directReferrals': futures[0],
      'activeDirectReferrals': futures[1],
      'teamSize': futures[2],
      'activeTeamSize': futures[3],
    };
  }
  
  /// Count direct referrals with optimized query
  static Future<int> _countDirectReferrals(String userId) async {
    final query = await _firestore
        .collection('users')
        .where('referredBy', isEqualTo: userId)
        .get();
    
    return query.docs.length;
  }
  
  /// Count active direct referrals with optimized query
  static Future<int> _countActiveDirectReferrals(String userId) async {
    final query = await _firestore
        .collection('users')
        .where('referredBy', isEqualTo: userId)
        .where('membershipPaid', isEqualTo: true)
        .get();
    
    return query.docs.length;
  }
  
  /// Calculate team size with recursive optimization
  static Future<int> _calculateTeamSize(String userId) async {
    final visited = <String>{};
    return await _calculateTeamSizeRecursive(userId, visited, 0, 10); // Max depth 10
  }
  
  /// Calculate active team size with recursive optimization
  static Future<int> _calculateActiveTeamSize(String userId) async {
    final visited = <String>{};
    return await _calculateActiveTeamSizeRecursive(userId, visited, 0, 10); // Max depth 10
  }
  
  /// Recursive team size calculation with depth limit
  static Future<int> _calculateTeamSizeRecursive(
    String userId,
    Set<String> visited,
    int currentDepth,
    int maxDepth,
  ) async {
    if (currentDepth >= maxDepth || visited.contains(userId)) {
      return 0;
    }
    
    visited.add(userId);
    
    final query = await _firestore
        .collection('users')
        .where('referredBy', isEqualTo: userId)
        .get();
    
    int totalSize = query.docs.length;
    
    // Recursively calculate for each direct referral
    for (final doc in query.docs) {
      totalSize += await _calculateTeamSizeRecursive(
        doc.id,
        visited,
        currentDepth + 1,
        maxDepth,
      );
    }
    
    return totalSize;
  }
  
  /// Recursive active team size calculation with depth limit
  static Future<int> _calculateActiveTeamSizeRecursive(
    String userId,
    Set<String> visited,
    int currentDepth,
    int maxDepth,
  ) async {
    if (currentDepth >= maxDepth || visited.contains(userId)) {
      return 0;
    }
    
    visited.add(userId);
    
    final query = await _firestore
        .collection('users')
        .where('referredBy', isEqualTo: userId)
        .get();
    
    int activeSize = 0;
    
    for (final doc in query.docs) {
      final data = doc.data();
      if (data['membershipPaid'] == true) {
        activeSize++;
      }
      
      // Recursively calculate for each direct referral
      activeSize += await _calculateActiveTeamSizeRecursive(
        doc.id,
        visited,
        currentDepth + 1,
        maxDepth,
      );
    }
    
    return activeSize;
  }
  
  /// Optimize Firestore queries with proper indexing hints
  static Query optimizeQuery(Query query, Map<String, dynamic> indexHints) {
    // In a real implementation, this would add index hints
    // For now, return the query as-is
    return query;
  }
  
  /// Handle race conditions for concurrent updates
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries) {
          rethrow;
        }
        
        // Exponential backoff
        await Future.delayed(delay * attempts);
      }
    }
    
    throw PerformanceOptimizationException(
      'Operation failed after $maxRetries attempts',
      'MAX_RETRIES_EXCEEDED'
    );
  }
  
  /// Get performance metrics
  static Map<String, dynamic> getPerformanceMetrics() {
    return {
      'cacheSize': _cache.length,
      'pendingRequests': _pendingRequests.length,
      'cacheHitRate': _calculateCacheHitRate(),
      'expiredEntries': _cache.values.where((entry) => entry.isExpired).length,
      'memoryUsage': _estimateMemoryUsage(),
    };
  }
  
  /// Calculate cache hit rate (simplified)
  static double _calculateCacheHitRate() {
    // In a real implementation, this would track hits vs misses
    return 0.85; // Placeholder
  }
  
  /// Estimate memory usage (simplified)
  static String _estimateMemoryUsage() {
    final entries = _cache.length;
    final estimatedBytes = entries * 1024; // Rough estimate
    
    if (estimatedBytes < 1024) {
      return '${estimatedBytes}B';
    } else if (estimatedBytes < 1024 * 1024) {
      return '${(estimatedBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(estimatedBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
  
  /// Preload frequently accessed data
  static Future<void> preloadFrequentData() async {
    try {
      // Preload role definitions
      await getCachedData(
        'role_definitions',
        () async {
          // This would fetch role definitions
          return {'preloaded': true};
        },
        cacheDuration: ROLE_DEFINITIONS_CACHE_DURATION,
      );
      
      // Preload global statistics
      await getCachedData(
        'global_stats',
        () async {
          // This would fetch global statistics
          return {'preloaded': true};
        },
        cacheDuration: Duration(minutes: 10),
      );
    } catch (e) {
      print('Warning: Failed to preload frequent data: $e');
    }
  }
  
  /// Monitor query performance
  static Future<T> monitorQuery<T>(
    String queryName,
    Future<T> Function() queryFunction,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await queryFunction();
      stopwatch.stop();
      
      _logQueryPerformance(queryName, stopwatch.elapsedMilliseconds, true);
      return result;
    } catch (e) {
      stopwatch.stop();
      _logQueryPerformance(queryName, stopwatch.elapsedMilliseconds, false);
      rethrow;
    }
  }
  
  /// Log query performance metrics
  static void _logQueryPerformance(String queryName, int durationMs, bool success) {
    if (kDebugMode) {
      print('Query: $queryName, Duration: ${durationMs}ms, Success: $success');
    }
    
    // In a real implementation, this would send to monitoring service
  }
  
  /// Cleanup expired cache entries
  static void cleanupExpiredEntries() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getCacheStatistics() {
    final expiredCount = _cache.values.where((entry) => entry.isExpired).length;
    
    return {
      'totalEntries': _cache.length,
      'expiredEntries': expiredCount,
      'validEntries': _cache.length - expiredCount,
      'maxSize': MAX_CACHE_SIZE,
      'utilizationPercent': (_cache.length / MAX_CACHE_SIZE * 100).round(),
      'pendingRequests': _pendingRequests.length,
    };
  }
}
