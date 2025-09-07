// Media Backfill Service - Fix existing posts with bad URLs
// Detects and fixes data URIs, gs:// paths, and missing tokens

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MediaBackfillService {
  static MediaBackfillService? _instance;
  static MediaBackfillService get instance => _instance ??= MediaBackfillService._internal();
  
  MediaBackfillService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Run complete media backfill for all collections
  Future<BackfillResult> runCompleteBackfill() async {
    try {
      debugPrint('ðŸ”„ Starting complete media backfill...');
      
      final results = <String, CollectionBackfillResult>{};
      
      // Backfill posts
      results['posts'] = await backfillCollection(
        collection: 'posts',
        mediaFields: ['imageUrls', 'videoUrls', 'documentUrls'],
      );
      
      // Backfill stories
      results['stories'] = await backfillCollection(
        collection: 'stories',
        mediaFields: ['mediaUrl'],
      );
      
      // Backfill user profiles
      results['users'] = await backfillCollection(
        collection: 'users',
        mediaFields: ['profileImageUrl', 'coverImageUrl'],
      );
      
      final totalFixed = results.values
          .map((r) => r.fixedDocuments)
          .fold(0, (sum, count) => sum + count);
      
      debugPrint('âœ… Complete backfill finished: $totalFixed documents fixed');
      
      return BackfillResult(
        collectionResults: results,
        totalFixed: totalFixed,
        success: true,
      );
      
    } catch (e) {
      debugPrint('âŒ Complete backfill failed: $e');
      return BackfillResult(
        collectionResults: {},
        totalFixed: 0,
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Backfill media URLs in a specific collection
  Future<CollectionBackfillResult> backfillCollection({
    required String collection,
    required List<String> mediaFields,
    int batchSize = 50,
  }) async {
    try {
      debugPrint('ðŸ”„ Backfilling collection: $collection');
      
      int totalProcessed = 0;
      int totalFixed = 0;
      final errors = <String>[];
      
      QuerySnapshot? lastSnapshot;
      
      while (true) {
        Query query = _firestore.collection(collection).limit(batchSize);
        
        if (lastSnapshot != null && lastSnapshot.docs.isNotEmpty) {
          query = query.startAfterDocument(lastSnapshot.docs.last);
        }
        
        final snapshot = await query.get();
        
        if (snapshot.docs.isEmpty) break;
        
        final batch = _firestore.batch();
        int batchFixed = 0;
        
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            
            final updates = <String, dynamic>{};
            bool needsUpdate = false;
            
            // Process each media field
            for (final field in mediaFields) {
              final fieldValue = data[field];
              
              if (fieldValue is String) {
                // Single URL field
                final fixedUrl = await _fixMediaUrl(fieldValue);
                if (fixedUrl != null && fixedUrl != fieldValue) {
                  updates[field] = fixedUrl;
                  needsUpdate = true;
                }
              } else if (fieldValue is List) {
                // Array of URLs
                final fixedUrls = <String>[];
                bool arrayChanged = false;
                
                for (final url in fieldValue) {
                  if (url is String) {
                    final fixedUrl = await _fixMediaUrl(url);
                    if (fixedUrl != null) {
                      fixedUrls.add(fixedUrl);
                      if (fixedUrl != url) {
                        arrayChanged = true;
                      }
                    } else {
                      fixedUrls.add(url);
                    }
                  } else {
                    fixedUrls.add(url);
                  }
                }
                
                if (arrayChanged) {
                  updates[field] = fixedUrls;
                  needsUpdate = true;
                }
              }
            }
            
            if (needsUpdate) {
              batch.update(doc.reference, updates);
              batchFixed++;
            }
            
            totalProcessed++;
            
          } catch (e) {
            errors.add('Error processing document ${doc.id}: $e');
          }
        }
        
        if (batchFixed > 0) {
          await batch.commit();
          totalFixed += batchFixed;
          debugPrint('âœ… Fixed batch: $batchFixed documents in $collection');
        }
        
        lastSnapshot = snapshot;
        
        // Add delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      debugPrint('âœ… Collection backfill complete: $collection ($totalFixed/$totalProcessed)');
      
      return CollectionBackfillResult(
        collection: collection,
        processedDocuments: totalProcessed,
        fixedDocuments: totalFixed,
        errors: errors,
      );
      
    } catch (e) {
      debugPrint('âŒ Collection backfill failed: $collection - $e');
      return CollectionBackfillResult(
        collection: collection,
        processedDocuments: 0,
        fixedDocuments: 0,
        errors: [e.toString()],
      );
    }
  }
  
  /// Fix a single media URL
  Future<String?> _fixMediaUrl(String url) async {
    try {
      // Check if URL needs fixing
      final urlType = _detectUrlType(url);
      
      switch (urlType) {
        case MediaUrlType.dataUri:
          return await _fixDataUri(url);
        case MediaUrlType.gsPath:
          return await _fixGsPath(url);
        case MediaUrlType.missingToken:
          return await _fixMissingToken(url);
        case MediaUrlType.wrongBucket:
          return _fixWrongBucket(url);
        case MediaUrlType.valid:
          return null; // No fix needed
      }
      
    } catch (e) {
      debugPrint('âŒ Failed to fix URL: $url - $e');
      return null;
    }
  }
  
  /// Detect URL type that needs fixing
  MediaUrlType _detectUrlType(String url) {
    if (url.startsWith('data:')) {
      return MediaUrlType.dataUri;
    }
    
    if (url.startsWith('gs://')) {
      return MediaUrlType.gsPath;
    }
    
    if (url.contains('firebasestorage.googleapis.com')) {
      final uri = Uri.parse(url);
      
      // Check for wrong bucket - talowa.appspot.com is the wrong bucket
      if (url.contains('talowa.appspot.com')) {
        return MediaUrlType.wrongBucket;
      }
      
      // Check for missing token
      if (!uri.queryParameters.containsKey('token')) {
        return MediaUrlType.missingToken;
      }
      
      return MediaUrlType.valid;
    }
    
    return MediaUrlType.valid; // Assume valid for other URLs
  }
  
  /// Fix data URI by removing it (cannot be converted to proper URL)
  Future<String?> _fixDataUri(String dataUri) async {
    debugPrint('ðŸ—‘ï¸ Removing data URI (cannot be converted): ${dataUri.substring(0, 50)}...');
    
    // Data URIs cannot be converted to proper Firebase Storage URLs
    // They should be removed from the database
    return null;
  }
  
  /// Fix gs:// path by converting to download URL
  Future<String?> _fixGsPath(String gsPath) async {
    try {
      debugPrint('ðŸ”„ Converting gs:// path: $gsPath');
      
      // Extract path from gs://bucket/path format
      final uri = Uri.parse(gsPath);
      final storagePath = uri.path.substring(1); // Remove leading slash
      
      // Get download URL
      final storageRef = _storage.ref().child(storagePath);
      final downloadUrl = await storageRef.getDownloadURL();
      
      debugPrint('âœ… Converted gs:// to download URL');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('âŒ Failed to convert gs:// path: $e');
      return null;
    }
  }
  
  /// Fix missing token by regenerating download URL
  Future<String?> _fixMissingToken(String url) async {
    try {
      debugPrint('ðŸ”„ Fixing missing token: $url');
      
      // Extract storage path from URL
      final storagePath = _extractStoragePathFromUrl(url);
      if (storagePath == null) {
        debugPrint('âŒ Could not extract storage path from URL');
        return null;
      }
      
      // Get fresh download URL with token
      final storageRef = _storage.ref().child(storagePath);
      final downloadUrl = await storageRef.getDownloadURL();
      
      debugPrint('âœ… Fixed missing token');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('âŒ Failed to fix missing token: $e');
      return null;
    }
  }
  
  /// Fix wrong bucket host
  String _fixWrongBucket(String url) {
    debugPrint('ðŸ”„ Fixing wrong bucket: $url');
    
    final fixedUrl = url.replaceAll(
      'talowa.appspot.com',
      'talowa.firebasestorage.app',
    );
    
    debugPrint('âœ… Fixed bucket host');
    return fixedUrl;
  }
  
  /// Extract storage path from Firebase Storage URL
  String? _extractStoragePathFromUrl(String url) {
    try {
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
      return null;
    }
  }
  
  /// Get backfill status for a collection
  Future<BackfillStatus> getBackfillStatus(String collection) async {
    try {
      final snapshot = await _firestore.collection(collection).get();
      
      int totalDocuments = snapshot.docs.length;
      int documentsNeedingFix = 0;
      final urlTypes = <MediaUrlType, int>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        bool needsFix = false;
        
        // Check all fields for media URLs
        for (final value in data.values) {
          if (value is String && _isMediaUrl(value)) {
            final urlType = _detectUrlType(value);
            urlTypes[urlType] = (urlTypes[urlType] ?? 0) + 1;
            
            if (urlType != MediaUrlType.valid) {
              needsFix = true;
            }
          } else if (value is List) {
            for (final item in value) {
              if (item is String && _isMediaUrl(item)) {
                final urlType = _detectUrlType(item);
                urlTypes[urlType] = (urlTypes[urlType] ?? 0) + 1;
                
                if (urlType != MediaUrlType.valid) {
                  needsFix = true;
                }
              }
            }
          }
        }
        
        if (needsFix) {
          documentsNeedingFix++;
        }
      }
      
      return BackfillStatus(
        collection: collection,
        totalDocuments: totalDocuments,
        documentsNeedingFix: documentsNeedingFix,
        urlTypeBreakdown: urlTypes,
        backfillComplete: documentsNeedingFix == 0,
      );
      
    } catch (e) {
      debugPrint('âŒ Failed to get backfill status for $collection: $e');
      return BackfillStatus(
        collection: collection,
        totalDocuments: 0,
        documentsNeedingFix: 0,
        urlTypeBreakdown: {},
        backfillComplete: false,
        error: e.toString(),
      );
    }
  }
  
  /// Check if string is a media URL
  bool _isMediaUrl(String value) {
    return value.startsWith('http') || 
           value.startsWith('gs://') || 
           value.startsWith('data:');
  }
}

// Enums and Data Classes

enum MediaUrlType {
  valid,
  dataUri,
  gsPath,
  missingToken,
  wrongBucket,
}

class BackfillResult {
  final Map<String, CollectionBackfillResult> collectionResults;
  final int totalFixed;
  final bool success;
  final String? error;

  const BackfillResult({
    required this.collectionResults,
    required this.totalFixed,
    required this.success,
    this.error,
  });
}

class CollectionBackfillResult {
  final String collection;
  final int processedDocuments;
  final int fixedDocuments;
  final List<String> errors;

  const CollectionBackfillResult({
    required this.collection,
    required this.processedDocuments,
    required this.fixedDocuments,
    required this.errors,
  });
}

class BackfillStatus {
  final String collection;
  final int totalDocuments;
  final int documentsNeedingFix;
  final Map<MediaUrlType, int> urlTypeBreakdown;
  final bool backfillComplete;
  final String? error;

  const BackfillStatus({
    required this.collection,
    required this.totalDocuments,
    required this.documentsNeedingFix,
    required this.urlTypeBreakdown,
    required this.backfillComplete,
    this.error,
  });
}

