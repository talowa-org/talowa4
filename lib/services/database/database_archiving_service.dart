// Database Archiving Service for TALOWA Social Feed System
// Data lifecycle management and cleanup strategies

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Database Archiving Service for data lifecycle management
class DatabaseArchivingService {
  static DatabaseArchivingService? _instance;
  static DatabaseArchivingService get instance => _instance ??= DatabaseArchivingService._internal();
  
  DatabaseArchivingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Archiving configuration
  static const Duration _archiveInterval = Duration(hours: 24);
  static const Duration _postArchiveThreshold = Duration(days: 90);
  static const Duration _messageArchiveThreshold = Duration(days: 30);
  static const Duration _analyticsArchiveThreshold = Duration(days: 180);
  static const Duration _logArchiveThreshold = Duration(days: 7);
  static const int _batchSize = 100;
  
  // Archiving tracking
  final Map<String, DateTime> _lastArchive = {};
  final Map<String, int> _archivedCounts = {};
  Timer? _archiveTimer;
  
  bool _isInitialized = false;

  /// Initialize archiving service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initializing Database Archiving Service...');
      
      // Load archiving history
      await _loadArchivingHistory();
      
      // Start automated archiving timer
      _startAutomatedArchiving();
      
      _isInitialized = true;
      debugPrint('✅ Database Archiving Service initialized');
      
    } catch (error) {
      debugPrint('❌ Failed to initialize Database Archiving Service: $error');
      rethrow;
    }
  }

  /// Load archiving history from database
  Future<void> _loadArchivingHistory() async {
    try {
      final doc = await _firestore.collection('system').doc('archiving_status').get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        if (data['lastArchive'] != null) {
          (data['lastArchive'] as Map<String, dynamic>).forEach((collection, timestamp) {
            _lastArchive[collection] = (timestamp as Timestamp).toDate();
          });
        }
        
        if (data['archivedCounts'] != null) {
          (data['archivedCounts'] as Map<String, dynamic>).forEach((collection, count) {
            _archivedCounts[collection] = count as int;
          });
        }
      }
      
      debugPrint('📊 Loaded archiving history for ${_lastArchive.length} collections');
      
    } catch (error) {
      debugPrint('❌ Error loading archiving history: $error');
    }
  }

  /// Start automated archiving timer
  void _startAutomatedArchiving() {
    _archiveTimer = Timer.periodic(_archiveInterval, (_) {
      _performAutomatedArchiving();
    });
    
    debugPrint('⏰ Automated archiving scheduled every ${_archiveInterval.inHours} hours');
  }

  /// Perform automated archiving of all collections
  Future<void> _performAutomatedArchiving() async {
    try {
      debugPrint('🔄 Starting automated archiving...');
      
      // Archive old posts
      await archiveOldDocuments('posts', _postArchiveThreshold);
      
      // Archive old messages
      await archiveOldDocuments('messages', _messageArchiveThreshold);
      
      // Archive old analytics
      await archiveOldDocuments('analytics', _analyticsArchiveThreshold);
      
      // Archive old logs
      await archiveOldDocuments('logs', _logArchiveThreshold);
      
      // Clean up temporary data
      await cleanupTemporaryData();
      
      // Update collection statistics
      await updateCollectionStatistics();
      
      debugPrint('✅ Automated archiving completed');
      
    } catch (error) {
      debugPrint('❌ Automated archiving failed: $error');
    }
  }

  /// Archive old documents from a collection
  Future<ArchivingResult> archiveOldDocuments(String collection, Duration threshold) async {
    if (!_isInitialized) await initialize();

    debugPrint('🔄 Archiving old documents from: $collection');
    
    final stopwatch = Stopwatch()..start();
    final cutoffDate = DateTime.now().subtract(threshold);
    int archivedCount = 0;
    int totalSize = 0;
    
    try {
      // Query old documents in batches
      Query query = _firestore
          .collection(collection)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(_batchSize);
      
      QuerySnapshot snapshot;
      
      do {
        snapshot = await query.get();
        
        if (snapshot.docs.isNotEmpty) {
          // Archive batch of documents
          final batchResult = await _archiveBatch(collection, snapshot.docs);
          archivedCount += batchResult.documentCount;
          totalSize += batchResult.sizeBytes;
          
          // Update query for next batch
          query = _firestore
              .collection(collection)
              .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
              .startAfterDocument(snapshot.docs.last)
              .limit(_batchSize);
        }
        
      } while (snapshot.docs.length == _batchSize);
      
      // Update tracking
      _lastArchive[collection] = DateTime.now();
      _archivedCounts[collection] = (_archivedCounts[collection] ?? 0) + archivedCount;
      
      // Save archiving status
      await _saveArchivingStatus();
      
      final result = ArchivingResult(
        collection: collection,
        documentCount: archivedCount,
        sizeBytes: totalSize,
        durationMs: stopwatch.elapsedMilliseconds,
        threshold: threshold,
      );
      
      debugPrint('✅ Archived $archivedCount documents from $collection (${stopwatch.elapsedMilliseconds}ms)');
      
      return result;
      
    } catch (error) {
      debugPrint('❌ Error archiving $collection: $error');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Archive a batch of documents
  Future<BatchArchiveResult> _archiveBatch(String collection, List<QueryDocumentSnapshot> docs) async {
    final batch = _firestore.batch();
    int sizeBytes = 0;
    
    // Move documents to archive collection
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      data['archivedAt'] = FieldValue.serverTimestamp();
      data['originalCollection'] = collection;
      
      // Calculate approximate size
      sizeBytes += _calculateDocumentSize(data);
      
      // Add to archive collection
      final archiveRef = _firestore.collection('${collection}_archive').doc(doc.id);
      batch.set(archiveRef, data);
      
      // Delete from original collection
      batch.delete(doc.reference);
    }
    
    // Commit batch
    await batch.commit();
    
    return BatchArchiveResult(
      documentCount: docs.length,
      sizeBytes: sizeBytes,
    );
  }

  /// Clean up temporary data
  Future<void> cleanupTemporaryData() async {
    try {
      debugPrint('🔄 Cleaning up temporary data...');
      
      // Clean up expired phone verifications
      await _cleanupExpiredVerifications();
      
      // Clean up old health check records
      await _cleanupHealthCheckRecords();
      
      // Clean up expired cache entries
      await _cleanupExpiredCacheEntries();
      
      debugPrint('✅ Temporary data cleanup completed');
      
    } catch (error) {
      debugPrint('❌ Error cleaning up temporary data: $error');
    }
  }

  /// Clean up expired phone verifications
  Future<void> _cleanupExpiredVerifications() async {
    final cutoffDate = DateTime.now().subtract(const Duration(hours: 1));
    
    final snapshot = await _firestore
        .collection('phone_verifications')
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      debugPrint('🗑️ Cleaned up ${snapshot.docs.length} expired phone verifications');
    }
  }

  /// Clean up old health check records
  Future<void> _cleanupHealthCheckRecords() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 1));
    
    final snapshot = await _firestore
        .collection('health_check')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      debugPrint('🗑️ Cleaned up ${snapshot.docs.length} old health check records');
    }
  }

  /// Clean up expired cache entries
  Future<void> _cleanupExpiredCacheEntries() async {
    final cutoffDate = DateTime.now().subtract(const Duration(hours: 6));
    
    final snapshot = await _firestore
        .collection('cache_entries')
        .where('expiresAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      debugPrint('🗑️ Cleaned up ${snapshot.docs.length} expired cache entries');
    }
  }

  /// Update collection statistics
  Future<void> updateCollectionStatistics() async {
    try {
      debugPrint('🔄 Updating collection statistics...');
      
      final collections = ['posts', 'users', 'messages', 'conversations', 'live_streams'];
      final stats = <String, CollectionStats>{};
      
      for (final collection in collections) {
        final snapshot = await _firestore.collection(collection).count().get();
        final archiveSnapshot = await _firestore.collection('${collection}_archive').count().get();
        
        stats[collection] = CollectionStats(
          collection: collection,
          activeDocuments: snapshot.count ?? 0,
          archivedDocuments: archiveSnapshot.count ?? 0,
          lastUpdated: DateTime.now(),
        );
      }
      
      // Save statistics
      await _firestore.collection('system').doc('collection_stats').set({
        'stats': stats.map((key, value) => MapEntry(key, value.toMap())),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Collection statistics updated');
      
    } catch (error) {
      debugPrint('❌ Error updating collection statistics: $error');
    }
  }

  /// Restore archived documents
  Future<void> restoreArchivedDocuments(String collection, List<String> documentIds) async {
    if (!_isInitialized) await initialize();

    debugPrint('🔄 Restoring ${documentIds.length} documents to $collection');
    
    try {
      final batch = _firestore.batch();
      
      for (final docId in documentIds) {
        // Get archived document
        final archiveDoc = await _firestore
            .collection('${collection}_archive')
            .doc(docId)
            .get();
        
        if (archiveDoc.exists) {
          final data = archiveDoc.data() as Map<String, dynamic>;
          
          // Remove archive metadata
          data.remove('archivedAt');
          data.remove('originalCollection');
          
          // Restore to original collection
          batch.set(_firestore.collection(collection).doc(docId), data);
          
          // Delete from archive
          batch.delete(archiveDoc.reference);
        }
      }
      
      await batch.commit();
      
      debugPrint('✅ Restored ${documentIds.length} documents to $collection');
      
    } catch (error) {
      debugPrint('❌ Error restoring documents: $error');
      rethrow;
    }
  }

  /// Calculate approximate document size
  int _calculateDocumentSize(Map<String, dynamic> data) {
    // Simple approximation based on JSON string length
    try {
      return data.toString().length;
    } catch (error) {
      return 1000; // Default estimate
    }
  }

  /// Save archiving status to database
  Future<void> _saveArchivingStatus() async {
    await _firestore.collection('system').doc('archiving_status').set({
      'lastArchive': _lastArchive.map((key, value) => MapEntry(key, Timestamp.fromDate(value))),
      'archivedCounts': _archivedCounts,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Get archiving statistics
  Map<String, dynamic> getArchivingStatistics() {
    return {
      'lastArchive': _lastArchive.map((key, value) => MapEntry(key, value.toIso8601String())),
      'archivedCounts': Map.from(_archivedCounts),
      'thresholds': {
        'posts': _postArchiveThreshold.inDays,
        'messages': _messageArchiveThreshold.inDays,
        'analytics': _analyticsArchiveThreshold.inDays,
        'logs': _logArchiveThreshold.inDays,
      },
    };
  }

  /// Shutdown archiving service
  Future<void> shutdown() async {
    try {
      debugPrint('🔄 Shutting down Database Archiving Service...');
      
      // Cancel archive timer
      _archiveTimer?.cancel();
      
      // Clear tracking data
      _lastArchive.clear();
      _archivedCounts.clear();
      
      _isInitialized = false;
      
      debugPrint('✅ Database Archiving Service shutdown complete');
      
    } catch (error) {
      debugPrint('❌ Error during archiving service shutdown: $error');
    }
  }
}

/// Archiving result model
class ArchivingResult {
  final String collection;
  final int documentCount;
  final int sizeBytes;
  final int durationMs;
  final Duration threshold;

  ArchivingResult({
    required this.collection,
    required this.documentCount,
    required this.sizeBytes,
    required this.durationMs,
    required this.threshold,
  });
}

/// Batch archive result model
class BatchArchiveResult {
  final int documentCount;
  final int sizeBytes;

  BatchArchiveResult({
    required this.documentCount,
    required this.sizeBytes,
  });
}

/// Collection statistics model
class CollectionStats {
  final String collection;
  final int activeDocuments;
  final int archivedDocuments;
  final DateTime lastUpdated;

  CollectionStats({
    required this.collection,
    required this.activeDocuments,
    required this.archivedDocuments,
    required this.lastUpdated,
  });

  int get totalDocuments => activeDocuments + archivedDocuments;
  double get archivePercentage => totalDocuments > 0 ? (archivedDocuments / totalDocuments) * 100 : 0;

  Map<String, dynamic> toMap() {
    return {
      'collection': collection,
      'activeDocuments': activeDocuments,
      'archivedDocuments': archivedDocuments,
      'totalDocuments': totalDocuments,
      'archivePercentage': archivePercentage,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}