// Media Cache Service - Handle media caching for offline support
// Part of Task 10: Implement media handling system

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Cached media item
class CachedMediaItem {
  final String url;
  final String localPath;
  final String fileName;
  final int fileSizeBytes;
  final DateTime cachedAt;
  final DateTime? expiresAt;
  final String fileType;
  
  const CachedMediaItem({
    required this.url,
    required this.localPath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.cachedAt,
    this.expiresAt,
    required this.fileType,
  });
  
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  
  Map<String, dynamic> toJson() => {
    'url': url,
    'localPath': localPath,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    'cachedAt': cachedAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'fileType': fileType,
  };
  
  factory CachedMediaItem.fromJson(Map<String, dynamic> json) => CachedMediaItem(
    url: json['url'],
    localPath: json['localPath'],
    fileName: json['fileName'],
    fileSizeBytes: json['fileSizeBytes'],
    cachedAt: DateTime.parse(json['cachedAt']),
    expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
    fileType: json['fileType'],
  );
}

/// Media cache service for offline support
class MediaCacheService {
  static const String _cacheDirectoryName = 'media_cache';
  static const String _cacheIndexFileName = 'cache_index.json';
  static const int _maxCacheSizeBytes = 100 * 1024 * 1024; // 100MB
  static const Duration _defaultCacheExpiry = Duration(days: 7);
  
  static Directory? _cacheDirectory;
  static Map<String, CachedMediaItem> _cacheIndex = {};
  static bool _isInitialized = false;
  
  /// Initialize cache service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = Directory('${appDir.path}/$_cacheDirectoryName');
      
      // Create cache directory if it doesn't exist
      if (!await _cacheDirectory!.exists()) {
        await _cacheDirectory!.create(recursive: true);
      }
      
      // Load cache index
      await _loadCacheIndex();
      
      // Clean expired items
      await _cleanExpiredItems();
      
      _isInitialized = true;
      print('Media cache service initialized');
    } catch (e) {
      print('Error initializing media cache service: $e');
    }
  }
  
  /// Cache media from URL
  static Future<String?> cacheMedia({
    required String url,
    Duration? expiry,
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();
    
    try {
      final urlHash = _generateUrlHash(url);
      final existingItem = _cacheIndex[urlHash];
      
      // Return existing cached file if valid and not forcing refresh
      if (!forceRefresh && existingItem != null && !existingItem.isExpired) {
        final file = File(existingItem.localPath);
        if (await file.exists()) {
          return existingItem.localPath;
        }
      }
      
      // Download and cache the file
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download media: ${response.statusCode}');
      }
      
      final bytes = response.bodyBytes;
      final fileName = _generateFileName(url);
      final localPath = '${_cacheDirectory!.path}/$fileName';
      
      // Write file to cache
      final file = File(localPath);
      await file.writeAsBytes(bytes);
      
      // Update cache index
      final cacheItem = CachedMediaItem(
        url: url,
        localPath: localPath,
        fileName: fileName,
        fileSizeBytes: bytes.length,
        cachedAt: DateTime.now(),
        expiresAt: expiry != null ? DateTime.now().add(expiry) : DateTime.now().add(_defaultCacheExpiry),
        fileType: _getFileTypeFromUrl(url),
      );
      
      _cacheIndex[urlHash] = cacheItem;
      await _saveCacheIndex();
      
      // Check cache size and clean if necessary
      await _enforceMaxCacheSize();
      
      return localPath;
    } catch (e) {
      print('Error caching media: $e');
      return null;
    }
  }
  
  /// Get cached media path
  static Future<String?> getCachedMediaPath(String url) async {
    await _ensureInitialized();
    
    final urlHash = _generateUrlHash(url);
    final cacheItem = _cacheIndex[urlHash];
    
    if (cacheItem == null || cacheItem.isExpired) {
      return null;
    }
    
    final file = File(cacheItem.localPath);
    if (await file.exists()) {
      return cacheItem.localPath;
    } else {
      // File was deleted, remove from index
      _cacheIndex.remove(urlHash);
      await _saveCacheIndex();
      return null;
    }
  }
  
  /// Check if media is cached
  static Future<bool> isMediaCached(String url) async {
    final cachedPath = await getCachedMediaPath(url);
    return cachedPath != null;
  }
  
  /// Preload media for offline use
  static Future<List<String>> preloadMedia(List<String> urls) async {
    final cachedPaths = <String>[];
    
    for (final url in urls) {
      try {
        final cachedPath = await cacheMedia(url: url);
        if (cachedPath != null) {
          cachedPaths.add(cachedPath);
        }
      } catch (e) {
        print('Error preloading media $url: $e');
      }
    }
    
    return cachedPaths;
  }
  
  /// Clear specific cached media
  static Future<void> clearCachedMedia(String url) async {
    await _ensureInitialized();
    
    final urlHash = _generateUrlHash(url);
    final cacheItem = _cacheIndex[urlHash];
    
    if (cacheItem != null) {
      try {
        final file = File(cacheItem.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        
        _cacheIndex.remove(urlHash);
        await _saveCacheIndex();
      } catch (e) {
        print('Error clearing cached media: $e');
      }
    }
  }
  
  /// Clear all cached media
  static Future<void> clearAllCache() async {
    await _ensureInitialized();
    
    try {
      // Delete all cached files
      if (await _cacheDirectory!.exists()) {
        await _cacheDirectory!.delete(recursive: true);
        await _cacheDirectory!.create(recursive: true);
      }
      
      // Clear index
      _cacheIndex.clear();
      await _saveCacheIndex();
      
      print('All cached media cleared');
    } catch (e) {
      print('Error clearing all cache: $e');
    }
  }
  
  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInitialized();
    
    int totalFiles = _cacheIndex.length;
    int totalSizeBytes = 0;
    int expiredFiles = 0;
    
    for (final item in _cacheIndex.values) {
      totalSizeBytes += item.fileSizeBytes;
      if (item.isExpired) {
        expiredFiles++;
      }
    }
    
    return {
      'totalFiles': totalFiles,
      'totalSizeBytes': totalSizeBytes,
      'totalSizeMB': (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2),
      'expiredFiles': expiredFiles,
      'maxSizeMB': (_maxCacheSizeBytes / (1024 * 1024)).toStringAsFixed(2),
      'usagePercentage': ((totalSizeBytes / _maxCacheSizeBytes) * 100).toStringAsFixed(1),
    };
  }
  
  /// Clean expired cache items
  static Future<void> cleanExpiredItems() async {
    await _ensureInitialized();
    await _cleanExpiredItems();
  }
  
  /// Set cache expiry for specific URL
  static Future<void> setCacheExpiry(String url, Duration expiry) async {
    await _ensureInitialized();
    
    final urlHash = _generateUrlHash(url);
    final cacheItem = _cacheIndex[urlHash];
    
    if (cacheItem != null) {
      final updatedItem = CachedMediaItem(
        url: cacheItem.url,
        localPath: cacheItem.localPath,
        fileName: cacheItem.fileName,
        fileSizeBytes: cacheItem.fileSizeBytes,
        cachedAt: cacheItem.cachedAt,
        expiresAt: DateTime.now().add(expiry),
        fileType: cacheItem.fileType,
      );
      
      _cacheIndex[urlHash] = updatedItem;
      await _saveCacheIndex();
    }
  }
  
  // Private helper methods
  
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
  
  static String _generateUrlHash(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  static String _generateFileName(String url) {
    final urlHash = _generateUrlHash(url);
    final extension = _getFileExtensionFromUrl(url);
    return '$urlHash$extension';
  }
  
  static String _getFileExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot != -1 && lastDot < path.length - 1) {
        return path.substring(lastDot);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return '.cache'; // Default extension
  }
  
  static String _getFileTypeFromUrl(String url) {
    final extension = _getFileExtensionFromUrl(url).toLowerCase();
    
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
      return 'image';
    } else if (['.pdf', '.doc', '.docx', '.txt'].contains(extension)) {
      return 'document';
    } else if (['.mp4', '.mov', '.avi'].contains(extension)) {
      return 'video';
    }
    
    return 'unknown';
  }
  
  static Future<void> _loadCacheIndex() async {
    try {
      final indexFile = File('${_cacheDirectory!.path}/$_cacheIndexFileName');
      
      if (await indexFile.exists()) {
        final jsonString = await indexFile.readAsString();
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        
        _cacheIndex = jsonData.map((key, value) => 
          MapEntry(key, CachedMediaItem.fromJson(value as Map<String, dynamic>))
        );
      }
    } catch (e) {
      print('Error loading cache index: $e');
      _cacheIndex = {};
    }
  }
  
  static Future<void> _saveCacheIndex() async {
    try {
      final indexFile = File('${_cacheDirectory!.path}/$_cacheIndexFileName');
      final jsonData = _cacheIndex.map((key, value) => MapEntry(key, value.toJson()));
      final jsonString = json.encode(jsonData);
      
      await indexFile.writeAsString(jsonString);
    } catch (e) {
      print('Error saving cache index: $e');
    }
  }
  
  static Future<void> _cleanExpiredItems() async {
    final expiredKeys = <String>[];
    
    for (final entry in _cacheIndex.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
        
        // Delete the cached file
        try {
          final file = File(entry.value.localPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Error deleting expired cache file: $e');
        }
      }
    }
    
    // Remove expired items from index
    for (final key in expiredKeys) {
      _cacheIndex.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      await _saveCacheIndex();
      print('Cleaned ${expiredKeys.length} expired cache items');
    }
  }
  
  static Future<void> _enforceMaxCacheSize() async {
    int totalSize = _cacheIndex.values.fold(0, (sum, item) => sum + item.fileSizeBytes);
    
    if (totalSize <= _maxCacheSizeBytes) return;
    
    // Sort by cached date (oldest first)
    final sortedItems = _cacheIndex.entries.toList()
      ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));
    
    // Remove oldest items until under size limit
    for (final entry in sortedItems) {
      if (totalSize <= _maxCacheSizeBytes) break;
      
      try {
        final file = File(entry.value.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        
        totalSize -= entry.value.fileSizeBytes;
        _cacheIndex.remove(entry.key);
      } catch (e) {
        print('Error removing cache file for size limit: $e');
      }
    }
    
    await _saveCacheIndex();
    print('Enforced cache size limit, removed ${sortedItems.length - _cacheIndex.length} items');
  }
}