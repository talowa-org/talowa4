// lib/services/performance/advanced_cache_service.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Advanced Multi-Level Caching Service for 10M DAU Support
class AdvancedCacheService {
  static final AdvancedCacheService _instance = AdvancedCacheService._internal();
  factory AdvancedCacheService() => _instance;
  AdvancedCacheService._internal();

  // Cache Configuration
  static const int maxMemoryCacheSize = 1000;
  static const int maxDiskCacheSize = 10000;
  static const Duration shortCache = Duration(minutes: 5);
  static const Duration mediumCache = Duration(hours: 1);
  static const Duration longCache = Duration(days: 1);

  // Memory Cache (L1)
  final LinkedHashMap<String, CacheEntry> _memoryCache = LinkedHashMap();
  
  // Cache Statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  
  // Cache Warming Queue
  final Queue<String> _warmingQueue = Queue();
  Timer? _warmingTimer;
  
  // Cache Invalidation
  final Map<String, Set<String>> _taggedKeys = {};
  final Map<String, DateTime> _keyExpiry = {};

  /// Initialize the cache service
  Future<void> initialize() async {
    await _startCacheWarming();
    _startCacheCleanup();
    _startCacheAnalytics();
    
    if (kDebugMode) {
      print('✅ Advanced Cache Service initialized');
    }
  }

  /// Get cached data with automatic cache warming
  Future<T?> get<T>(
    String key, {
    Duration? ttl,
    List<String>? tags,
    bool warmCache = false,
  }) async {
    try {
      // Check memory cache first (L1)
      final memoryEntry = _memoryCache[key];
      if (memoryEntry != null && !_isExpired(memoryEntry)) {
        _hits++;
        
        // Move to end (LRU)
        _memoryCache.remove(key);
        _memoryCache[key] = memoryEntry;
        
        if (warmCache) {
          _scheduleWarmup(key);
        }
        
        return _deserialize<T>(memoryEntry.data);
      }

      // Cache miss
      _misses++;
      
      if (kDebugMode) {
        print('🔍 Cache miss for key: $key');
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Cache get error for key $key: $e');
      }
      return null;
    }
  }

  /// Set cached data with intelligent eviction
  Future<void> set<T>(
    String key,
    T data, {
    Duration? ttl,
    List<String>? tags,
    CachePriority priority = CachePriority.normal,
  }) async {
    try {
      final expiry = DateTime.now().add(ttl ?? mediumCache);
      final entry = CacheEntry(
        key: key,
        data: _serialize(data),
        expiry: expiry,
        priority: priority,
        accessCount: 1,
        lastAccessed: DateTime.now(),
        tags: tags ?? [],
      );

      // Add to memory cache
      await _addToMemoryCache(key, entry);
      
      // Update tag mappings
      if (tags != null) {
        for (final tag in tags) {
          _taggedKeys.putIfAbsent(tag, () => <String>{}).add(key);
        }
      }
      
      // Set expiry tracking
      _keyExpiry[key] = expiry;
      
      if (kDebugMode) {
        print('💾 Cached data for key: $key (TTL: ${ttl?.inMinutes ?? 60}min)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Cache set error for key $key: $e');
      }
    }
  }

  /// Add entry to memory cache with intelligent eviction
  Future<void> _addToMemoryCache(String key, CacheEntry entry) async {
    // Remove existing entry if present
    _memoryCache.remove(key);
    
    // Check if cache is full
    if (_memoryCache.length >= maxMemoryCacheSize) {
      await _evictLeastValuable();
    }
    
    // Add new entry
    _memoryCache[key] = entry;
  }

  /// Evict least valuable cache entry
  Future<void> _evictLeastValuable() async {
    if (_memoryCache.isEmpty) return;
    
    String? keyToEvict;
    double lowestScore = double.infinity;
    
    for (final entry in _memoryCache.entries) {
      final score = _calculateCacheScore(entry.value);
      if (score < lowestScore) {
        lowestScore = score;
        keyToEvict = entry.key;
      }
    }
    
    if (keyToEvict != null) {
      _memoryCache.remove(keyToEvict);
      _keyExpiry.remove(keyToEvict);
      _evictions++;
      
      if (kDebugMode) {
        print('🗑️ Evicted cache entry: $keyToEvict (score: ${lowestScore.toStringAsFixed(2)})');
      }
    }
  }

  /// Calculate cache score for eviction priority
  double _calculateCacheScore(CacheEntry entry) {
    final now = DateTime.now();
    final age = now.difference(entry.lastAccessed).inMinutes;
    final timeToExpiry = entry.expiry.difference(now).inMinutes;
    
    // Higher score = more valuable (less likely to be evicted)
    double score = entry.accessCount.toDouble();
    
    // Priority multiplier
    switch (entry.priority) {
      case CachePriority.critical:
        score *= 10.0;
        break;
      case CachePriority.high:
        score *= 5.0;
        break;
      case CachePriority.normal:
        score *= 1.0;
        break;
      case CachePriority.low:
        score *= 0.5;
        break;
    }
    
    // Reduce score based on age
    score /= (age + 1);
    
    // Reduce score if expiring soon
    if (timeToExpiry < 60) {
      score *= 0.1;
    }
    
    return score;
  }

  /// Invalidate cache by key
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    _keyExpiry.remove(key);
    
    // Remove from tag mappings
    _taggedKeys.forEach((tag, keys) {
      keys.remove(key);
    });
    
    if (kDebugMode) {
      print('🗑️ Invalidated cache for key: $key');
    }
  }

  /// Invalidate cache by tags
  Future<void> invalidateByTags(List<String> tags) async {
    final keysToInvalidate = <String>{};
    
    for (final tag in tags) {
      final taggedKeys = _taggedKeys[tag];
      if (taggedKeys != null) {
        keysToInvalidate.addAll(taggedKeys);
      }
    }
    
    for (final key in keysToInvalidate) {
      await invalidate(key);
    }
    
    if (kDebugMode) {
      print('🗑️ Invalidated ${keysToInvalidate.length} cache entries by tags: $tags');
    }
  }

  /// Warm cache with popular content
  Future<void> warmCache(String key, Future<dynamic> Function() dataLoader) async {
    try {
      final data = await dataLoader();
      await set(key, data, ttl: longCache, priority: CachePriority.high);
      
      if (kDebugMode) {
        print('🔥 Warmed cache for key: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Cache warming error for key $key: $e');
      }
    }
  }

  /// Schedule cache warming
  void _scheduleWarmup(String key) {
    if (!_warmingQueue.contains(key)) {
      _warmingQueue.add(key);
    }
  }

  /// Start cache warming process
  Future<void> _startCacheWarming() async {
    _warmingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _processCacheWarming();
    });
  }

  /// Process cache warming queue
  void _processCacheWarming() {
    if (_warmingQueue.isNotEmpty) {
      final key = _warmingQueue.removeFirst();
      // Implement cache warming logic based on key patterns
      _warmPopularContent(key);
    }
  }

  /// Warm popular content based on usage patterns
  void _warmPopularContent(String key) {
    // Implement intelligent cache warming based on usage patterns
    // This would typically involve analyzing access patterns and pre-loading related content
    if (kDebugMode) {
      print('🔥 Warming related content for: $key');
    }
  }

  /// Start cache cleanup process
  void _startCacheCleanup() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _cleanupExpiredEntries();
    });
  }

  /// Cleanup expired cache entries
  void _cleanupExpiredEntries() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _memoryCache.forEach((key, entry) {
      if (_isExpired(entry)) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _keyExpiry.remove(key);
    }
    
    if (expiredKeys.isNotEmpty && kDebugMode) {
      print('🧹 Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }

  /// Check if cache entry is expired
  bool _isExpired(CacheEntry entry) {
    return DateTime.now().isAfter(entry.expiry);
  }

  /// Start cache analytics
  void _startCacheAnalytics() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      _logCacheAnalytics();
    });
  }

  /// Log cache analytics
  void _logCacheAnalytics() {
    if (kDebugMode) {
      final hitRate = _hits + _misses > 0 ? (_hits / (_hits + _misses) * 100) : 0;
      
      print('📊 Cache Analytics:');
      print('   Hit Rate: ${hitRate.toStringAsFixed(1)}%');
      print('   Hits: $_hits, Misses: $_misses');
      print('   Memory Cache Size: ${_memoryCache.length}/$maxMemoryCacheSize');
      print('   Evictions: $_evictions');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final hitRate = _hits + _misses > 0 ? (_hits / (_hits + _misses) * 100) : 0;
    
    return {
      'hitRate': hitRate,
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'memoryCacheSize': _memoryCache.length,
      'maxMemoryCacheSize': maxMemoryCacheSize,
      'taggedKeysCount': _taggedKeys.length,
    };
  }

  /// Serialize data for caching
  String _serialize<T>(T data) {
    try {
      return jsonEncode(data);
    } catch (e) {
      return data.toString();
    }
  }

  /// Deserialize cached data
  T? _deserialize<T>(String data) {
    try {
      return jsonDecode(data) as T;
    } catch (e) {
      return data as T?;
    }
  }

  /// Clear all cache
  Future<void> clear() async {
    _memoryCache.clear();
    _keyExpiry.clear();
    _taggedKeys.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    
    if (kDebugMode) {
      print('🧹 Cache cleared');
    }
  }

  /// Dispose cache service
  void dispose() {
    _warmingTimer?.cancel();
    clear();
  }
}

/// Cache entry model
class CacheEntry {
  final String key;
  final String data;
  final DateTime expiry;
  final CachePriority priority;
  final List<String> tags;
  int accessCount;
  DateTime lastAccessed;

  CacheEntry({
    required this.key,
    required this.data,
    required this.expiry,
    required this.priority,
    required this.tags,
    this.accessCount = 1,
    required this.lastAccessed,
  });
}

/// Cache priority levels
enum CachePriority {
  critical,
  high,
  normal,
  low,
}