// Enhanced Media Service - Proper Firebase Storage URL handling
// Fixes CORS issues and ensures proper media loading

import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EnhancedMediaService {
  static EnhancedMediaService? _instance;
  static EnhancedMediaService get instance => _instance ??= EnhancedMediaService._internal();
  
  EnhancedMediaService._internal();
  
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // URL cache to avoid repeated getDownloadURL calls
  final Map<String, String> _urlCache = {};
  final Map<String, DateTime> _urlCacheTimestamps = {};
  static const Duration _urlCacheExpiry = Duration(hours: 1);
  
  /// Upload media file and return storage path (not URL)
  Future<MediaUploadResult> uploadMedia({
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
    required String folder, // e.g., 'posts', 'stories', 'profiles'
    String? userId,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('ðŸ“¤ Uploading media: $fileName to $folder/');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = userId ?? currentUser?.uid ?? 'anonymous';
      
      // Create storage path (not URL)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$folder/$uid/$timestamp-$fileName';
      
      // Create storage reference
      final storageRef = _storage.ref().child(storagePath);
      
      // Set metadata
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': fileName,
          'folder': folder,
        },
      );
      
      // Upload file
      final uploadTask = storageRef.putData(fileBytes, metadata);
      
      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });
      
      // Wait for completion
      final snapshot = await uploadTask;
      
      // Get file size
      final fileSize = fileBytes.length;
      
      debugPrint('âœ… Media uploaded successfully: $storagePath');
      
      return MediaUploadResult(
        storagePath: storagePath,
        fileName: fileName,
        contentType: contentType,
        fileSize: fileSize,
        uploadedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('âŒ Media upload failed: $e');
      rethrow;
    }
  }
  
  /// Get download URL from storage path with caching and CORS handling
  Future<String> getDownloadUrl(String storagePath) async {
    try {
      // Check cache first
      final cachedUrl = _getCachedUrl(storagePath);
      if (cachedUrl != null) {
        return _processCorsUrl(cachedUrl);
      }

      debugPrint('ðŸ”— Getting download URL for: $storagePath');
      
      // Check if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('âš ï¸ Warning: User not authenticated when requesting media');
      }

      // Get fresh URL from Firebase
      final storageRef = _storage.ref().child(storagePath);
      final downloadUrl = await storageRef.getDownloadURL();

      // Cache the URL
      _cacheUrl(storagePath, downloadUrl);

      // Process URL for CORS compatibility
      final processedUrl = _processCorsUrl(downloadUrl);

      debugPrint('âœ… Download URL obtained: ${processedUrl.substring(0, 100)}...');

      return processedUrl;

    } catch (e) {
      debugPrint('âŒ Failed to get download URL for $storagePath: $e');
      rethrow;
    }
  }

  /// Process URL for CORS compatibility
  String _processCorsUrl(String url) {
    try {
      // For Firebase Storage URLs, ensure proper parameters
      if (url.contains('firebasestorage') || url.contains('firebase') && url.contains('storage')) {
        final uri = Uri.parse(url);
        final newUri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'alt': 'media',
          // Preserve existing token if present
          if (uri.queryParameters.containsKey('token'))
            'token': uri.queryParameters['token']!,
        });
        final processedUrl = newUri.toString();
        debugPrint('ðŸ”„ Processed URL: ${processedUrl.substring(0, min(processedUrl.length, 100))}...');
        return processedUrl;
      }

      return url;
    } catch (e) {
      debugPrint('âŒ Error processing CORS URL: $e');
      return url; // Return original URL if processing fails
    }
  }
  
  /// Get multiple download URLs efficiently
  Future<Map<String, String>> getMultipleDownloadUrls(List<String> storagePaths) async {
    try {
      final results = <String, String>{};
      final futures = <Future<void>>[];
      
      for (final path in storagePaths) {
        futures.add(
          getDownloadUrl(path).then((url) {
            results[path] = url;
          }).catchError((error) {
            debugPrint('âŒ Failed to get URL for $path: $error');
            // Don't add to results if failed
          }),
        );
      }
      
      await Future.wait(futures);
      return results;
      
    } catch (e) {
      debugPrint('âŒ Failed to get multiple download URLs: $e');
      return {};
    }
  }
  
  /// Check if media exists at storage path
  Future<bool> mediaExists(String storagePath) async {
    try {
      final storageRef = _storage.ref().child(storagePath);
      await storageRef.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Delete media from storage
  Future<void> deleteMedia(String storagePath) async {
    try {
      debugPrint('ðŸ—‘ï¸ Deleting media: $storagePath');
      
      final storageRef = _storage.ref().child(storagePath);
      await storageRef.delete();
      
      // Remove from cache
      _urlCache.remove(storagePath);
      _urlCacheTimestamps.remove(storagePath);
      
      debugPrint('âœ… Media deleted successfully');
      
    } catch (e) {
      debugPrint('âŒ Failed to delete media: $e');
      rethrow;
    }
  }
  
  /// Get media metadata
  Future<MediaMetadata?> getMediaMetadata(String storagePath) async {
    try {
      final storageRef = _storage.ref().child(storagePath);
      final metadata = await storageRef.getMetadata();
      
      return MediaMetadata(
        storagePath: storagePath,
        contentType: metadata.contentType ?? 'application/octet-stream',
        size: metadata.size ?? 0,
        timeCreated: metadata.timeCreated,
        updated: metadata.updated,
        customMetadata: metadata.customMetadata ?? {},
      );
      
    } catch (e) {
      debugPrint('âŒ Failed to get media metadata: $e');
      return null;
    }
  }
  
  /// Migrate bad URLs in Firestore documents
  Future<void> migrateBadUrls({
    required String collection,
    required String urlField,
    int batchSize = 100,
  }) async {
    try {
      debugPrint('ðŸ”„ Starting URL migration for $collection.$urlField');
      
      final query = _firestore.collection(collection).limit(batchSize);
      QuerySnapshot snapshot = await query.get();
      
      int totalMigrated = 0;
      
      while (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        int batchCount = 0;
        
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          
          final currentUrl = data[urlField] as String?;
          if (currentUrl == null) continue;
          
          // Check if URL needs migration
          if (currentUrl.contains('talowa.appspot.com')) {
           final correctedUrl = currentUrl.replaceAll(
             'talowa.appspot.com',
             'talowa.firebasestorage.app',
           );
             
             batch.update(doc.reference, {urlField: correctedUrl});
            batchCount++;
            
            debugPrint('ðŸ”„ Migrating: ${doc.id}');
          }
        }
        
        if (batchCount > 0) {
          await batch.commit();
          totalMigrated += batchCount;
          debugPrint('âœ… Migrated batch: $batchCount documents');
        }
        
        // Get next batch
        if (snapshot.docs.length < batchSize) break;
        
        final lastDoc = snapshot.docs.last;
        snapshot = await query.startAfterDocument(lastDoc).get();
      }
      
      debugPrint('âœ… Migration complete: $totalMigrated documents migrated');
      
    } catch (e) {
      debugPrint('âŒ Migration failed: $e');
      rethrow;
    }
  }
  
  /// Convert attachment URLs to storage paths
  String? urlToStoragePath(String url) {
    try {
      // Extract storage path from Firebase Storage URL
      final uri = Uri.parse(url);
      
      if (uri.host.contains('firebasestorage.googleapis.com')) {
        // Format: https://firebasestorage.googleapis.com/v0/b/bucket/o/path?alt=media&token=...
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 4 && pathSegments[0] == 'v0' && pathSegments[1] == 'b') {
          final encodedPath = pathSegments[3];
          return Uri.decodeComponent(encodedPath);
        }
      }
      
      return null;
      
    } catch (e) {
      debugPrint('âŒ Failed to extract storage path from URL: $e');
      return null;
    }
  }
  
  /// Get cached URL if still valid
  String? _getCachedUrl(String storagePath) {
    final cachedUrl = _urlCache[storagePath];
    final timestamp = _urlCacheTimestamps[storagePath];
    
    if (cachedUrl != null && timestamp != null) {
      final age = DateTime.now().difference(timestamp);
      if (age < _urlCacheExpiry) {
        return cachedUrl;
      } else {
        // Remove expired cache
        _urlCache.remove(storagePath);
        _urlCacheTimestamps.remove(storagePath);
      }
    }
    
    return null;
  }
  
  /// Cache URL with timestamp
  void _cacheUrl(String storagePath, String url) {
    _urlCache[storagePath] = url;
    _urlCacheTimestamps[storagePath] = DateTime.now();
    
    // Clean up old cache entries periodically
    if (_urlCache.length > 1000) {
      _cleanupCache();
    }
  }
  
  /// Clean up expired cache entries
  void _cleanupCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _urlCacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > _urlCacheExpiry) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _urlCache.remove(key);
      _urlCacheTimestamps.remove(key);
    }
    
    debugPrint('ðŸ§¹ Cleaned up ${expiredKeys.length} expired cache entries');
  }
  
  /// Clear all cached URLs
  void clearCache() {
    _urlCache.clear();
    _urlCacheTimestamps.clear();
    debugPrint('ðŸ§¹ Media URL cache cleared');
  }
}

// Data Classes

class MediaUploadResult {
  final String storagePath;
  final String fileName;
  final String contentType;
  final int fileSize;
  final DateTime uploadedAt;

  const MediaUploadResult({
    required this.storagePath,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
    required this.uploadedAt,
  });

  Map<String, dynamic> toJson() => {
    'storagePath': storagePath,
    'fileName': fileName,
    'contentType': contentType,
    'fileSize': fileSize,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) => MediaUploadResult(
    storagePath: json['storagePath'],
    fileName: json['fileName'],
    contentType: json['contentType'],
    fileSize: json['fileSize'],
    uploadedAt: DateTime.parse(json['uploadedAt']),
  );
}

class MediaMetadata {
  final String storagePath;
  final String contentType;
  final int size;
  final DateTime? timeCreated;
  final DateTime? updated;
  final Map<String, String> customMetadata;

  const MediaMetadata({
    required this.storagePath,
    required this.contentType,
    required this.size,
    this.timeCreated,
    this.updated,
    required this.customMetadata,
  });
}

