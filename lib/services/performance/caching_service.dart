// Advanced Caching Service - Comprehensive caching for TALOWA platform
// Multi-level caching with memory, disk, and network optimization

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class CachingService {
  static CachingService? _instance;
  static CachingService get instance => _instance ??= CachingService._internal();
  
  CachingService._internal();
  
  // Memory cache
  final Map<String, CacheEntry> _memoryCache = {};
  final Map<String, Uint8List> _imageCache = {};
  
  // Cache configuration
  static const int maxMemoryCacheSize = 100 * 1024 * 1024; // 100MB
  static const int maxImageCacheSize = 50 * 1024 * 1024; // 50MB
  static const Duration defaultCacheDuration = Duration(hours: 24);
  static const Duration imageCacheDuration = Duration(days: 7);
  
  // Cache statistics
  int _memoryCacheSize = 0;
  int _imageCacheSize = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  /// Initialize caching service
  static Future<void> initialize() async {
    final service = CachingService.instance;
    if (service._isInitialized) return;
    
    try {
      debugPrint('⚡ Initializing Advanced Caching Service...');
      
      service._prefs = await SharedPreferences.getInstance();
      
      // Load cache statistics
      service._loadCacheStatistics();
      
      // Setup periodic cleanup
      service._setupPeriodicCleanup();
      
      service._isInitialized = true;
      debugPrint('✅ Advanced Caching Service initialized');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize caching service: $e');
    }
  }
  
  /// Cache data with automatic expiration
  Future<void> cacheData(
    String key,
    dynamic data, {
    Duration? duration,
    CacheLevel level = CacheLevel.memory,
  }) async {
    try {
      final cacheKey = _generateCacheKey(key);
      final expiresAt = DateTime.now().add(duration ?? defaultCacheDuration);
      
      switch (level) {
        case CacheLevel.memory:
          await _cacheInMemory(cacheKey, data, expiresAt);
          break;
        case CacheLevel.disk:
          await _cacheToDisk(cacheKey, data, expiresAt);
          break;
        case CacheLevel.both:
          await _cacheInMemory(cacheKey, data, expiresAt);
          await _cacheToDisk(cacheKey, data, expiresAt);
          break;
      }
      
      debugPrint('ðŸ’¾ Cached data: $key (${level.name})');
      
    } catch (e) {
      debugPrint('âŒ Failed to cache data: $e');
    }
  }
  
  /// Retrieve cached data
  Future<T?> getCachedData<T>(
    String key, {
    CacheLevel level = CacheLevel.memory,
  }) async {
    try {
      final cacheKey = _generateCacheKey(key);
      
      // Try memory cache first
      if (level == CacheLevel.memory || level == CacheLevel.both) {
        final memoryResult = _getFromMemory<T>(cacheKey);
        if (memoryResult != null) {
          _cacheHits++;
          debugPrint('ðŸŽ¯ Cache hit (memory): $key');
          return memoryResult;
        }
      }
      
      // Try disk cache
      if (level == CacheLevel.disk || level == CacheLevel.both) {
        final diskResult = await _getFromDisk<T>(cacheKey);
        if (diskResult != null) {
          _cacheHits++;
          debugPrint('ðŸŽ¯ Cache hit (disk): $key');
          
          // Promote to memory cache
          if (level == CacheLevel.both) {
            await _cacheInMemory(cacheKey, diskResult, DateTime.now().add(defaultCacheDuration));
          }
          
          return diskResult;
        }
      }
      
      _cacheMisses++;
      debugPrint('âŒ Cache miss: $key');
      return null;
      
    } catch (e) {
      debugPrint('âŒ Failed to get cached data: $e');
      return null;
    }
  }
  
  /// Cache image data
  Future<void> cacheImage(String url, Uint8List imageData) async {
    try {
      final cacheKey = _generateCacheKey(url);
      
      // Check if we need to free up space
      if (_imageCacheSize + imageData.length > maxImageCacheSize) {
        await _cleanupImageCache();
      }
      
      _imageCache[cacheKey] = imageData;
      _imageCacheSize += imageData.length;
      
      // Also cache to disk for persistence
      await _cacheImageToDisk(cacheKey, imageData);
      
      debugPrint('ðŸ–¼ï¸ Cached image: $url (${imageData.length} bytes)');
      
    } catch (e) {
      debugPrint('âŒ Failed to cache image: $e');
    }
  }
  
  /// Get cached image
  Future<Uint8List?> getCachedImage(String url) async {
    try {
      final cacheKey = _generateCacheKey(url);
      
      // Try memory cache first
      if (_imageCache.containsKey(cacheKey)) {
        _cacheHits++;
        debugPrint('ðŸŽ¯ Image cache hit (memory): $url');
        return _imageCache[cacheKey];
      }
      
      // Try disk cache
      final diskImage = await _getImageFromDisk(cacheKey);
      if (diskImage != null) {
        _cacheHits++;
        debugPrint('ðŸŽ¯ Image cache hit (disk): $url');
        
        // Promote to memory cache if there's space
        if (_imageCacheSize + diskImage.length <= maxImageCacheSize) {
          _imageCache[cacheKey] = diskImage;
          _imageCacheSize += diskImage.length;
        }
        
        return diskImage;
      }
      
      _cacheMisses++;
      return null;
      
    } catch (e) {
      debugPrint('âŒ Failed to get cached image: $e');
      return null;
    }
  }
  
  /// Clear specific cache entry
  Future<void> clearCache(String key) async {
    try {
      final cacheKey = _generateCacheKey(key);
      
      // Remove from memory
      final memoryEntry = _memoryCache.remove(cacheKey);
      if (memoryEntry != null) {
        _memoryCacheSize -= _calculateDataSize(memoryEntry.data);
      }
      
      // Remove from disk
      await _removeFromDisk(cacheKey);
      
      debugPrint('ðŸ—‘ï¸ Cleared cache: $key');
      
    } catch (e) {
      debugPrint('âŒ Failed to clear cache: $e');
    }
  }
  
  /// Clear all caches
  Future<void> clearAllCaches() async {
    try {
      debugPrint('ðŸ§¹ Clearing all caches...');
      
      // Clear memory caches
      _memoryCache.clear();
      _imageCache.clear();
      _memoryCacheSize = 0;
      _imageCacheSize = 0;
      
      // Clear disk cache
      await _clearDiskCache();
      
      debugPrint('âœ… All caches cleared');
      
    } catch (e) {
      debugPrint('âŒ Failed to clear all caches: $e');
    }
  }
  
  /// Get cache statistics
  CacheStatistics getCacheStatistics() {
    final hitRate = _cacheHits + _cacheMisses > 0 
        ? _cacheHits / (_cacheHits + _cacheMisses) 
        : 0.0;
    
    return CacheStatistics(
      memoryCacheSize: _memoryCacheSize,
      imageCacheSize: _imageCacheSize,
      memoryCacheEntries: _memoryCache.length,
      imageCacheEntries: _imageCache.length,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      hitRate: hitRate,
    );
  }
  
  /// Cache data in memory
  Future<void> _cacheInMemory(String key, dynamic data, DateTime expiresAt) async {
    final dataSize = _calculateDataSize(data);
    
    // Check if we need to free up space
    if (_memoryCacheSize + dataSize > maxMemoryCacheSize) {
      await _cleanupMemoryCache();
    }
    
    _memoryCache[key] = CacheEntry(
      data: data,
      expiresAt: expiresAt,
      size: dataSize,
    );
    
    _memoryCacheSize += dataSize;
  }
  
  /// Get data from memory cache
  T? _getFromMemory<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    
    // Check if expired
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _memoryCache.remove(key);
      _memoryCacheSize -= entry.size;
      return null;
    }
    
    return entry.data as T?;
  }
  
  /// Cache data to disk
  Future<void> _cacheToDisk(String key, dynamic data, DateTime expiresAt) async {
    if (_prefs == null) return;
    
    final cacheData = {
      'data': data,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
    
    await _prefs!.setString('cache_$key', jsonEncode(cacheData));
  }
  
  /// Get data from disk cache
  Future<T?> _getFromDisk<T>(String key) async {
    if (_prefs == null) return null;
    
    final cachedString = _prefs!.getString('cache_$key');
    if (cachedString == null) return null;
    
    try {
      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(cacheData['expiresAt']);
      
      // Check if expired
      if (DateTime.now().isAfter(expiresAt)) {
        await _prefs!.remove('cache_$key');
        return null;
      }
      
      return cacheData['data'] as T?;
      
    } catch (e) {
      debugPrint('âŒ Failed to parse cached data: $e');
      await _prefs!.remove('cache_$key');
      return null;
    }
  }
  
  /// Cache image to disk
  Future<void> _cacheImageToDisk(String key, Uint8List imageData) async {
    if (_prefs == null) return;
    
    final base64Data = base64Encode(imageData);
    final cacheData = {
      'data': base64Data,
      'expiresAt': DateTime.now().add(imageCacheDuration).millisecondsSinceEpoch,
    };
    
    await _prefs!.setString('image_$key', jsonEncode(cacheData));
  }
  
  /// Get image from disk cache
  Future<Uint8List?> _getImageFromDisk(String key) async {
    if (_prefs == null) return null;
    
    final cachedString = _prefs!.getString('image_$key');
    if (cachedString == null) return null;
    
    try {
      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(cacheData['expiresAt']);
      
      // Check if expired
      if (DateTime.now().isAfter(expiresAt)) {
        await _prefs!.remove('image_$key');
        return null;
      }
      
      return base64Decode(cacheData['data']);
      
    } catch (e) {
      debugPrint('âŒ Failed to parse cached image: $e');
      await _prefs!.remove('image_$key');
      return null;
    }
  }
  
  /// Generate cache key
  String _generateCacheKey(String key) {
    final bytes = utf8.encode(key);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Calculate data size
  int _calculateDataSize(dynamic data) {
    try {
      final jsonString = jsonEncode(data);
      return utf8.encode(jsonString).length;
    } catch (e) {
      return 1024; // Default size estimate
    }
  }
  
  /// Cleanup memory cache
  Future<void> _cleanupMemoryCache() async {
    final entries = _memoryCache.entries.toList();
    entries.sort((a, b) => a.value.expiresAt.compareTo(b.value.expiresAt));
    
    // Remove expired entries first
    final now = DateTime.now();
    for (final entry in entries) {
      if (now.isAfter(entry.value.expiresAt)) {
        _memoryCache.remove(entry.key);
        _memoryCacheSize -= entry.value.size;
      }
    }
    
    // If still over limit, remove oldest entries
    while (_memoryCacheSize > maxMemoryCacheSize * 0.8 && _memoryCache.isNotEmpty) {
      final oldestKey = entries.first.key;
      final oldestEntry = _memoryCache.remove(oldestKey);
      if (oldestEntry != null) {
        _memoryCacheSize -= oldestEntry.size;
      }
      entries.removeAt(0);
    }
  }
  
  /// Cleanup image cache
  Future<void> _cleanupImageCache() async {
    // Remove half of the images to free up space
    final keys = _imageCache.keys.toList();
    final keysToRemove = keys.take(keys.length ~/ 2);
    
    for (final key in keysToRemove) {
      final imageData = _imageCache.remove(key);
      if (imageData != null) {
        _imageCacheSize -= imageData.length;
      }
    }
  }
  
  /// Remove from disk cache
  Future<void> _removeFromDisk(String key) async {
    if (_prefs == null) return;
    
    await _prefs!.remove('cache_$key');
    await _prefs!.remove('image_$key');
  }
  
  /// Clear disk cache
  Future<void> _clearDiskCache() async {
    if (_prefs == null) return;
    
    final keys = _prefs!.getKeys();
    final cacheKeys = keys.where((key) => key.startsWith('cache_') || key.startsWith('image_'));
    
    for (final key in cacheKeys) {
      await _prefs!.remove(key);
    }
  }
  
  /// Load cache statistics
  void _loadCacheStatistics() {
    if (_prefs == null) return;
    
    _cacheHits = _prefs!.getInt('cache_hits') ?? 0;
    _cacheMisses = _prefs!.getInt('cache_misses') ?? 0;
  }
  
  /// Save cache statistics
  Future<void> _saveCacheStatistics() async {
    if (_prefs == null) return;
    
    await _prefs!.setInt('cache_hits', _cacheHits);
    await _prefs!.setInt('cache_misses', _cacheMisses);
  }
  
  /// Setup periodic cleanup
  void _setupPeriodicCleanup() {
    Timer.periodic(const Duration(hours: 1), (timer) {
      _cleanupMemoryCache();
      _saveCacheStatistics();
    });
  }
}

// Enums and Data Classes

enum CacheLevel {
  memory,
  disk,
  both,
}

class CacheEntry {
  final dynamic data;
  final DateTime expiresAt;
  final int size;

  const CacheEntry({
    required this.data,
    required this.expiresAt,
    required this.size,
  });
}

class CacheStatistics {
  final int memoryCacheSize;
  final int imageCacheSize;
  final int memoryCacheEntries;
  final int imageCacheEntries;
  final int cacheHits;
  final int cacheMisses;
  final double hitRate;

  const CacheStatistics({
    required this.memoryCacheSize,
    required this.imageCacheSize,
    required this.memoryCacheEntries,
    required this.imageCacheEntries,
    required this.cacheHits,
    required this.cacheMisses,
    required this.hitRate,
  });
}

