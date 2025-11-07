import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'advanced_cache_service.dart';

/// Cache partition types for different data categories
enum CachePartition {
  userProfiles,    // User profile data
  feedPosts,       // Social feed posts
  mediaAssets,     // Images, videos, documents
  searchResults,   // Search query results
  analytics,       // Analytics and metrics
  notifications,   // Push notifications
  realtime,        // Real-time data
  static,          // Static configuration data
  moderation,      // AI moderation results
}

/// Partition configuration
class PartitionConfig {
  final String name;
  final int maxSize;
  final int maxEntries;
  final Duration defaultTTL;
  final bool compressionEnabled;
  final CacheTier preferredTier;
  final double evictionThreshold;

  const PartitionConfig({
    required this.name,
    required this.maxSize,
    required this.maxEntries,
    required this.defaultTTL,
    this.compressionEnabled = true,
    this.preferredTier = CacheTier.l1Memory,
    this.evictionThreshold = 0.8,
  });
}

/// Partition statistics tracking
class PartitionStats {
  int hits = 0;
  int misses = 0;
  int sets = 0;
  int invalidations = 0;
  int entryCount = 0;
  int estimatedSize = 0;
  DateTime lastReset = DateTime.now();

  double get hitRate => (hits + misses) > 0 ? hits / (hits + misses) : 0.0;
  
  void reset() {
    hits = 0;
    misses = 0;
    sets = 0;
    invalidations = 0;
    entryCount = 0;
    estimatedSize = 0;
    lastReset = DateTime.now();
  }
}

/// Cache partitioning service for optimized performance
class CachePartitionService {
  static CachePartitionService? _instance;
  static CachePartitionService get instance => _instance ??= CachePartitionService._();

  CachePartitionService._();

  final AdvancedCacheService _cacheService = AdvancedCacheService.instance;
  
  // Partition configurations
  static const Map<CachePartition, PartitionConfig> _partitionConfigs = {
    CachePartition.userProfiles: PartitionConfig(
      name: 'user_profiles',
      maxSize: 10 * 1024 * 1024, // 10MB
      maxEntries: 1000,
      defaultTTL: Duration(hours: 2),
      preferredTier: CacheTier.l1Memory,
    ),
    
    CachePartition.feedPosts: PartitionConfig(
      name: 'feed_posts',
      maxSize: 50 * 1024 * 1024, // 50MB
      maxEntries: 2000,
      defaultTTL: Duration(minutes: 30),
      preferredTier: CacheTier.l1Memory,
    ),
    
    CachePartition.mediaAssets: PartitionConfig(
      name: 'media_assets',
      maxSize: 200 * 1024 * 1024, // 200MB
      maxEntries: 500,
      defaultTTL: Duration(hours: 24),
      preferredTier: CacheTier.l2Persistent,
      compressionEnabled: false, // Media is already compressed
    ),
    
    CachePartition.searchResults: PartitionConfig(
      name: 'search_results',
      maxSize: 20 * 1024 * 1024, // 20MB
      maxEntries: 1000,
      defaultTTL: Duration(minutes: 15),
      preferredTier: CacheTier.l1Memory,
    ),
    
    CachePartition.analytics: PartitionConfig(
      name: 'analytics',
      maxSize: 5 * 1024 * 1024, // 5MB
      maxEntries: 500,
      defaultTTL: Duration(hours: 1),
      preferredTier: CacheTier.l2Persistent,
    ),
    
    CachePartition.notifications: PartitionConfig(
      name: 'notifications',
      maxSize: 2 * 1024 * 1024, // 2MB
      maxEntries: 200,
      defaultTTL: Duration(minutes: 10),
      preferredTier: CacheTier.l1Memory,
    ),
    
    CachePartition.realtime: PartitionConfig(
      name: 'realtime',
      maxSize: 5 * 1024 * 1024, // 5MB
      maxEntries: 100,
      defaultTTL: Duration(minutes: 5),
      preferredTier: CacheTier.l1Memory,
      evictionThreshold: 0.9, // More aggressive eviction for real-time data
    ),
    
    CachePartition.static: PartitionConfig(
      name: 'static',
      maxSize: 10 * 1024 * 1024, // 10MB
      maxEntries: 100,
      defaultTTL: Duration(hours: 12),
      preferredTier: CacheTier.l2Persistent,
    ),
  };

  // Partition statistics
  final Map<CachePartition, PartitionStats> _partitionStats = {};
  
  bool _isInitialized = false;

  /// Initialize the cache partition service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _cacheService.initialize();
      _initializePartitionStats();
      _startPartitionMonitoring();
      
      _isInitialized = true;
      debugPrint('✅ Cache Partition Service initialized');
      debugPrint('📊 Partitions: ${_partitionConfigs.length}');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize Cache Partition Service: $e');
    }
  }

  /// Set data in appropriate partition
  Future<void> setInPartition<T>(
    CachePartition partition,
    String key,
    T data, {
    Duration? duration,
    List<String>? dependencies,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final config = _partitionConfigs[partition]!;
      final partitionKey = _buildPartitionKey(partition, key);
      
      // Check partition capacity
      await _checkPartitionCapacity(partition);
      
      await _cacheService.set(
        partitionKey,
        data,
        duration: duration ?? config.defaultTTL,
        dependencies: dependencies,
        metadata: {
          'partition': partition.name,
          'originalKey': key,
          ...?metadata,
        },
        preferredTier: config.preferredTier,
        compress: config.compressionEnabled,
      );
      
      // Update partition statistics
      _updatePartitionStats(partition, 'set');
      
      debugPrint('💾 Cached in partition [${partition.name}]: $key');
      
    } catch (e) {
      debugPrint('❌ Error setting cache in partition ${partition.name}: $e');
    }
  }

  /// Get data from partition
  Future<T?> getFromPartition<T>(CachePartition partition, String key) async {
    if (!_isInitialized) await initialize();

    try {
      final partitionKey = _buildPartitionKey(partition, key);
      final result = await _cacheService.get<T>(partitionKey);
      
      // Update partition statistics
      _updatePartitionStats(partition, result != null ? 'hit' : 'miss');
      
      if (result != null) {
        debugPrint('🎯 Cache hit in partition [${partition.name}]: $key');
      }
      
      return result;
      
    } catch (e) {
      debugPrint('❌ Error getting cache from partition ${partition.name}: $e');
      return null;
    }
  }

  /// Get partition statistics
  Map<String, dynamic> getPartitionStats() {
    final stats = <String, dynamic>{};
    
    for (final partition in CachePartition.values) {
      final partitionStats = _partitionStats[partition];
      if (partitionStats != null) {
        stats[partition.name] = {
          'hits': partitionStats.hits,
          'misses': partitionStats.misses,
          'sets': partitionStats.sets,
          'invalidations': partitionStats.invalidations,
          'hitRate': partitionStats.hitRate,
          'size': partitionStats.estimatedSize,
          'entries': partitionStats.entryCount,
          'config': {
            'maxSize': _partitionConfigs[partition]!.maxSize,
            'maxEntries': _partitionConfigs[partition]!.maxEntries,
            'defaultTTL': _partitionConfigs[partition]!.defaultTTL.inMinutes,
            'preferredTier': _partitionConfigs[partition]!.preferredTier.name,
          },
        };
      }
    }
    
    return stats;
  }

  // Private helper methods

  String _buildPartitionKey(CachePartition partition, String key) {
    return '${partition.name}_$key';
  }

  void _initializePartitionStats() {
    for (final partition in CachePartition.values) {
      _partitionStats[partition] = PartitionStats();
    }
  }

  Future<void> _checkPartitionCapacity(CachePartition partition) async {
    final config = _partitionConfigs[partition]!;
    final stats = _partitionStats[partition]!;
    
    // Check if partition is approaching capacity
    if (stats.entryCount >= config.maxEntries * config.evictionThreshold ||
        stats.estimatedSize >= config.maxSize * config.evictionThreshold) {
      
      debugPrint('⚠️ Partition ${partition.name} approaching capacity, triggering cleanup');
      await _cleanupPartition(partition);
    }
  }

  Future<void> _cleanupPartition(CachePartition partition) async {
    try {
      // This would implement LRU eviction for the specific partition
      debugPrint('🧹 Cleaning up partition: ${partition.name}');
      
    } catch (e) {
      debugPrint('❌ Error cleaning up partition ${partition.name}: $e');
    }
  }

  void _updatePartitionStats(CachePartition partition, String operation) {
    final stats = _partitionStats[partition];
    if (stats != null) {
      switch (operation) {
        case 'hit':
          stats.hits++;
          break;
        case 'miss':
          stats.misses++;
          break;
        case 'set':
          stats.sets++;
          stats.entryCount++;
          break;
        case 'invalidate':
          stats.invalidations++;
          stats.entryCount = max(0, stats.entryCount - 1);
          break;
      }
    }
  }

  void _startPartitionMonitoring() {
    Timer.periodic(const Duration(minutes: 10), (timer) {
      _performPartitionMaintenance();
    });
    
    debugPrint('🔍 Partition monitoring started');
  }

  void _performPartitionMaintenance() {
    try {
      // Log partition statistics
      if (kDebugMode) {
        for (final partition in CachePartition.values) {
          final stats = _partitionStats[partition];
          if (stats != null && (stats.hits + stats.misses) > 0) {
            debugPrint('📊 Partition [${partition.name}]: '
                'Hit rate: ${(stats.hitRate * 100).toStringAsFixed(1)}%, '
                'Entries: ${stats.entryCount}');
          }
        }
      }
      
    } catch (e) {
      debugPrint('❌ Error during partition maintenance: $e');
    }
  }
}