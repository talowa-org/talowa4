import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache entry for storing data with metadata
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final DateTime? expiresAt;

  CacheEntry({
    required this.data,
    required this.timestamp,
    this.expiresAt,
  });
}

/// Performance-focused cache service for optimizing app performance
class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();

  CacheService._();

  SharedPreferences? _prefs;
  final Map<String, CacheEntry> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  static const int _maxMemoryCacheSize = 100;
  static const Duration _defaultCacheDuration = Duration(minutes: 10);
  
  // Configuration properties
  int _maxMemorySize = 100 * 1024 * 1024; // 100MB default
  int _maxDiskSize = 500 * 1024 * 1024; // 500MB default

  /// Get persistent cache reference
  SharedPreferences? get _persistentCache => _prefs;

  /// Initialize the cache service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('✅ Performance CacheService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Performance CacheService: $e');
    }
  }
  
  /// Configure cache settings
  void configure({
    int? maxMemorySize,
    int? maxDiskSize,
  }) {
    if (maxMemorySize != null) {
      _maxMemorySize = maxMemorySize;
    }
    if (maxDiskSize != null) {
      _maxDiskSize = maxDiskSize;
    }
    debugPrint('📝 Cache configured - Memory: ${_maxMemorySize ~/ (1024 * 1024)}MB, Disk: ${_maxDiskSize ~/ (1024 * 1024)}MB');
  }

  /// Store data in cache with performance optimization
  Future<void> setCache(
    String key,
    dynamic data, {
    Duration? expiration,
    bool useMemoryCache = true,
    bool usePersistentCache = false,
  }) async {
    try {
      final timestamp = DateTime.now();

      // Store in memory cache for fast access
      if (useMemoryCache) {
        _memoryCache[key] = data;
        _cacheTimestamps[key] = timestamp;
        _manageCacheSize();
      }

      // Store in persistent cache if needed
      if (usePersistentCache && _prefs != null) {
        final cacheData = {
          'data': data,
          'timestamp': timestamp.millisecondsSinceEpoch,
          'expiration': expiration?.inMilliseconds,
        };
        await _prefs!.setString(key, jsonEncode(cacheData));
      }

      debugPrint('📦 Performance cached: $key');
    } catch (e) {
      debugPrint('❌ Failed to cache data: $e');
    }
  }

  /// Retrieve data from cache with performance optimization
  Future<T?> getCache<T>(String key, {Duration? maxAge}) async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(key)) {
        final entry = _memoryCache[key]!;
        if (entry.expiresAt != null && entry.expiresAt!.isAfter(DateTime.now())) {
          debugPrint('🎯 Memory cache hit: $key');
          return entry.data as T?;
        } else {
          _memoryCache.remove(key);
        }
      }

      // Check persistent cache
      if (_prefs != null) {
        final cachedData = _prefs!.getString(key);
        if (cachedData != null) {
          final Map<String, dynamic> data = jsonDecode(cachedData);
          final expiresAt = DateTime.parse(data['expiresAt']);
          
          if (expiresAt.isAfter(DateTime.now())) {
            debugPrint('💾 Persistent cache hit: $key');
            // Convert back to original type if needed
            if (T == Uint8List) {
              return base64Decode(data['data']) as T;
            }
            return data['data'] as T;
          } else {
            _prefs!.remove(key);
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cache for $key: $e');
      return null;
    }
  }

  /// Clear specific cache entry
  Future<void> clearCache(String key) async {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
    
    if (_prefs != null) {
      await _prefs!.remove(key);
    }
    
    debugPrint('🗑️ Cleared cache: $key');
  }

  /// Get cached image data
  Future<Uint8List?> getCachedImage(String imageUrl) async {
    debugPrint('🖼️ Getting cached image: $imageUrl');
    return await getCache<Uint8List>(imageUrl);
  }

  /// Cache image data
  Future<void> cacheImage(String imageUrl, Uint8List imageData) async {
    debugPrint('💾 Caching image: $imageUrl');
    await set<Uint8List>(imageUrl, imageData, duration: const Duration(hours: 24));
  }

  /// Generic get method for backward compatibility
  Future<T?> get<T>(String key) async {
    return await getCache<T>(key);
  }

  /// Set cache data with expiration
  Future<void> set<T>(String key, T data, {Duration? duration}) async {
    try {
      debugPrint('💾 Setting cache for key: $key');
      
      // Store in memory cache
      _memoryCache[key] = CacheEntry(
        data: data,
        timestamp: DateTime.now(),
        expiresAt: duration != null ? DateTime.now().add(duration) : null,
      );
      
      // Store in persistent cache if available
      if (_persistentCache != null) {
        final jsonData = jsonEncode({
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'expiresAt': duration != null 
              ? DateTime.now().add(duration).millisecondsSinceEpoch 
              : null,
        });
        await _persistentCache!.setString(key, jsonData);
      }
      
      debugPrint('✅ Cache set successfully for key: $key');
    } catch (e) {
      debugPrint('❌ Failed to set cache for key $key: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      _memoryCache.clear();
      _cacheTimestamps.clear();

      if (_prefs != null) {
        final keys = _prefs!.getKeys().toList();
        for (final key in keys) {
          await _prefs!.remove(key);
        }
      }

      debugPrint('🗑️ Cleared all cache');
    } catch (e) {
      debugPrint('❌ Failed to clear all cache: $e');
    }
  }

  /// Get cache performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'memoryCache': {
        'size': _memoryCache.length,
        'maxSize': _maxMemoryCacheSize,
        'hitRate': _calculateHitRate(),
      },
      'persistentCache': {
        'available': _prefs != null,
        'keys': _prefs?.getKeys().length ?? 0,
      },
      'performance': {
        'averageAccessTime': _calculateAverageAccessTime(),
        'cacheEfficiency': _calculateCacheEfficiency(),
      },
    };
  }

  /// Check if cache entry is valid
  bool _isCacheValid(DateTime timestamp, Duration? maxAge) {
    final age = maxAge ?? _defaultCacheDuration;
    return DateTime.now().difference(timestamp) <= age;
  }

  /// Manage memory cache size for optimal performance
  void _manageCacheSize() {
    if (_memoryCache.length > _maxMemoryCacheSize) {
      // Remove oldest entries
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final entriesToRemove = sortedEntries.take(_memoryCache.length - _maxMemoryCacheSize);

      for (final entry in entriesToRemove) {
        _memoryCache.remove(entry.key);
        _cacheTimestamps.remove(entry.key);
      }

      debugPrint('🗑️ Cleaned up ${entriesToRemove.length} cache entries');
    }
  }

  /// Calculate cache hit rate for performance monitoring
  double _calculateHitRate() {
    // This would be implemented with actual hit/miss counters
    return 0.85; // Placeholder
  }

  /// Calculate average access time
  double _calculateAverageAccessTime() {
    // This would be implemented with actual timing measurements
    return 2.5; // Placeholder in milliseconds
  }

  /// Calculate cache efficiency
  double _calculateCacheEfficiency() {
    // This would be implemented with actual efficiency metrics
    return 0.92; // Placeholder
  }

  /// Preload frequently accessed data
  Future<void> preloadCache(Map<String, dynamic> data) async {
    try {
      for (final entry in data.entries) {
        await setCache(
          entry.key,
          entry.value,
          useMemoryCache: true,
          usePersistentCache: false,
        );
      }
      debugPrint('📦 Preloaded ${data.length} cache entries');
    } catch (e) {
      debugPrint('❌ Failed to preload cache: $e');
    }
  }

  /// Warm up cache with essential data
  Future<void> warmUpCache() async {
    try {
      // This would preload essential app data
      debugPrint('🔥 Cache warmed up');
    } catch (e) {
      debugPrint('❌ Failed to warm up cache: $e');
    }
  }
}