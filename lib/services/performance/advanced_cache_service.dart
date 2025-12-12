import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Cache tier levels for multi-tier architecture
enum CacheTier {
  l1Memory,     // In-memory cache (fastest)
  l2Persistent, // Local persistent cache
  l3Distributed,// Distributed cache simulation
  l4CDN,        // CDN cache (external)
}

/// Cache entry with metadata and compression support
class AdvancedCacheEntry {
  final String key;
  final dynamic data;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int accessCount;
  final DateTime lastAccessedAt;
  final int size;
  final bool isCompressed;
  final List<String> dependencies;
  final Map<String, dynamic> metadata;

  AdvancedCacheEntry({
    required this.key,
    required this.data,
    required this.createdAt,
    required this.expiresAt,
    this.accessCount = 0,
    DateTime? lastAccessedAt,
    this.size = 0,
    this.isCompressed = false,
    this.dependencies = const [],
    this.metadata = const {},
  }) : lastAccessedAt = lastAccessedAt ?? DateTime.now();

  AdvancedCacheEntry copyWith({
    int? accessCount,
    DateTime? lastAccessedAt,
  }) {
    return AdvancedCacheEntry(
      key: key,
      data: data,
      createdAt: createdAt,
      expiresAt: expiresAt,
      accessCount: accessCount ?? this.accessCount,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      size: size,
      isCompressed: isCompressed,
      dependencies: dependencies,
      metadata: metadata,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired;
}

/// Cache performance metrics
class CacheMetrics {
  int hits = 0;
  int misses = 0;
  int evictions = 0;
  int compressions = 0;
  int decompressions = 0;
  double totalSize = 0;
  DateTime lastReset = DateTime.now();

  double get hitRate => (hits + misses) > 0 ? hits / (hits + misses) : 0.0;
  double get missRate => 1.0 - hitRate;
  
  void reset() {
    hits = 0;
    misses = 0;
    evictions = 0;
    compressions = 0;
    decompressions = 0;
    totalSize = 0;
    lastReset = DateTime.now();
  }
}

/// Advanced multi-tier caching system with intelligent invalidation
class AdvancedCacheService {
  static AdvancedCacheService? _instance;
  static AdvancedCacheService get instance => _instance ??= AdvancedCacheService._();

  AdvancedCacheService._();

  // L1 Cache - In-memory (fastest)
  final Map<String, AdvancedCacheEntry> _l1Cache = {};
  
  // L2 Cache - Persistent storage
  SharedPreferences? _l2Cache;
  
  // L3 Cache - Distributed cache simulation (using IndexedDB on web)
  final Map<String, AdvancedCacheEntry> _l3Cache = {};
  
  // Cache configuration
  int _maxL1Size = 50 * 1024 * 1024; // 50MB
  int _maxL2Size = 200 * 1024 * 1024; // 200MB
  int _maxL3Size = 500 * 1024 * 1024; // 500MB
  int _maxL1Entries = 1000;
  int _maxL2Entries = 5000;
  int _maxL3Entries = 10000;
  
  // Dependency tracking for intelligent invalidation
  final Map<String, Set<String>> _dependencies = {};
  final Map<String, Set<String>> _dependents = {};
  
  // Performance metrics
  final Map<CacheTier, CacheMetrics> _metrics = {
    CacheTier.l1Memory: CacheMetrics(),
    CacheTier.l2Persistent: CacheMetrics(),
    CacheTier.l3Distributed: CacheMetrics(),
  };
  
  // Cache warming strategies
  final Map<String, Timer> _warmingTimers = {};
  final Set<String> _popularKeys = {};
  
  // Compression settings
  bool _compressionEnabled = true;
  int _compressionThreshold = 1024; // 1KB
  
  bool _isInitialized = false;

  /// Initialize the advanced cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _l2Cache = await SharedPreferences.getInstance();
      await _loadL3Cache();
      await _startCacheMonitoring();
      
      _isInitialized = true;
      debugPrint('✅ Advanced Cache Service initialized');
      debugPrint('📊 Cache tiers: L1(Memory), L2(Persistent), L3(Distributed)');
    } catch (e) {
      debugPrint('❌ Failed to initialize Advanced Cache Service: $e');
    }
  }

  /// Configure cache settings
  void configure({
    int? maxL1Size,
    int? maxL2Size,
    int? maxL3Size,
    int? maxL1Entries,
    int? maxL2Entries,
    int? maxL3Entries,
    bool? compressionEnabled,
    int? compressionThreshold,
  }) {
    _maxL1Size = maxL1Size ?? _maxL1Size;
    _maxL2Size = maxL2Size ?? _maxL2Size;
    _maxL3Size = maxL3Size ?? _maxL3Size;
    _maxL1Entries = maxL1Entries ?? _maxL1Entries;
    _maxL2Entries = maxL2Entries ?? _maxL2Entries;
    _maxL3Entries = maxL3Entries ?? _maxL3Entries;
    _compressionEnabled = compressionEnabled ?? _compressionEnabled;
    _compressionThreshold = compressionThreshold ?? _compressionThreshold;
    
    debugPrint('🔧 Advanced Cache configured:');
    debugPrint('   L1: ${_maxL1Size ~/ (1024 * 1024)}MB, $_maxL1Entries entries');
    debugPrint('   L2: ${_maxL2Size ~/ (1024 * 1024)}MB, $_maxL2Entries entries');
    debugPrint('   L3: ${_maxL3Size ~/ (1024 * 1024)}MB, $_maxL3Entries entries');
    debugPrint('   Compression: $_compressionEnabled (threshold: ${_compressionThreshold}B)');
  }

  /// Set data in cache with intelligent tier placement
  Future<void> set<T>(
    String key,
    T data, {
    Duration? duration,
    List<String>? dependencies,
    Map<String, dynamic>? metadata,
    CacheTier? preferredTier,
    bool? compress,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final expiration = duration ?? const Duration(minutes: 30);
      final expiresAt = DateTime.now().add(expiration);
      
      // Serialize data
      final serializedData = _serializeData(data);
      final dataSize = _calculateSize(serializedData);
      
      // Determine if compression should be used
      final shouldCompress = compress ?? 
          (_compressionEnabled && dataSize > _compressionThreshold);
      
      final finalData = shouldCompress ? 
          _compressData(serializedData) : serializedData;
      
      if (shouldCompress) {
        _metrics[CacheTier.l1Memory]!.compressions++;
      }

      // Create cache entry
      final entry = AdvancedCacheEntry(
        key: key,
        data: finalData,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        size: _calculateSize(finalData),
        isCompressed: shouldCompress,
        dependencies: dependencies ?? [],
        metadata: metadata ?? {},
      );

      // Set up dependency tracking
      if (dependencies != null) {
        _setupDependencyTracking(key, dependencies);
      }

      // Determine cache tier placement
      final tier = preferredTier ?? _determineBestTier(entry);
      
      // Store in appropriate tiers
      await _setInTier(tier, key, entry);
      
      // Mark as popular if accessed frequently
      _trackPopularity(key);
      
      debugPrint('💾 Cached [$tier]: $key (${entry.size} bytes, compressed: $shouldCompress)');
      
    } catch (e) {
      debugPrint('❌ Error setting cache for $key: $e');
    }
  }

  /// Get data from cache with tier fallback
  Future<T?> get<T>(String key) async {
    if (!_isInitialized) await initialize();

    try {
      // Try L1 cache first (fastest)
      final l1Entry = await _getFromTier<T>(CacheTier.l1Memory, key);
      if (l1Entry != null) {
        _metrics[CacheTier.l1Memory]!.hits++;
        await _updateAccessStats(key, l1Entry);
        return l1Entry;
      }

      // Try L2 cache
      final l2Entry = await _getFromTier<T>(CacheTier.l2Persistent, key);
      if (l2Entry != null) {
        _metrics[CacheTier.l2Persistent]!.hits++;
        // Promote to L1 for faster future access
        await _promoteToL1(key, l2Entry);
        return l2Entry;
      }

      // Try L3 cache
      final l3Entry = await _getFromTier<T>(CacheTier.l3Distributed, key);
      if (l3Entry != null) {
        _metrics[CacheTier.l3Distributed]!.hits++;
        // Promote to L1 for faster future access
        await _promoteToL1(key, l3Entry);
        return l3Entry;
      }

      // Cache miss
      _metrics[CacheTier.l1Memory]!.misses++;
      return null;
      
    } catch (e) {
      debugPrint('❌ Error getting cache for $key: $e');
      return null;
    }
  }

  /// Intelligent cache invalidation with dependency tracking
  Future<void> invalidate(String key) async {
    try {
      // Remove from all tiers
      await _removeFromAllTiers(key);
      
      // Invalidate dependents
      final dependents = _dependents[key] ?? {};
      for (final dependent in dependents) {
        await invalidate(dependent);
      }
      
      // Clean up dependency tracking
      _cleanupDependencyTracking(key);
      
      debugPrint('🗑️ Invalidated cache: $key (+ ${dependents.length} dependents)');
      
    } catch (e) {
      debugPrint('❌ Error invalidating cache for $key: $e');
    }
  }

  /// Invalidate cache entries by pattern
  Future<void> invalidatePattern(String pattern) async {
    try {
      final regex = RegExp(pattern);
      final keysToInvalidate = <String>[];
      
      // Find matching keys in all tiers
      keysToInvalidate.addAll(_l1Cache.keys.where((key) => regex.hasMatch(key)));
      keysToInvalidate.addAll(_l3Cache.keys.where((key) => regex.hasMatch(key)));
      
      // Check L2 cache keys
      if (_l2Cache != null) {
        final l2Keys = _l2Cache!.getKeys().where((key) => 
            key.startsWith('cache_') && regex.hasMatch(key.substring(6)));
        keysToInvalidate.addAll(l2Keys.map((key) => key.substring(6)));
      }
      
      // Invalidate all matching keys
      for (final key in keysToInvalidate.toSet()) {
        await invalidate(key);
      }
      
      debugPrint('🗑️ Invalidated ${keysToInvalidate.length} entries matching pattern: $pattern');
      
    } catch (e) {
      debugPrint('❌ Error invalidating pattern $pattern: $e');
    }
  }

  /// Cache warming for popular content
  Future<void> warmCache(Map<String, dynamic> popularData) async {
    try {
      debugPrint('🔥 Starting cache warming for ${popularData.length} entries');
      
      for (final entry in popularData.entries) {
        await set(
          entry.key,
          entry.value,
          duration: const Duration(hours: 2),
          preferredTier: CacheTier.l1Memory,
        );
        
        // Mark as popular
        _popularKeys.add(entry.key);
      }
      
      debugPrint('✅ Cache warming completed');
      
    } catch (e) {
      debugPrint('❌ Error warming cache: $e');
    }
  }

  /// Preload cache with predictive content
  Future<void> preloadCache(List<String> keys, Future<dynamic> Function(String) dataLoader) async {
    try {
      debugPrint('📦 Preloading cache for ${keys.length} keys');
      
      final futures = keys.map((key) async {
        try {
          final data = await dataLoader(key);
          await set(key, data, duration: const Duration(minutes: 45));
        } catch (e) {
          debugPrint('❌ Error preloading $key: $e');
        }
      });
      
      await Future.wait(futures);
      debugPrint('✅ Cache preloading completed');
      
    } catch (e) {
      debugPrint('❌ Error preloading cache: $e');
    }
  }

  /// Get comprehensive cache statistics
  Map<String, dynamic> getStats() {
    final stats = <String, dynamic>{};
    
    for (final tier in CacheTier.values) {
      if (tier == CacheTier.l4CDN) continue; // External tier
      
      final metrics = _metrics[tier]!;
      stats[tier.name] = {
        'hits': metrics.hits,
        'misses': metrics.misses,
        'hitRate': metrics.hitRate,
        'evictions': metrics.evictions,
        'compressions': metrics.compressions,
        'decompressions': metrics.decompressions,
        'totalSize': metrics.totalSize,
        'entries': _getEntriesCount(tier),
      };
    }
    
    stats['popular_keys'] = _popularKeys.length;
    stats['dependency_chains'] = _dependencies.length;
    stats['warming_timers'] = _warmingTimers.length;
    
    return stats;
  }

  /// Clear all cache tiers
  Future<void> clearAll() async {
    try {
      _l1Cache.clear();
      _l3Cache.clear();
      
      if (_l2Cache != null) {
        final keys = _l2Cache!.getKeys().where((key) => key.startsWith('cache_'));
        for (final key in keys) {
          await _l2Cache!.remove(key);
        }
      }
      
      _dependencies.clear();
      _dependents.clear();
      _popularKeys.clear();
      
      // Reset metrics
      for (final metrics in _metrics.values) {
        metrics.reset();
      }
      
      debugPrint('🗑️ Cleared all cache tiers');
      
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  // Private helper methods

  CacheTier _determineBestTier(AdvancedCacheEntry entry) {
    // Small, frequently accessed data goes to L1
    if (entry.size < 10 * 1024 && _popularKeys.contains(entry.key)) {
      return CacheTier.l1Memory;
    }
    
    // Medium-sized data goes to L2
    if (entry.size < 100 * 1024) {
      return CacheTier.l2Persistent;
    }
    
    // Large data goes to L3
    return CacheTier.l3Distributed;
  }

  Future<void> _setInTier(CacheTier tier, String key, AdvancedCacheEntry entry) async {
    switch (tier) {
      case CacheTier.l1Memory:
        _l1Cache[key] = entry;
        await _evictIfNeeded(CacheTier.l1Memory);
        break;
        
      case CacheTier.l2Persistent:
        if (_l2Cache != null) {
          final serialized = jsonEncode({
            'data': entry.data,
            'createdAt': entry.createdAt.millisecondsSinceEpoch,
            'expiresAt': entry.expiresAt.millisecondsSinceEpoch,
            'size': entry.size,
            'isCompressed': entry.isCompressed,
            'dependencies': entry.dependencies,
            'metadata': entry.metadata,
          });
          await _l2Cache!.setString('cache_$key', serialized);
        }
        break;
        
      case CacheTier.l3Distributed:
        _l3Cache[key] = entry;
        await _evictIfNeeded(CacheTier.l3Distributed);
        break;
        
      case CacheTier.l4CDN:
        // External CDN cache - not implemented in this service
        break;
    }
  }

  Future<T?> _getFromTier<T>(CacheTier tier, String key) async {
    AdvancedCacheEntry? entry;
    
    switch (tier) {
      case CacheTier.l1Memory:
        entry = _l1Cache[key];
        break;
        
      case CacheTier.l2Persistent:
        if (_l2Cache != null) {
          final serialized = _l2Cache!.getString('cache_$key');
          if (serialized != null) {
            try {
              final data = jsonDecode(serialized);
              entry = AdvancedCacheEntry(
                key: key,
                data: data['data'],
                createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt']),
                expiresAt: DateTime.fromMillisecondsSinceEpoch(data['expiresAt']),
                size: data['size'] ?? 0,
                isCompressed: data['isCompressed'] ?? false,
                dependencies: List<String>.from(data['dependencies'] ?? []),
                metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
              );
            } catch (e) {
              debugPrint('❌ Error deserializing L2 cache entry: $e');
            }
          }
        }
        break;
        
      case CacheTier.l3Distributed:
        entry = _l3Cache[key];
        break;
        
      case CacheTier.l4CDN:
        // External CDN cache - not implemented
        break;
    }
    
    if (entry == null || entry.isExpired) {
      if (entry?.isExpired == true) {
        await _removeFromTier(tier, key);
      }
      return null;
    }
    
    // Decompress if needed
    dynamic data = entry.data;
    if (entry.isCompressed) {
      data = _decompressData(data);
      _metrics[tier]!.decompressions++;
    }
    
    return _deserializeData<T>(data);
  }

  Future<void> _removeFromTier(CacheTier tier, String key) async {
    switch (tier) {
      case CacheTier.l1Memory:
        _l1Cache.remove(key);
        break;
        
      case CacheTier.l2Persistent:
        if (_l2Cache != null) {
          await _l2Cache!.remove('cache_$key');
        }
        break;
        
      case CacheTier.l3Distributed:
        _l3Cache.remove(key);
        break;
        
      case CacheTier.l4CDN:
        // External CDN cache - not implemented
        break;
    }
  }

  Future<void> _removeFromAllTiers(String key) async {
    await _removeFromTier(CacheTier.l1Memory, key);
    await _removeFromTier(CacheTier.l2Persistent, key);
    await _removeFromTier(CacheTier.l3Distributed, key);
  }

  Future<void> _evictIfNeeded(CacheTier tier) async {
    Map<String, AdvancedCacheEntry> cache;
    int maxEntries;
    int maxSize;
    
    switch (tier) {
      case CacheTier.l1Memory:
        cache = _l1Cache;
        maxEntries = _maxL1Entries;
        maxSize = _maxL1Size;
        break;
      case CacheTier.l3Distributed:
        cache = _l3Cache;
        maxEntries = _maxL3Entries;
        maxSize = _maxL3Size;
        break;
      default:
        return;
    }
    
    // Check if eviction is needed
    if (cache.length <= maxEntries) return;
    
    // Calculate total size
    final totalSize = cache.values.fold<int>(0, (sum, entry) => sum + entry.size);
    if (totalSize <= maxSize) return;
    
    // Evict least recently used entries
    final sortedEntries = cache.entries.toList()
      ..sort((a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt));
    
    final entriesToEvict = sortedEntries.take(cache.length - maxEntries + 1);
    
    for (final entry in entriesToEvict) {
      cache.remove(entry.key);
      _metrics[tier]!.evictions++;
    }
    
    debugPrint('🗑️ Evicted ${entriesToEvict.length} entries from $tier');
  }

  Future<void> _promoteToL1(String key, dynamic data) async {
    if (!_l1Cache.containsKey(key)) {
      final entry = AdvancedCacheEntry(
        key: key,
        data: data,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        size: _calculateSize(data),
      );
      
      _l1Cache[key] = entry;
      await _evictIfNeeded(CacheTier.l1Memory);
    }
  }

  void _setupDependencyTracking(String key, List<String> dependencies) {
    _dependencies[key] = dependencies.toSet();
    
    for (final dependency in dependencies) {
      _dependents[dependency] ??= <String>{};
      _dependents[dependency]!.add(key);
    }
  }

  void _cleanupDependencyTracking(String key) {
    final dependencies = _dependencies.remove(key) ?? <String>{};
    
    for (final dependency in dependencies) {
      _dependents[dependency]?.remove(key);
      if (_dependents[dependency]?.isEmpty == true) {
        _dependents.remove(dependency);
      }
    }
  }

  void _trackPopularity(String key) {
    // Simple popularity tracking - in production this would be more sophisticated
    final entry = _l1Cache[key];
    if (entry != null && entry.accessCount > 5) {
      _popularKeys.add(key);
    }
  }

  Future<void> _updateAccessStats(String key, dynamic data) async {
    final entry = _l1Cache[key];
    if (entry != null) {
      _l1Cache[key] = entry.copyWith(
        accessCount: entry.accessCount + 1,
        lastAccessedAt: DateTime.now(),
      );
    }
  }

  String _serializeData(dynamic data) {
    try {
      return jsonEncode(data);
    } catch (e) {
      return data.toString();
    }
  }

  T? _deserializeData<T>(dynamic data) {
    try {
      if (data is String) {
        final decoded = jsonDecode(data);
        return decoded as T?;
      }
      return data as T?;
    } catch (e) {
      return data as T?;
    }
  }

  String _compressData(String data) {
    // Web-compatible compression: Use base64 encoding only
    // Note: gzip is not available in web platform
    // For production, consider using a web-compatible compression library
    if (kIsWeb) {
      // On web, skip compression to avoid platform issues
      return data;
    }
    
    try {
      final bytes = utf8.encode(data);
      final compressed = gzip.encode(bytes);
      return base64Encode(compressed);
    } catch (e) {
      debugPrint('⚠️ Compression failed, returning original data: $e');
      return data;
    }
  }

  String _decompressData(String compressedData) {
    if (kIsWeb) {
      // On web, data is not compressed
      return compressedData;
    }
    
    try {
      final bytes = base64Decode(compressedData);
      final decompressed = gzip.decode(bytes);
      return utf8.decode(decompressed);
    } catch (e) {
      return compressedData; // Return as-is if decompression fails
    }
  }

  int _calculateSize(dynamic data) {
    if (data is String) {
      return utf8.encode(data).length;
    } else if (data is Uint8List) {
      return data.length;
    } else {
      return utf8.encode(data.toString()).length;
    }
  }

  int _getEntriesCount(CacheTier tier) {
    switch (tier) {
      case CacheTier.l1Memory:
        return _l1Cache.length;
      case CacheTier.l2Persistent:
        return _l2Cache?.getKeys().where((key) => key.startsWith('cache_')).length ?? 0;
      case CacheTier.l3Distributed:
        return _l3Cache.length;
      case CacheTier.l4CDN:
        return 0;
    }
  }

  Future<void> _loadL3Cache() async {
    // In a real implementation, this would load from a distributed cache
    // For now, we'll simulate it with in-memory storage
    debugPrint('📡 L3 Distributed cache simulation initialized');
  }

  Future<void> _startCacheMonitoring() async {
    // Start periodic cache maintenance
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _performMaintenance();
    });
    
    debugPrint('🔍 Cache monitoring started');
  }

  void _performMaintenance() {
    try {
      // Clean expired entries
      _cleanExpiredEntries();
      
      // Update popularity metrics
      _updatePopularityMetrics();
      
      // Log performance stats
      if (kDebugMode) {
        final stats = getStats();
        debugPrint('📊 Cache Stats: L1 hit rate: ${(stats['l1Memory']['hitRate'] * 100).toStringAsFixed(1)}%');
      }
      
    } catch (e) {
      debugPrint('❌ Error during cache maintenance: $e');
    }
  }

  void _cleanExpiredEntries() {
    final now = DateTime.now();
    
    // Clean L1 cache
    _l1Cache.removeWhere((key, entry) => entry.expiresAt.isBefore(now));
    
    // Clean L3 cache
    _l3Cache.removeWhere((key, entry) => entry.expiresAt.isBefore(now));
  }

  void _updatePopularityMetrics() {
    // Update popular keys based on access patterns
    const popularThreshold = 10;
    
    for (final entry in _l1Cache.entries) {
      if (entry.value.accessCount >= popularThreshold) {
        _popularKeys.add(entry.key);
      }
    }
  }
}