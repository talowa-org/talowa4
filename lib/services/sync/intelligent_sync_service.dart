// Intelligent Sync Service for TALOWA
// Implements Task 22: Add sync and conflict resolution - Intelligent Sync

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../social_feed/offline_sync_service.dart';
import 'sync_conflict_resolver.dart';
import '../../core/database/local_database.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';

class IntelligentSyncService {
  static final IntelligentSyncService _instance = IntelligentSyncService._internal();
  factory IntelligentSyncService() => _instance;
  IntelligentSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineSyncService _offlineSync = OfflineSyncService();
  final SyncConflictResolver _conflictResolver = SyncConflictResolver();
  final LocalDatabase _localDb = LocalDatabase();
  
  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  final StreamController<SyncProgress> _syncProgressController = StreamController<SyncProgress>.broadcast();
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  SyncConfiguration _config = SyncConfiguration.defaultConfig();
  
  // Getters for streams
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  /// Initialize the intelligent sync service
  Future<void> initialize() async {
    try {
      debugPrint('Initializing Intelligent Sync Service');
      
      // Load sync configuration
      await _loadSyncConfiguration();
      
      // Start connectivity monitoring
      _startConnectivityMonitoring();
      
      // Schedule periodic sync
      _schedulePeriodicSync();
      
      // Perform initial sync if online
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        _performIntelligentSync();
      }
      
      debugPrint('Intelligent Sync Service initialized');
    } catch (e) {
      debugPrint('Error initializing sync service: $e');
    }
  }

  /// Perform intelligent synchronization
  Future<SyncResult> performSync({
    SyncMode mode = SyncMode.intelligent,
    bool forceSync = false,
  }) async {
    if (_isSyncing && !forceSync) {
      debugPrint('Sync already in progress');
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncedItems: 0,
        conflicts: 0,
      );
    }

    try {
      _isSyncing = true;
      _updateSyncStatus(SyncStatus.syncing);
      
      debugPrint('Starting intelligent sync with mode: $mode');
      
      final syncResult = await _performIntelligentSync(mode: mode);
      
      _updateSyncStatus(syncResult.success ? SyncStatus.completed : SyncStatus.failed);
      
      return syncResult;
    } catch (e) {
      debugPrint('Error during sync: $e');
      _updateSyncStatus(SyncStatus.failed);
      
      return SyncResult(
        success: false,
        message: e.toString(),
        syncedItems: 0,
        conflicts: 0,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Update sync configuration
  Future<void> updateSyncConfiguration(SyncConfiguration config) async {
    try {
      _config = config;
      await _saveSyncConfiguration();
      
      // Reschedule periodic sync with new configuration
      _schedulePeriodicSync();
      
      debugPrint('Sync configuration updated');
    } catch (e) {
      debugPrint('Error updating sync configuration: $e');
    }
  }

  /// Get current sync status
  SyncStatus getCurrentSyncStatus() {
    return _isSyncing ? SyncStatus.syncing : SyncStatus.idle;
  }

  /// Get sync statistics
  Future<SyncStatistics> getSyncStatistics() async {
    try {
      final stats = await _localDb.getSyncStatistics();
      return stats;
    } catch (e) {
      debugPrint('Error getting sync statistics: $e');
      return SyncStatistics(
        totalSyncs: 0,
        successfulSyncs: 0,
        failedSyncs: 0,
        totalConflicts: 0,
        resolvedConflicts: 0,
        lastSyncTime: null,
        averageSyncDuration: Duration.zero,
      );
    }
  }

  /// Cancel ongoing sync
  Future<void> cancelSync() async {
    if (_isSyncing) {
      _isSyncing = false;
      _updateSyncStatus(SyncStatus.cancelled);
      debugPrint('Sync cancelled by user');
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
    _syncProgressController.close();
  }

  // Private methods

  Future<SyncResult> _performIntelligentSync({SyncMode mode = SyncMode.intelligent}) async {
    final startTime = DateTime.now();
    int syncedItems = 0;
    int conflicts = 0;
    final errors = <String>[];

    try {
      // Phase 1: Analyze what needs to be synced
      _updateSyncProgress(SyncProgress(
        phase: SyncPhase.analyzing,
        progress: 0.1,
        message: 'Analyzing changes...',
      ));

      final syncPlan = await _createSyncPlan(mode);
      
      // Phase 2: Upload local changes
      _updateSyncProgress(SyncProgress(
        phase: SyncPhase.uploading,
        progress: 0.3,
        message: 'Uploading local changes...',
      ));

      final uploadResult = await _uploadLocalChanges(syncPlan);
      syncedItems += uploadResult.syncedItems;
      conflicts += uploadResult.conflicts;
      errors.addAll(uploadResult.errors);

      // Phase 3: Download remote changes
      _updateSyncProgress(SyncProgress(
        phase: SyncPhase.downloading,
        progress: 0.6,
        message: 'Downloading remote changes...',
      ));

      final downloadResult = await _downloadRemoteChanges(syncPlan);
      syncedItems += downloadResult.syncedItems;
      conflicts += downloadResult.conflicts;
      errors.addAll(downloadResult.errors);

      // Phase 4: Resolve conflicts
      if (conflicts > 0) {
        _updateSyncProgress(SyncProgress(
          phase: SyncPhase.resolving,
          progress: 0.8,
          message: 'Resolving conflicts...',
        ));

        final conflictResult = await _resolveConflicts();
        conflicts = conflictResult.resolvedConflicts;
        errors.addAll(conflictResult.errors);
      }

      // Phase 5: Finalize sync
      _updateSyncProgress(SyncProgress(
        phase: SyncPhase.finalizing,
        progress: 0.9,
        message: 'Finalizing sync...',
      ));

      await _finalizeSyncProcess(startTime, syncedItems, conflicts);

      _updateSyncProgress(SyncProgress(
        phase: SyncPhase.completed,
        progress: 1.0,
        message: 'Sync completed successfully',
      ));

      return SyncResult(
        success: errors.isEmpty,
        message: errors.isEmpty ? 'Sync completed successfully' : 'Sync completed with errors',
        syncedItems: syncedItems,
        conflicts: conflicts,
        errors: errors,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      debugPrint('Error in intelligent sync: $e');
      
      return SyncResult(
        success: false,
        message: e.toString(),
        syncedItems: syncedItems,
        conflicts: conflicts,
        errors: [...errors, e.toString()],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  Future<SyncPlan> _createSyncPlan(SyncMode mode) async {
    final plan = SyncPlan();

    try {
      // Get local changes that need to be uploaded
      final localChanges = await _localDb.getPendingChanges();
      plan.localChangesToUpload = localChanges;

      // Get last sync timestamp
      final lastSyncTime = await _localDb.getLastSyncTimestamp();
      
      // Determine what remote changes to download based on mode
      switch (mode) {
        case SyncMode.intelligent:
          // Only sync recent changes and user's content
          plan.remoteChangesToDownload = await _getIntelligentRemoteChanges(lastSyncTime);
          break;
        case SyncMode.full:
          // Sync everything
          plan.remoteChangesToDownload = await _getFullRemoteChanges(lastSyncTime);
          break;
        case SyncMode.minimal:
          // Only sync critical changes
          plan.remoteChangesToDownload = await _getMinimalRemoteChanges(lastSyncTime);
          break;
      }

      // Estimate sync size and duration
      plan.estimatedItems = plan.localChangesToUpload.length + plan.remoteChangesToDownload.length;
      plan.estimatedDuration = _estimateSyncDuration(plan.estimatedItems);

      debugPrint('Sync plan created: ${plan.estimatedItems} items, estimated ${plan.estimatedDuration.inSeconds}s');
      
      return plan;
    } catch (e) {
      debugPrint('Error creating sync plan: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getIntelligentRemoteChanges(DateTime? lastSyncTime) async {
    final changes = <Map<String, dynamic>>[];
    
    try {
      // Get changes from the last sync time or last 24 hours, whichever is more recent
      final cutoffTime = lastSyncTime ?? DateTime.now().subtract(const Duration(hours: 24));
      
      // Get posts that have been updated
      final postsQuery = _firestore
          .collection('posts')
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .limit(_config.maxItemsPerSync);
      
      final postsSnapshot = await postsQuery.get();
      
      for (final doc in postsSnapshot.docs) {
        changes.add({
          'type': 'post',
          'id': doc.id,
          'data': doc.data(),
          'action': 'update',
        });
      }

      // Get comments for those posts
      for (final postDoc in postsSnapshot.docs) {
        final commentsQuery = postDoc.reference
            .collection('comments')
            .where('updatedAt', isGreaterThan: Timestamp.fromDate(cutoffTime));
        
        final commentsSnapshot = await commentsQuery.get();
        
        for (final commentDoc in commentsSnapshot.docs) {
          changes.add({
            'type': 'comment',
            'id': commentDoc.id,
            'postId': postDoc.id,
            'data': commentDoc.data(),
            'action': 'update',
          });
        }
      }

      debugPrint('Found ${changes.length} intelligent remote changes');
      return changes;
    } catch (e) {
      debugPrint('Error getting intelligent remote changes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getFullRemoteChanges(DateTime? lastSyncTime) async {
    // Implementation for full sync - get all changes
    // This would be more comprehensive but also more resource-intensive
    return await _getIntelligentRemoteChanges(lastSyncTime);
  }

  Future<List<Map<String, dynamic>>> _getMinimalRemoteChanges(DateTime? lastSyncTime) async {
    // Implementation for minimal sync - only critical changes
    final changes = <Map<String, dynamic>>[];
    
    try {
      final cutoffTime = lastSyncTime ?? DateTime.now().subtract(const Duration(hours: 1));
      
      // Get recent posts and filter emergency locally to avoid index
      final recentQuery = _firestore
          .collection('posts')
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .limit(20);
      
      final recentSnapshot = await recentQuery.get();
      final emergencyDocs = recentSnapshot.docs
          .where((doc) => doc.data()['isEmergency'] == true)
          .take(10)
          .toList();
      
      for (final doc in emergencyDocs) {
        changes.add({
          'type': 'post',
          'id': doc.id,
          'data': doc.data(),
          'action': 'update',
        });
      }

      debugPrint('Found ${changes.length} minimal remote changes');
      return changes;
    } catch (e) {
      debugPrint('Error getting minimal remote changes: $e');
      return [];
    }
  }

  Future<SyncResult> _uploadLocalChanges(SyncPlan plan) async {
    int syncedItems = 0;
    int conflicts = 0;
    final errors = <String>[];

    try {
      for (int i = 0; i < plan.localChangesToUpload.length; i++) {
        final change = plan.localChangesToUpload[i];
        
        try {
          final result = await _uploadSingleChange(change);
          if (result.success) {
            syncedItems++;
          } else {
            if (result.hasConflict) {
              conflicts++;
            } else {
              errors.add(result.error ?? 'Unknown error');
            }
          }
          
          // Update progress
          final progress = 0.3 + (0.3 * (i + 1) / plan.localChangesToUpload.length);
          _updateSyncProgress(SyncProgress(
            phase: SyncPhase.uploading,
            progress: progress,
            message: 'Uploaded ${i + 1}/${plan.localChangesToUpload.length} changes',
          ));
        } catch (e) {
          errors.add('Error uploading change ${change['id']}: $e');
        }
      }

      return SyncResult(
        success: errors.isEmpty,
        message: 'Upload completed',
        syncedItems: syncedItems,
        conflicts: conflicts,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error uploading local changes: $e');
      return SyncResult(
        success: false,
        message: e.toString(),
        syncedItems: syncedItems,
        conflicts: conflicts,
        errors: [...errors, e.toString()],
      );
    }
  }

  Future<UploadResult> _uploadSingleChange(Map<String, dynamic> change) async {
    try {
      final type = change['type'] as String;
      final id = change['id'] as String;
      final data = change['data'] as Map<String, dynamic>;
      final action = change['action'] as String;

      switch (type) {
        case 'post':
          return await _uploadPostChange(id, data, action);
        case 'comment':
          return await _uploadCommentChange(id, data, action);
        case 'engagement':
          return await _uploadEngagementChange(id, data, action);
        default:
          return UploadResult(
            success: false,
            error: 'Unknown change type: $type',
          );
      }
    } catch (e) {
      return UploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<UploadResult> _uploadPostChange(String id, Map<String, dynamic> data, String action) async {
    try {
      final postRef = _firestore.collection('posts').doc(id);
      
      if (action == 'delete') {
        await postRef.delete();
      } else {
        // Check for conflicts before uploading
        final remoteDoc = await postRef.get();
        
        if (remoteDoc.exists) {
          final remoteData = remoteDoc.data()!;
          final localUpdatedAt = DateTime.parse(data['updatedAt']);
          final remoteUpdatedAt = (remoteData['updatedAt'] as Timestamp).toDate();
          
          if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
            // Conflict detected
            return UploadResult(
              success: false,
              hasConflict: true,
              conflictData: {
                'local': data,
                'remote': remoteData,
              },
            );
          }
        }
        
        await postRef.set(data, SetOptions(merge: false));
      }
      
      // Mark as synced in local database
      await _localDb.markChangeSynced(id, 'post');
      
      return UploadResult(success: true);
    } catch (e) {
      return UploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<UploadResult> _uploadCommentChange(String id, Map<String, dynamic> data, String action) async {
    try {
      final postId = data['postId'] as String;
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(id);
      
      if (action == 'delete') {
        await commentRef.delete();
      } else {
        await commentRef.set(data, SetOptions(merge: false));
      }
      
      await _localDb.markChangeSynced(id, 'comment');
      
      return UploadResult(success: true);
    } catch (e) {
      return UploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<UploadResult> _uploadEngagementChange(String id, Map<String, dynamic> data, String action) async {
    try {
      final postId = data['postId'] as String;
      final engagementType = data['type'] as String;
      final engagementRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('engagement')
          .doc(engagementType);
      
      if (action == 'delete') {
        await engagementRef.delete();
      } else {
        await engagementRef.set(data, SetOptions(merge: true));
      }
      
      await _localDb.markChangeSynced(id, 'engagement');
      
      return UploadResult(success: true);
    } catch (e) {
      return UploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<SyncResult> _downloadRemoteChanges(SyncPlan plan) async {
    int syncedItems = 0;
    int conflicts = 0;
    final errors = <String>[];

    try {
      for (int i = 0; i < plan.remoteChangesToDownload.length; i++) {
        final change = plan.remoteChangesToDownload[i];
        
        try {
          final result = await _downloadSingleChange(change);
          if (result.success) {
            syncedItems++;
          } else {
            if (result.hasConflict) {
              conflicts++;
            } else {
              errors.add(result.error ?? 'Unknown error');
            }
          }
          
          // Update progress
          final progress = 0.6 + (0.2 * (i + 1) / plan.remoteChangesToDownload.length);
          _updateSyncProgress(SyncProgress(
            phase: SyncPhase.downloading,
            progress: progress,
            message: 'Downloaded ${i + 1}/${plan.remoteChangesToDownload.length} changes',
          ));
        } catch (e) {
          errors.add('Error downloading change ${change['id']}: $e');
        }
      }

      return SyncResult(
        success: errors.isEmpty,
        message: 'Download completed',
        syncedItems: syncedItems,
        conflicts: conflicts,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error downloading remote changes: $e');
      return SyncResult(
        success: false,
        message: e.toString(),
        syncedItems: syncedItems,
        conflicts: conflicts,
        errors: [...errors, e.toString()],
      );
    }
  }

  Future<DownloadResult> _downloadSingleChange(Map<String, dynamic> change) async {
    try {
      final type = change['type'] as String;
      final id = change['id'] as String;
      final data = change['data'] as Map<String, dynamic>;

      // Check if we have a local version
      final localData = await _localDb.getLocalData(id, type);
      
      if (localData != null) {
        // Check for conflicts
        final hasConflict = await _checkForConflict(localData, data, type);
        if (hasConflict) {
          return DownloadResult(
            success: false,
            hasConflict: true,
            conflictData: {
              'local': localData,
              'remote': data,
            },
          );
        }
      }

      // Save to local database
      await _localDb.saveRemoteData(id, type, data);
      
      return DownloadResult(success: true);
    } catch (e) {
      return DownloadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> _checkForConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
    String type,
  ) async {
    try {
      // Simple conflict detection based on update timestamps
      final localUpdatedAt = DateTime.parse(localData['updatedAt']);
      final remoteUpdatedAt = (remoteData['updatedAt'] as Timestamp).toDate();
      
      // If both have been updated since last sync, it's a conflict
      final lastSyncTime = await _localDb.getLastSyncTimestamp();
      
      if (lastSyncTime != null) {
        final localModifiedSinceSync = localUpdatedAt.isAfter(lastSyncTime);
        final remoteModifiedSinceSync = remoteUpdatedAt.isAfter(lastSyncTime);
        
        return localModifiedSinceSync && remoteModifiedSinceSync;
      }
      
      // If no last sync time, check if timestamps are different
      return localUpdatedAt != remoteUpdatedAt;
    } catch (e) {
      debugPrint('Error checking for conflict: $e');
      return false;
    }
  }

  Future<ConflictResolutionResult> _resolveConflicts() async {
    int resolvedConflicts = 0;
    final errors = <String>[];

    try {
      final conflicts = await _localDb.getPendingConflicts();
      
      for (final conflict in conflicts) {
        try {
          final resolution = await _resolveConflict(conflict);
          if (resolution.isResolved) {
            resolvedConflicts++;
            await _localDb.markConflictResolved(conflict['id']);
          } else {
            errors.add('Failed to resolve conflict: ${conflict['id']}');
          }
        } catch (e) {
          errors.add('Error resolving conflict ${conflict['id']}: $e');
        }
      }

      return ConflictResolutionResult(
        resolvedConflicts: resolvedConflicts,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error resolving conflicts: $e');
      return ConflictResolutionResult(
        resolvedConflicts: resolvedConflicts,
        errors: [...errors, e.toString()],
      );
    }
  }

  Future<ConflictResolution> _resolveConflict(Map<String, dynamic> conflict) async {
    final type = conflict['type'] as String;
    
    switch (type) {
      case 'post':
        final localPost = PostModel.fromMap(conflict['localData']);
        final remotePost = PostModel.fromMap(conflict['remoteData']);
        return await _conflictResolver.resolvePostConflict(
          localPost: localPost,
          remotePost: remotePost,
          strategy: _config.conflictResolutionStrategy,
        );
      case 'comment':
        final localComment = CommentModel.fromMap(conflict['localData']);
        final remoteComment = CommentModel.fromMap(conflict['remoteData']);
        return await _conflictResolver.resolveCommentConflict(
          localComment: localComment,
          remoteComment: remoteComment,
          strategy: _config.conflictResolutionStrategy,
        );
      case 'engagement':
        return await _conflictResolver.resolveEngagementConflict(
          localEngagement: conflict['localData'],
          remoteEngagement: conflict['remoteData'],
          engagementType: conflict['engagementType'],
        );
      default:
        throw Exception('Unknown conflict type: $type');
    }
  }

  Future<void> _finalizeSyncProcess(DateTime startTime, int syncedItems, int conflicts) async {
    try {
      // Update last sync timestamp
      await _localDb.updateLastSyncTimestamp(DateTime.now());
      
      // Record sync statistics
      final duration = DateTime.now().difference(startTime);
      await _localDb.recordSyncStatistics(
        syncedItems: syncedItems,
        conflicts: conflicts,
        duration: duration,
        success: true,
      );
      
      // Clean up old sync data
      await _localDb.cleanupOldSyncData();
      
      debugPrint('Sync finalized: $syncedItems items, $conflicts conflicts, ${duration.inSeconds}s');
    } catch (e) {
      debugPrint('Error finalizing sync: $e');
    }
  }

  Duration _estimateSyncDuration(int itemCount) {
    // Estimate based on historical data and item count
    const baseTime = Duration(seconds: 2);
    const timePerItem = Duration(milliseconds: 100);
    
    return baseTime + (timePerItem * itemCount);
  }

  void _startConnectivityMonitoring() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none && !_isSyncing) {
        // Connection restored, trigger sync
        debugPrint('Connection restored, triggering sync');
        _performIntelligentSync();
      }
    });
  }

  void _schedulePeriodicSync() {
    _syncTimer?.cancel();
    
    if (_config.enablePeriodicSync) {
      _syncTimer = Timer.periodic(_config.syncInterval, (timer) {
        if (!_isSyncing) {
          _performIntelligentSync();
        }
      });
    }
  }

  Future<void> _loadSyncConfiguration() async {
    try {
      final configData = await _localDb.getSyncConfiguration();
      if (configData != null) {
        _config = SyncConfiguration.fromMap(configData);
      }
    } catch (e) {
      debugPrint('Error loading sync configuration: $e');
    }
  }

  Future<void> _saveSyncConfiguration() async {
    try {
      await _localDb.saveSyncConfiguration(_config.toMap());
    } catch (e) {
      debugPrint('Error saving sync configuration: $e');
    }
  }

  void _updateSyncStatus(SyncStatus status) {
    _syncStatusController.add(status);
  }

  void _updateSyncProgress(SyncProgress progress) {
    _syncProgressController.add(progress);
  }
}

// Data models for intelligent sync

enum SyncMode {
  intelligent,
  full,
  minimal,
}

enum SyncStatus {
  idle,
  syncing,
  completed,
  failed,
  cancelled,
}

enum SyncPhase {
  analyzing,
  uploading,
  downloading,
  resolving,
  finalizing,
  completed,
}

class SyncConfiguration {
  final bool enablePeriodicSync;
  final Duration syncInterval;
  final int maxItemsPerSync;
  final ConflictResolutionStrategy conflictResolutionStrategy;
  final bool syncOnlyOnWifi;
  final bool enableBackgroundSync;

  SyncConfiguration({
    required this.enablePeriodicSync,
    required this.syncInterval,
    required this.maxItemsPerSync,
    required this.conflictResolutionStrategy,
    required this.syncOnlyOnWifi,
    required this.enableBackgroundSync,
  });

  static SyncConfiguration defaultConfig() {
    return SyncConfiguration(
      enablePeriodicSync: true,
      syncInterval: const Duration(minutes: 15),
      maxItemsPerSync: 100,
      conflictResolutionStrategy: ConflictResolutionStrategy.automatic,
      syncOnlyOnWifi: false,
      enableBackgroundSync: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enablePeriodicSync': enablePeriodicSync,
      'syncInterval': syncInterval.inMinutes,
      'maxItemsPerSync': maxItemsPerSync,
      'conflictResolutionStrategy': conflictResolutionStrategy.toString(),
      'syncOnlyOnWifi': syncOnlyOnWifi,
      'enableBackgroundSync': enableBackgroundSync,
    };
  }

  factory SyncConfiguration.fromMap(Map<String, dynamic> map) {
    return SyncConfiguration(
      enablePeriodicSync: map['enablePeriodicSync'] ?? true,
      syncInterval: Duration(minutes: map['syncInterval'] ?? 15),
      maxItemsPerSync: map['maxItemsPerSync'] ?? 100,
      conflictResolutionStrategy: ConflictResolutionStrategy.values.firstWhere(
        (e) => e.toString() == map['conflictResolutionStrategy'],
        orElse: () => ConflictResolutionStrategy.automatic,
      ),
      syncOnlyOnWifi: map['syncOnlyOnWifi'] ?? false,
      enableBackgroundSync: map['enableBackgroundSync'] ?? true,
    );
  }
}

class SyncPlan {
  List<Map<String, dynamic>> localChangesToUpload = [];
  List<Map<String, dynamic>> remoteChangesToDownload = [];
  int estimatedItems = 0;
  Duration estimatedDuration = Duration.zero;
}

class SyncProgress {
  final SyncPhase phase;
  final double progress; // 0.0 to 1.0
  final String message;

  SyncProgress({
    required this.phase,
    required this.progress,
    required this.message,
  });
}

class SyncResult {
  final bool success;
  final String message;
  final int syncedItems;
  final int conflicts;
  final List<String> errors;
  final Duration? duration;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedItems,
    required this.conflicts,
    this.errors = const [],
    this.duration,
  });
}

class UploadResult {
  final bool success;
  final bool hasConflict;
  final String? error;
  final Map<String, dynamic>? conflictData;

  UploadResult({
    required this.success,
    this.hasConflict = false,
    this.error,
    this.conflictData,
  });
}

class DownloadResult {
  final bool success;
  final bool hasConflict;
  final String? error;
  final Map<String, dynamic>? conflictData;

  DownloadResult({
    required this.success,
    this.hasConflict = false,
    this.error,
    this.conflictData,
  });
}

class ConflictResolutionResult {
  final int resolvedConflicts;
  final List<String> errors;

  ConflictResolutionResult({
    required this.resolvedConflicts,
    required this.errors,
  });
}

class SyncStatistics {
  final int totalSyncs;
  final int successfulSyncs;
  final int failedSyncs;
  final int totalConflicts;
  final int resolvedConflicts;
  final DateTime? lastSyncTime;
  final Duration averageSyncDuration;

  SyncStatistics({
    required this.totalSyncs,
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.totalConflicts,
    required this.resolvedConflicts,
    required this.lastSyncTime,
    required this.averageSyncDuration,
  });
}
