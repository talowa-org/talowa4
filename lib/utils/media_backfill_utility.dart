// Media Backfill Utility - Command-line tool to fix existing media URLs
// Run this utility to migrate existing posts with bad URLs

import 'package:flutter/foundation.dart';
import '../services/media/media_backfill_service.dart';

class MediaBackfillUtility {
  static MediaBackfillUtility? _instance;
  static MediaBackfillUtility get instance => _instance ??= MediaBackfillUtility._internal();
  
  MediaBackfillUtility._internal();
  
  final MediaBackfillService _backfillService = MediaBackfillService.instance;
  
  /// Run complete media backfill with progress reporting
  Future<void> runCompleteBackfill({
    bool dryRun = false,
    bool verbose = false,
  }) async {
    try {
      debugPrint('ðŸš€ Starting Media Backfill Utility');
      debugPrint('ðŸ“Š Mode: ${dryRun ? 'DRY RUN' : 'LIVE'}');
      debugPrint('ðŸ” Verbose: $verbose');
      debugPrint('');
      
      if (dryRun) {
        await _runDryRun(verbose);
      } else {
        await _runLiveBackfill(verbose);
      }
      
    } catch (e) {
      debugPrint('âŒ Backfill utility failed: $e');
      rethrow;
    }
  }
  
  /// Run dry run to analyze what needs to be fixed
  Future<void> _runDryRun(bool verbose) async {
    debugPrint('ðŸ” ANALYZING MEDIA URLS (DRY RUN)');
    debugPrint('=' * 50);
    
    final collections = ['posts', 'stories', 'users'];
    int totalDocuments = 0;
    int totalNeedingFix = 0;
    final urlTypeStats = <MediaUrlType, int>{};
    
    for (final collection in collections) {
      debugPrint('ðŸ“‚ Analyzing collection: $collection');
      
      final status = await _backfillService.getBackfillStatus(collection);
      
      if (status.error != null) {
        debugPrint('âŒ Error analyzing $collection: ${status.error}');
        continue;
      }
      
      totalDocuments += status.totalDocuments;
      totalNeedingFix += status.documentsNeedingFix;
      
      // Aggregate URL type statistics
      for (final entry in status.urlTypeBreakdown.entries) {
        urlTypeStats[entry.key] = (urlTypeStats[entry.key] ?? 0) + entry.value;
      }
      
      debugPrint('  ðŸ“Š Total documents: ${status.totalDocuments}');
      debugPrint('  ðŸ”§ Need fixing: ${status.documentsNeedingFix}');
      debugPrint('  âœ… Already good: ${status.totalDocuments - status.documentsNeedingFix}');
      
      if (verbose && status.urlTypeBreakdown.isNotEmpty) {
        debugPrint('  ðŸ“ˆ URL type breakdown:');
        for (final entry in status.urlTypeBreakdown.entries) {
          debugPrint('    ${_getUrlTypeDescription(entry.key)}: ${entry.value}');
        }
      }
      
      debugPrint('');
    }
    
    // Summary
    debugPrint('ðŸ“‹ DRY RUN SUMMARY');
    debugPrint('=' * 50);
    debugPrint('ðŸ“Š Total documents analyzed: $totalDocuments');
    debugPrint('ðŸ”§ Total documents needing fix: $totalNeedingFix');
    debugPrint('âœ… Total documents already good: ${totalDocuments - totalNeedingFix}');
    debugPrint('ðŸ“ˆ Fix success rate: ${totalNeedingFix > 0 ? ((totalDocuments - totalNeedingFix) / totalDocuments * 100).toStringAsFixed(1) : 100}%');
    
    if (urlTypeStats.isNotEmpty) {
      debugPrint('');
      debugPrint('ðŸ·ï¸ URL TYPE BREAKDOWN:');
      for (final entry in urlTypeStats.entries) {
        debugPrint('  ${_getUrlTypeDescription(entry.key)}: ${entry.value}');
      }
    }
    
    if (totalNeedingFix > 0) {
      debugPrint('');
      debugPrint('âš ï¸  Run with dryRun=false to perform actual fixes');
    } else {
      debugPrint('');
      debugPrint('ðŸŽ‰ All media URLs are already in good shape!');
    }
  }
  
  /// Run live backfill to actually fix the URLs
  Future<void> _runLiveBackfill(bool verbose) async {
    debugPrint('ðŸ”§ FIXING MEDIA URLS (LIVE MODE)');
    debugPrint('=' * 50);
    debugPrint('âš ï¸  This will modify your database!');
    debugPrint('');
    
    final result = await _backfillService.runCompleteBackfill();
    
    if (!result.success) {
      debugPrint('âŒ Backfill failed: ${result.error}');
      return;
    }
    
    // Report results for each collection
    for (final entry in result.collectionResults.entries) {
      final collection = entry.key;
      final collectionResult = entry.value;
      
      debugPrint('ðŸ“‚ Collection: $collection');
      debugPrint('  ðŸ“Š Processed: ${collectionResult.processedDocuments}');
      debugPrint('  ðŸ”§ Fixed: ${collectionResult.fixedDocuments}');
      debugPrint('  âœ… Success rate: ${collectionResult.processedDocuments > 0 ? (collectionResult.fixedDocuments / collectionResult.processedDocuments * 100).toStringAsFixed(1) : 0}%');
      
      if (collectionResult.errors.isNotEmpty) {
        debugPrint('  âŒ Errors: ${collectionResult.errors.length}');
        if (verbose) {
          for (final error in collectionResult.errors.take(5)) {
            debugPrint('    â€¢ $error');
          }
          if (collectionResult.errors.length > 5) {
            debugPrint('    â€¢ ... and ${collectionResult.errors.length - 5} more');
          }
        }
      }
      
      debugPrint('');
    }
    
    // Overall summary
    debugPrint('ðŸŽ‰ BACKFILL COMPLETE');
    debugPrint('=' * 50);
    debugPrint('ðŸ”§ Total documents fixed: ${result.totalFixed}');
    
    final totalProcessed = result.collectionResults.values
        .map((r) => r.processedDocuments)
        .fold(0, (sum, count) => sum + count);
    
    debugPrint('ðŸ“Š Total documents processed: $totalProcessed');
    debugPrint('âœ… Overall success rate: ${totalProcessed > 0 ? (result.totalFixed / totalProcessed * 100).toStringAsFixed(1) : 0}%');
    
    final totalErrors = result.collectionResults.values
        .map((r) => r.errors.length)
        .fold(0, (sum, count) => sum + count);
    
    if (totalErrors > 0) {
      debugPrint('âš ï¸  Total errors encountered: $totalErrors');
      debugPrint('ðŸ’¡ Check logs for detailed error information');
    }
  }
  
  /// Get human-readable description for URL type
  String _getUrlTypeDescription(MediaUrlType type) {
    switch (type) {
      case MediaUrlType.valid:
        return 'âœ… Valid URLs';
      case MediaUrlType.dataUri:
        return 'ðŸ—‘ï¸  Data URIs (will be removed)';
      case MediaUrlType.gsPath:
        return 'ðŸ”„ gs:// paths (will be converted)';
      case MediaUrlType.missingToken:
        return 'ðŸ”‘ Missing tokens (will be refreshed)';
      case MediaUrlType.wrongBucket:
        return 'ðŸª£ Wrong bucket (will be corrected)';
    }
  }
  
  /// Check specific collection status
  Future<void> checkCollectionStatus(String collection) async {
    try {
      debugPrint('ðŸ” Checking collection: $collection');
      debugPrint('=' * 30);
      
      final status = await _backfillService.getBackfillStatus(collection);
      
      if (status.error != null) {
        debugPrint('âŒ Error: ${status.error}');
        return;
      }
      
      debugPrint('ðŸ“Š Total documents: ${status.totalDocuments}');
      debugPrint('ðŸ”§ Need fixing: ${status.documentsNeedingFix}');
      debugPrint('âœ… Already good: ${status.totalDocuments - status.documentsNeedingFix}');
      debugPrint('ðŸ“ˆ Health score: ${status.totalDocuments > 0 ? ((status.totalDocuments - status.documentsNeedingFix) / status.totalDocuments * 100).toStringAsFixed(1) : 100}%');
      
      if (status.urlTypeBreakdown.isNotEmpty) {
        debugPrint('');
        debugPrint('ðŸ·ï¸ URL breakdown:');
        for (final entry in status.urlTypeBreakdown.entries) {
          debugPrint('  ${_getUrlTypeDescription(entry.key)}: ${entry.value}');
        }
      }
      
      debugPrint('');
      debugPrint(status.backfillComplete 
          ? 'ðŸŽ‰ Collection is healthy!' 
          : 'âš ï¸  Collection needs backfill');
      
    } catch (e) {
      debugPrint('âŒ Failed to check collection status: $e');
    }
  }
  
  /// Fix specific collection
  Future<void> fixCollection(String collection) async {
    try {
      debugPrint('ðŸ”§ Fixing collection: $collection');
      debugPrint('=' * 30);
      
      final result = await _backfillService.backfillCollection(
        collection: collection,
        mediaFields: _getMediaFieldsForCollection(collection),
      );
      
      debugPrint('ðŸ“Š Processed: ${result.processedDocuments}');
      debugPrint('ðŸ”§ Fixed: ${result.fixedDocuments}');
      debugPrint('âœ… Success rate: ${result.processedDocuments > 0 ? (result.fixedDocuments / result.processedDocuments * 100).toStringAsFixed(1) : 0}%');
      
      if (result.errors.isNotEmpty) {
        debugPrint('âŒ Errors: ${result.errors.length}');
        for (final error in result.errors.take(3)) {
          debugPrint('  â€¢ $error');
        }
        if (result.errors.length > 3) {
          debugPrint('  â€¢ ... and ${result.errors.length - 3} more');
        }
      }
      
    } catch (e) {
      debugPrint('âŒ Failed to fix collection: $e');
    }
  }
  
  /// Get media fields for a specific collection
  List<String> _getMediaFieldsForCollection(String collection) {
    switch (collection) {
      case 'posts':
        return ['imageUrls', 'videoUrls', 'documentUrls'];
      case 'stories':
        return ['mediaUrl'];
      case 'users':
        return ['profileImageUrl', 'coverImageUrl'];
      default:
        return ['imageUrls', 'videoUrls', 'documentUrls']; // Default
    }
  }
}

// Usage examples:
// 
// // Check status of all collections
// await MediaBackfillUtility.instance.runCompleteBackfill(dryRun: true, verbose: true);
//
// // Fix all collections
// await MediaBackfillUtility.instance.runCompleteBackfill(dryRun: false, verbose: true);
//
// // Check specific collection
// await MediaBackfillUtility.instance.checkCollectionStatus('posts');
//
// // Fix specific collection
// await MediaBackfillUtility.instance.fixCollection('posts');

