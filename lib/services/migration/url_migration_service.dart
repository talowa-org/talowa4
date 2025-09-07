// URL Migration Service - Fix bad Firebase Storage URLs in Firestore
// Migrates from incorrect bucket URLs to proper ones

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UrlMigrationService {
  static UrlMigrationService? _instance;
  static UrlMigrationService get instance => _instance ??= UrlMigrationService._internal();
  
  UrlMigrationService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Migration configuration
  static const String badBucketHost = 'talowa.appspot.com';
  static const String correctBucketHost = 'talowa.firebasestorage.app';
  static const int batchSize = 50;
  
  /// Run complete URL migration for all collections
  Future<MigrationResult> runCompleteMigration() async {
    try {
      debugPrint('ðŸ”„ Starting complete URL migration...');
      
      final results = <String, CollectionMigrationResult>{};
      
      // Migrate posts
      results['posts'] = await migrateCollection(
        collection: 'posts',
        urlFields: ['imageUrls', 'videoUrls', 'documentUrls'],
        arrayFields: ['imageUrls', 'videoUrls', 'documentUrls'],
      );
      
      // Migrate stories
      results['stories'] = await migrateCollection(
        collection: 'stories',
        urlFields: ['mediaUrl', 'thumbnailUrl'],
      );
      
      // Migrate user profiles
      results['users'] = await migrateCollection(
        collection: 'users',
        urlFields: ['profileImageUrl', 'coverImageUrl'],
      );
      
      // Migrate comments with attachments
      results['comments'] = await migrateNestedCollection(
        parentCollection: 'posts',
        nestedCollection: 'comments',
        urlFields: ['attachmentUrl'],
      );
      
      final totalMigrated = results.values
          .map((r) => r.migratedDocuments)
          .fold(0, (sum, count) => sum + count);
      
      debugPrint('âœ… Complete migration finished: $totalMigrated documents migrated');
      
      return MigrationResult(
        collectionResults: results,
        totalMigrated: totalMigrated,
        success: true,
      );
      
    } catch (e) {
      debugPrint('âŒ Complete migration failed: $e');
      return MigrationResult(
        collectionResults: {},
        totalMigrated: 0,
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Migrate URLs in a specific collection
  Future<CollectionMigrationResult> migrateCollection({
    required String collection,
    required List<String> urlFields,
    List<String>? arrayFields,
  }) async {
    try {
      debugPrint('ðŸ”„ Migrating collection: $collection');
      
      int totalProcessed = 0;
      int totalMigrated = 0;
      final errors = <String>[];
      
      // Process in batches
      QuerySnapshot? lastSnapshot;
      
      while (true) {
        Query query = _firestore.collection(collection).limit(batchSize);
        
        if (lastSnapshot != null && lastSnapshot.docs.isNotEmpty) {
          query = query.startAfterDocument(lastSnapshot.docs.last);
        }
        
        final snapshot = await query.get();
        
        if (snapshot.docs.isEmpty) break;
        
        final batch = _firestore.batch();
        int batchMigrated = 0;
        
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            
            final updates = <String, dynamic>{};
            bool needsUpdate = false;
            
            // Process each URL field
            for (final field in urlFields) {
              if (arrayFields?.contains(field) == true) {
                // Handle array fields
                final urls = data[field] as List<dynamic>?;
                if (urls != null && urls.isNotEmpty) {
                  final migratedUrls = urls.map((url) {
                    if (url is String && _needsMigration(url)) {
                      needsUpdate = true;
                      return _migrateUrl(url);
                    }
                    return url;
                  }).toList();
                  
                  if (needsUpdate) {
                    updates[field] = migratedUrls;
                  }
                }
              } else {
                // Handle single URL fields
                final url = data[field] as String?;
                if (url != null && _needsMigration(url)) {
                  updates[field] = _migrateUrl(url);
                  needsUpdate = true;
                }
              }
            }
            
            if (needsUpdate) {
              batch.update(doc.reference, updates);
              batchMigrated++;
            }
            
            totalProcessed++;
            
          } catch (e) {
            errors.add('Error processing document ${doc.id}: $e');
          }
        }
        
        if (batchMigrated > 0) {
          await batch.commit();
          totalMigrated += batchMigrated;
          debugPrint('âœ… Migrated batch: $batchMigrated documents in $collection');
        }
        
        lastSnapshot = snapshot;
        
        // Add delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      debugPrint('âœ… Collection migration complete: $collection ($totalMigrated/$totalProcessed)');
      
      return CollectionMigrationResult(
        collection: collection,
        processedDocuments: totalProcessed,
        migratedDocuments: totalMigrated,
        errors: errors,
      );
      
    } catch (e) {
      debugPrint('âŒ Collection migration failed: $collection - $e');
      return CollectionMigrationResult(
        collection: collection,
        processedDocuments: 0,
        migratedDocuments: 0,
        errors: [e.toString()],
      );
    }
  }
  
  /// Migrate URLs in nested collections
  Future<CollectionMigrationResult> migrateNestedCollection({
    required String parentCollection,
    required String nestedCollection,
    required List<String> urlFields,
    List<String>? arrayFields,
  }) async {
    try {
      debugPrint('ðŸ”„ Migrating nested collection: $parentCollection/$nestedCollection');
      
      int totalProcessed = 0;
      int totalMigrated = 0;
      final errors = <String>[];
      
      // Get all parent documents
      final parentDocs = await _firestore.collection(parentCollection).get();
      
      for (final parentDoc in parentDocs.docs) {
        try {
          // Process nested collection
          final nestedQuery = parentDoc.reference
              .collection(nestedCollection)
              .limit(batchSize);
          
          QuerySnapshot? lastSnapshot;
          
          while (true) {
            Query query = nestedQuery;
            
            if (lastSnapshot != null && lastSnapshot.docs.isNotEmpty) {
              query = query.startAfterDocument(lastSnapshot.docs.last);
            }
            
            final snapshot = await query.get();
            
            if (snapshot.docs.isEmpty) break;
            
            final batch = _firestore.batch();
            int batchMigrated = 0;
            
            for (final doc in snapshot.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) continue;
                
                final updates = <String, dynamic>{};
                bool needsUpdate = false;
                
                // Process each URL field
                for (final field in urlFields) {
                  if (arrayFields?.contains(field) == true) {
                    // Handle array fields
                    final urls = data[field] as List<dynamic>?;
                    if (urls != null && urls.isNotEmpty) {
                      final migratedUrls = urls.map((url) {
                        if (url is String && _needsMigration(url)) {
                          needsUpdate = true;
                          return _migrateUrl(url);
                        }
                        return url;
                      }).toList();
                      
                      if (needsUpdate) {
                        updates[field] = migratedUrls;
                      }
                    }
                  } else {
                    // Handle single URL fields
                    final url = data[field] as String?;
                    if (url != null && _needsMigration(url)) {
                      updates[field] = _migrateUrl(url);
                      needsUpdate = true;
                    }
                  }
                }
                
                if (needsUpdate) {
                  batch.update(doc.reference, updates);
                  batchMigrated++;
                }
                
                totalProcessed++;
                
              } catch (e) {
                errors.add('Error processing nested document ${doc.id}: $e');
              }
            }
            
            if (batchMigrated > 0) {
              await batch.commit();
              totalMigrated += batchMigrated;
            }
            
            lastSnapshot = snapshot;
            
            // Add delay to avoid rate limiting
            await Future.delayed(const Duration(milliseconds: 50));
          }
          
        } catch (e) {
          errors.add('Error processing parent document ${parentDoc.id}: $e');
        }
      }
      
      debugPrint('âœ… Nested collection migration complete: $parentCollection/$nestedCollection ($totalMigrated/$totalProcessed)');
      
      return CollectionMigrationResult(
        collection: '$parentCollection/$nestedCollection',
        processedDocuments: totalProcessed,
        migratedDocuments: totalMigrated,
        errors: errors,
      );
      
    } catch (e) {
      debugPrint('âŒ Nested collection migration failed: $parentCollection/$nestedCollection - $e');
      return CollectionMigrationResult(
        collection: '$parentCollection/$nestedCollection',
        processedDocuments: 0,
        migratedDocuments: 0,
        errors: [e.toString()],
      );
    }
  }
  
  /// Check if URL needs migration
  bool _needsMigration(String url) {
    return url.contains(badBucketHost);
  }
  
  /// Migrate a single URL
  String _migrateUrl(String url) {
    return url.replaceAll(badBucketHost, correctBucketHost);
  }
  
  /// Get migration status for a collection
  Future<MigrationStatus> getMigrationStatus(String collection) async {
    try {
      final snapshot = await _firestore.collection(collection).get();
      
      int totalDocuments = snapshot.docs.length;
      int documentsNeedingMigration = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        // Check if any field contains bad URLs
        bool needsMigration = false;
        for (final value in data.values) {
          if (value is String && _needsMigration(value)) {
            needsMigration = true;
            break;
          } else if (value is List) {
            for (final item in value) {
              if (item is String && _needsMigration(item)) {
                needsMigration = true;
                break;
              }
            }
            if (needsMigration) break;
          }
        }
        
        if (needsMigration) {
          documentsNeedingMigration++;
        }
      }
      
      return MigrationStatus(
        collection: collection,
        totalDocuments: totalDocuments,
        documentsNeedingMigration: documentsNeedingMigration,
        migrationComplete: documentsNeedingMigration == 0,
      );
      
    } catch (e) {
      debugPrint('âŒ Failed to get migration status for $collection: $e');
      return MigrationStatus(
        collection: collection,
        totalDocuments: 0,
        documentsNeedingMigration: 0,
        migrationComplete: false,
        error: e.toString(),
      );
    }
  }
}

// Data Classes

class MigrationResult {
  final Map<String, CollectionMigrationResult> collectionResults;
  final int totalMigrated;
  final bool success;
  final String? error;

  const MigrationResult({
    required this.collectionResults,
    required this.totalMigrated,
    required this.success,
    this.error,
  });
}

class CollectionMigrationResult {
  final String collection;
  final int processedDocuments;
  final int migratedDocuments;
  final List<String> errors;

  const CollectionMigrationResult({
    required this.collection,
    required this.processedDocuments,
    required this.migratedDocuments,
    required this.errors,
  });
}

class MigrationStatus {
  final String collection;
  final int totalDocuments;
  final int documentsNeedingMigration;
  final bool migrationComplete;
  final String? error;

  const MigrationStatus({
    required this.collection,
    required this.totalDocuments,
    required this.documentsNeedingMigration,
    required this.migrationComplete,
    this.error,
  });
}

