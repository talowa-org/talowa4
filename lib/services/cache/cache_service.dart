// Cache Service for TALOWA
// Simple in-memory cache with expiration support
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheItem> _cache = {};
  Timer? _cleanupTimer;

  void initialize() {
    // Start periodic cleanup every 5 minutes
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanup();
    });
  }

  /// Store data in cache with optional expiry
  Future<void> set(
    String key,
    dynamic data, {
    Duration? expiry,
  }) async {
    try {
      final expiryTime = expiry != null 
          ? DateTime.now().add(expiry)
          : null;

      _cache[key] = CacheItem(
        data: data,
        createdAt: DateTime.now(),
        expiryTime: expiryTime,
      );

      debugPrint('✅ Cached data for key: $key');
    } catch (e) {
      debugPrint('❌ Failed to cache data for key $key: $e');
    }
  }

  /// Retrieve data from cache
  T? get<T>(String key) {
    try {
      final item = _cache[key];
      if (item == null) return null;

      // Check if expired
      if (item.isExpired) {
        _cache.remove(key);
        return null;
      }

      return item.data as T?;
    } catch (e) {
      debugPrint('❌ Failed to get cached data for key $key: $e');
      return null;
    }
  }

  /// Check if key exists and is not expired
  bool has(String key) {
    final item = _cache[key];
    if (item == null) return false;
    
    if (item.isExpired) {
      _cache.remove(key);
      return false;
    }
    
    return true;
  }

  /// Remove specific key from cache
  Future<void> remove(String key) async {
    _cache.remove(key);
    debugPrint('✅ Removed cached data for key: $key');
  }

  /// Clear all cache
  Future<void> clear() async {
    _cache.clear();
    debugPrint('✅ Cleared all cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    int expiredCount = 0;
    int totalSize = 0;

    for (final item in _cache.values) {
      if (item.isExpired) expiredCount++;
      
      try {
        final jsonString = jsonEncode(item.data);
        totalSize += jsonString.length;
      } catch (e) {
        // Skip items that can't be serialized
      }
    }

    return {
      'total_items': _cache.length,
      'expired_items': expiredCount,
      'active_items': _cache.length - expiredCount,
      'estimated_size_bytes': totalSize,
    };
  }

  /// Clean up expired items
  void _cleanup() {
    final keysToRemove = <String>[];
    
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      debugPrint('✅ Cleaned up ${keysToRemove.length} expired cache items');
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

class CacheItem {
  final dynamic data;
  final DateTime createdAt;
  final DateTime? expiryTime;

  CacheItem({
    required this.data,
    required this.createdAt,
    this.expiryTime,
  });

  bool get isExpired {
    if (expiryTime == null) return false;
    return DateTime.now().isAfter(expiryTime!);
  }

  Duration get age => DateTime.now().difference(createdAt);
}