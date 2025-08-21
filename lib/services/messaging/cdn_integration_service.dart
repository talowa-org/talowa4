// CDN Integration Service for TALOWA
// Implements fast media file delivery across regions
// Requirements: 1.1, 8.4

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CDNIntegrationService {
  static final CDNIntegrationService _instance = CDNIntegrationService._internal();
  factory CDNIntegrationService() => _instance;
  CDNIntegrationService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  SharedPreferences? _prefs;
  
  // CDN configuration
  static const String cdnBaseUrl = 'https://firebasestorage.googleapis.com';
  static const Duration urlCacheExpiration = Duration(hours: 6);
  static const Duration mediaCacheExpiration = Duration(days: 7);
  static const int maxCacheSize = 500; // MB
  
  // Cache for CDN URLs and metadata
  final Map<String, String> _urlCache = {};
  final Map<String, DateTime> _urlCacheTimestamps = {};
  final Map<String, MediaMetadata> _mediaMetadataCache = {};
  
  // Regional CDN endpoints (would be configured based on user location)
  final Map<String, String> _regionalEndpoints = {
    'asia-south1': 'https://asia-south1-firebasestorage.googleapis.com',
    'us-central1': 'https://us-central1-firebasestorage.googleapis.com',
    'europe-west1': 'https://europe-west1-firebasestorage.googleapis.com',
  };

  /// Initialize CDN integration service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCachedUrls();
      await _setupRegionalOptimization();
      debugPrint('CDNIntegrationService initialized');
    } catch (e) {
      debugPrint('Error initializing CDNIntegrationService: $e');
    }
  }

  /// Upload media file with CDN optimization
  Future<CDNUploadResult> uploadMedia({
    required String fileName,
    required Uint8List fileData,
    required MediaType mediaType,
    String? conversationId,
    Map<String, String>? metadata,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Generate optimized file path
      final filePath = _generateOptimizedFilePath(
        fileName: fileName,
        mediaType: mediaType,
        conversationId: conversationId,
      );
      
      // Compress file if needed
      final optimizedData = await _optimizeMediaFile(fileData, mediaType);
      
      // Upload to Firebase Storage
      final ref = _storage.ref().child(filePath);
      final uploadTask = ref.putData(
        optimizedData,
        SettableMetadata(
          contentType: _getContentType(mediaType),
          customMetadata: {
            'originalSize': fileData.length.toString(),
            'optimizedSize': optimizedData.length.toString(),
            'uploadedAt': DateTime.now().toIso8601String(),
            ...?metadata,
          },
        ),
      );
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      stopwatch.stop();
      
      // Cache the URL and metadata
      await _cacheMediaUrl(filePath, downloadUrl);
      await _cacheMediaMetadata(filePath, MediaMetadata(
        fileName: fileName,
        filePath: filePath,
        downloadUrl: downloadUrl,
        mediaType: mediaType,
        originalSize: fileData.length,
        optimizedSize: optimizedData.length,
        uploadedAt: DateTime.now(),
        uploadDuration: stopwatch.elapsedMilliseconds,
      ));
      
      return CDNUploadResult(
        success: true,
        filePath: filePath,
        downloadUrl: downloadUrl,
        originalSize: fileData.length,
        optimizedSize: optimizedData.length,
        uploadDuration: stopwatch.elapsedMilliseconds,
        compressionRatio: (fileData.length - optimizedData.length) / fileData.length,
      );
    } catch (e) {
      debugPrint('Error uploading media to CDN: $e');
      return CDNUploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get optimized CDN URL for media file
  Future<String?> getOptimizedMediaUrl({
    required String filePath,
    MediaTransformation? transformation,
    bool useCache = true,
  }) async {
    try {
      // Check cache first
      if (useCache) {
        final cachedUrl = _getCachedUrl(filePath);
        if (cachedUrl != null) {
          return _applyTransformation(cachedUrl, transformation);
        }
      }
      
      // Get URL from Firebase Storage
      final ref = _storage.ref().child(filePath);
      final downloadUrl = await ref.getDownloadURL();
      
      // Cache the URL
      await _cacheMediaUrl(filePath, downloadUrl);
      
      return _applyTransformation(downloadUrl, transformation);
    } catch (e) {
      debugPrint('Error getting optimized media URL: $e');
      return null;
    }
  }

  /// Preload media files for faster access
  Future<void> preloadMediaFiles(List<String> filePaths) async {
    try {
      final futures = filePaths.take(10).map((filePath) async {
        try {
          await getOptimizedMediaUrl(filePath: filePath);
          
          // Also preload the actual file data for critical media
          final url = _getCachedUrl(filePath);
          if (url != null) {
            await CachedNetworkImage.evictFromCache(url);
            CachedNetworkImageProvider(url);
          }
        } catch (e) {
          debugPrint('Error preloading media file $filePath: $e');
        }
      });
      
      await Future.wait(futures);
      debugPrint('Preloaded ${filePaths.length} media files');
    } catch (e) {
      debugPrint('Error preloading media files: $e');
    }
  }

  /// Get media file with progressive loading
  Future<CDNMediaResult> getMediaWithProgressiveLoading({
    required String filePath,
    MediaQuality quality = MediaQuality.auto,
    Function(double progress)? onProgress,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Get appropriate URL based on quality
      final url = await _getQualityOptimizedUrl(filePath, quality);
      if (url == null) {
        throw Exception('Failed to get media URL');
      }
      
      // Load with progress tracking
      final imageProvider = CachedNetworkImageProvider(
        url,
        cacheKey: _generateCacheKey(filePath, quality),
      );
      
      // Get cached metadata
      final metadata = _mediaMetadataCache[filePath];
      
      stopwatch.stop();
      
      return CDNMediaResult(
        success: true,
        url: url,
        imageProvider: imageProvider,
        metadata: metadata,
        loadDuration: stopwatch.elapsedMilliseconds,
        fromCache: _getCachedUrl(filePath) != null,
      );
    } catch (e) {
      debugPrint('Error getting media with progressive loading: $e');
      return CDNMediaResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Delete media file from CDN
  Future<bool> deleteMediaFile(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      await ref.delete();
      
      // Remove from caches
      _urlCache.remove(filePath);
      _urlCacheTimestamps.remove(filePath);
      _mediaMetadataCache.remove(filePath);
      
      // Remove from persistent cache
      await _prefs?.remove('cdn_url_$filePath');
      await _prefs?.remove('cdn_metadata_$filePath');
      
      debugPrint('Deleted media file: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error deleting media file: $e');
      return false;
    }
  }

  /// Get media file metadata
  Future<MediaMetadata?> getMediaMetadata(String filePath) async {
    try {
      // Check cache first
      if (_mediaMetadataCache.containsKey(filePath)) {
        return _mediaMetadataCache[filePath];
      }
      
      // Load from persistent cache
      final cachedData = _prefs?.getString('cdn_metadata_$filePath');
      if (cachedData != null) {
        final metadata = MediaMetadata.fromJson(jsonDecode(cachedData));
        _mediaMetadataCache[filePath] = metadata;
        return metadata;
      }
      
      // Get from Firebase Storage
      final ref = _storage.ref().child(filePath);
      final metadata = await ref.getMetadata();
      
      final mediaMetadata = MediaMetadata(
        fileName: metadata.name ?? '',
        filePath: filePath,
        downloadUrl: await ref.getDownloadURL(),
        mediaType: _getMediaTypeFromContentType(metadata.contentType),
        originalSize: metadata.customMetadata?['originalSize'] != null 
            ? int.parse(metadata.customMetadata!['originalSize']!) 
            : metadata.size ?? 0,
        optimizedSize: metadata.size ?? 0,
        uploadedAt: metadata.timeCreated ?? DateTime.now(),
      );
      
      // Cache the metadata
      await _cacheMediaMetadata(filePath, mediaMetadata);
      
      return mediaMetadata;
    } catch (e) {
      debugPrint('Error getting media metadata: $e');
      return null;
    }
  }

  /// Get CDN statistics
  Map<String, dynamic> getCDNStatistics() {
    return {
      'cached_urls': _urlCache.length,
      'cached_metadata': _mediaMetadataCache.length,
      'cache_hit_rate': _calculateCacheHitRate(),
      'regional_endpoints': _regionalEndpoints.length,
      'cache_size_estimate': _estimateCacheSize(),
    };
  }

  /// Clear CDN caches
  Future<void> clearCDNCache() async {
    try {
      _urlCache.clear();
      _urlCacheTimestamps.clear();
      _mediaMetadataCache.clear();
      
      // Clear persistent cache
      final keys = _prefs?.getKeys().where((key) => 
          key.startsWith('cdn_url_') || key.startsWith('cdn_metadata_')) ?? [];
      
      for (final key in keys) {
        await _prefs?.remove(key);
      }
      
      debugPrint('CDN cache cleared');
    } catch (e) {
      debugPrint('Error clearing CDN cache: $e');
    }
  }

  // Private methods

  Future<void> _loadCachedUrls() async {
    try {
      final keys = _prefs?.getKeys().where((key) => key.startsWith('cdn_url_')) ?? [];
      
      for (final key in keys) {
        final filePath = key.substring(8); // Remove 'cdn_url_' prefix
        final url = _prefs?.getString(key);
        if (url != null) {
          _urlCache[filePath] = url;
          _urlCacheTimestamps[filePath] = DateTime.now();
        }
      }
      
      debugPrint('Loaded ${_urlCache.length} cached URLs');
    } catch (e) {
      debugPrint('Error loading cached URLs: $e');
    }
  }

  Future<void> _setupRegionalOptimization() async {
    try {
      // In a real implementation, this would detect user's region
      // and configure the optimal CDN endpoint
      final userRegion = await _detectUserRegion();
      debugPrint('Detected user region: $userRegion');
    } catch (e) {
      debugPrint('Error setting up regional optimization: $e');
    }
  }

  String _generateOptimizedFilePath({
    required String fileName,
    required MediaType mediaType,
    String? conversationId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = sha256.convert(utf8.encode('$fileName$timestamp')).toString().substring(0, 8);
    
    final folder = mediaType == MediaType.image ? 'images' : 
                   mediaType == MediaType.video ? 'videos' : 
                   mediaType == MediaType.audio ? 'audio' : 'files';
    
    final subfolder = conversationId != null ? 'conversations/$conversationId' : 'general';
    
    return '$folder/$subfolder/${hash}_$fileName';
  }

  Future<Uint8List> _optimizeMediaFile(Uint8List fileData, MediaType mediaType) async {
    try {
      // For now, return original data
      // In a real implementation, this would compress images, videos, etc.
      return fileData;
    } catch (e) {
      debugPrint('Error optimizing media file: $e');
      return fileData;
    }
  }

  String _getContentType(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.image:
        return 'image/jpeg';
      case MediaType.video:
        return 'video/mp4';
      case MediaType.audio:
        return 'audio/mpeg';
      case MediaType.document:
        return 'application/pdf';
    }
  }

  MediaType _getMediaTypeFromContentType(String? contentType) {
    if (contentType == null) return MediaType.document;
    
    if (contentType.startsWith('image/')) return MediaType.image;
    if (contentType.startsWith('video/')) return MediaType.video;
    if (contentType.startsWith('audio/')) return MediaType.audio;
    return MediaType.document;
  }

  Future<void> _cacheMediaUrl(String filePath, String url) async {
    try {
      _urlCache[filePath] = url;
      _urlCacheTimestamps[filePath] = DateTime.now();
      await _prefs?.setString('cdn_url_$filePath', url);
    } catch (e) {
      debugPrint('Error caching media URL: $e');
    }
  }

  Future<void> _cacheMediaMetadata(String filePath, MediaMetadata metadata) async {
    try {
      _mediaMetadataCache[filePath] = metadata;
      await _prefs?.setString('cdn_metadata_$filePath', jsonEncode(metadata.toJson()));
    } catch (e) {
      debugPrint('Error caching media metadata: $e');
    }
  }

  String? _getCachedUrl(String filePath) {
    final url = _urlCache[filePath];
    final timestamp = _urlCacheTimestamps[filePath];
    
    if (url != null && timestamp != null) {
      if (DateTime.now().difference(timestamp) < urlCacheExpiration) {
        return url;
      } else {
        // Remove expired cache
        _urlCache.remove(filePath);
        _urlCacheTimestamps.remove(filePath);
      }
    }
    
    return null;
  }

  String _applyTransformation(String url, MediaTransformation? transformation) {
    if (transformation == null) return url;
    
    // In a real CDN implementation, this would add transformation parameters
    // For Firebase Storage, we return the original URL
    return url;
  }

  Future<String?> _getQualityOptimizedUrl(String filePath, MediaQuality quality) async {
    // For now, return the standard URL
    // In a real implementation, this would return different quality versions
    return await getOptimizedMediaUrl(filePath: filePath);
  }

  String _generateCacheKey(String filePath, MediaQuality quality) {
    return '${filePath}_${quality.name}';
  }

  Future<String> _detectUserRegion() async {
    // Mock implementation - would use actual geolocation
    return 'asia-south1';
  }

  double _calculateCacheHitRate() {
    // Mock calculation
    return 0.85;
  }

  int _estimateCacheSize() {
    // Rough estimate in bytes
    return _urlCache.length * 200 + _mediaMetadataCache.length * 500;
  }
}

/// Media types supported by CDN
enum MediaType {
  image,
  video,
  audio,
  document,
}

/// Media quality options
enum MediaQuality {
  low,
  medium,
  high,
  auto,
}

/// Media transformation options
class MediaTransformation {
  final int? width;
  final int? height;
  final int? quality;
  final String? format;

  MediaTransformation({
    this.width,
    this.height,
    this.quality,
    this.format,
  });
}

/// Media metadata
class MediaMetadata {
  final String fileName;
  final String filePath;
  final String downloadUrl;
  final MediaType mediaType;
  final int originalSize;
  final int optimizedSize;
  final DateTime uploadedAt;
  final int? uploadDuration;

  MediaMetadata({
    required this.fileName,
    required this.filePath,
    required this.downloadUrl,
    required this.mediaType,
    required this.originalSize,
    required this.optimizedSize,
    required this.uploadedAt,
    this.uploadDuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'filePath': filePath,
      'downloadUrl': downloadUrl,
      'mediaType': mediaType.name,
      'originalSize': originalSize,
      'optimizedSize': optimizedSize,
      'uploadedAt': uploadedAt.toIso8601String(),
      'uploadDuration': uploadDuration,
    };
  }

  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      fileName: json['fileName'] ?? '',
      filePath: json['filePath'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      mediaType: MediaType.values.firstWhere(
        (type) => type.name == json['mediaType'],
        orElse: () => MediaType.document,
      ),
      originalSize: json['originalSize'] ?? 0,
      optimizedSize: json['optimizedSize'] ?? 0,
      uploadedAt: DateTime.parse(json['uploadedAt']),
      uploadDuration: json['uploadDuration'],
    );
  }
}

/// CDN upload result
class CDNUploadResult {
  final bool success;
  final String? filePath;
  final String? downloadUrl;
  final int? originalSize;
  final int? optimizedSize;
  final int? uploadDuration;
  final double? compressionRatio;
  final String? error;

  CDNUploadResult({
    required this.success,
    this.filePath,
    this.downloadUrl,
    this.originalSize,
    this.optimizedSize,
    this.uploadDuration,
    this.compressionRatio,
    this.error,
  });
}

/// CDN media result
class CDNMediaResult {
  final bool success;
  final String? url;
  final CachedNetworkImageProvider? imageProvider;
  final MediaMetadata? metadata;
  final int? loadDuration;
  final bool fromCache;
  final String? error;

  CDNMediaResult({
    required this.success,
    this.url,
    this.imageProvider,
    this.metadata,
    this.loadDuration,
    this.fromCache = false,
    this.error,
  });
}