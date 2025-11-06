// Cross-Device Sync Service for TALOWA
// Implements Task 9: Cross-device compatibility and data synchronization - Real-time Data Sync
// Reference: in-app-communication/requirements.md - Requirements 8.2, 8.3, 8.4

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_service.dart';
import 'device_session_manager.dart';
import 'conversation_state_manager.dart';
import 'message_sync_service.dart';


class CrossDeviceSyncService {
  static final CrossDeviceSyncService _instance = CrossDeviceSyncService._internal();
  factory CrossDeviceSyncService() => _instance;
  CrossDeviceSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceSessionManager _sessionManager = DeviceSessionManager();
  final ConversationStateManager _stateManager = ConversationStateManager();
  final MessageSyncService _messageSyncService = MessageSyncService();
  
  final StreamController<CrossDeviceSyncEvent> _syncEventsController = 
      StreamController<CrossDeviceSyncEvent>.broadcast();
  final StreamController<ConversationStateSync> _stateUpdatesController = 
      StreamController<ConversationStateSync>.broadcast();
  
  final Map<String, StreamSubscription> _conversationSubscriptions = {};
  final Map<String, StreamSubscription> _stateSubscriptions = {};
  Timer? _syncTimer;
  bool _isInitialized = false;
  
  // Configuration
  static const String _syncStateCollectionName = 'cross_device_sync_state';
  static const String _conflictResolutionCollectionName = 'sync_conflicts';
  static const Duration _syncInterval = Duration(seconds: 30);
  static const Duration _stateUpdateDebounce = Duration(milliseconds: 500);
  
  // Getters
  Stream<CrossDeviceSyncEvent> get syncEventsStream => _syncEventsController.stream;
  Stream<ConversationStateSync> get stateUpdatesStream => _stateUpdatesController.stream;

  /// Initialize cross-device sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Cross-Device Sync Service');
      
      await _sessionManager.initialize();
      await _stateManager.initialize();
      await _messageSyncService.initialize();
      
      await _startRealTimeSyncMonitoring();
      await _startConversationStateSync();
      await _schedulePeriodicSync();
      
      _isInitialized = true;
      debugPrint('Cross-Device Sync Service initialized');
    } catch (e) {
      debugPrint('Error initializing cross-device sync service: $e');
      rethrow;
    }
  }

  /// Sync conversation state across devices
  Future<void> syncConversationState({
    required String conversationId,
    required ConversationStateSyncData stateData,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final currentDevice = _sessionManager.currentDeviceId;
      if (currentDevice == null) {
        throw Exception('Device not initialized');
      }

      final syncDoc = ConversationStateSync(
        id: '${conversationId}_${currentUser.uid}',
        conversationId: conversationId,
        userId: currentUser.uid,
        deviceId: currentDevice,
        stateData: stateData,
        timestamp: DateTime.now(),
        version: await _getNextStateVersion(conversationId, currentUser.uid),
      );

      // Save to Firestore for cross-device sync
      await _firestore
          .collection(_syncStateCollectionName)
          .doc(syncDoc.id)
          .set(syncDoc.toFirestore(), SetOptions(merge: true));

      // Update local state
      await _updateLocalConversationState(conversationId, stateData);

      // Notify sync event
      _syncEventsController.add(CrossDeviceSyncEvent(
        type: SyncEventType.stateUpdated,
        conversationId: conversationId,
        deviceId: currentDevice,
        timestamp: DateTime.now(),
        data: stateData.toMap(),
      ));

      debugPrint('Synced conversation state for $conversationId');
    } catch (e) {
      debugPrint('Error syncing conversation state: $e');
      rethrow;
    }
  }

  /// Sync read status across devices
  Future<void> syncReadStatus({
    required String conversationId,
    required List<String> messageIds,
    required DateTime readAt,
  }) async {
    try {
      final stateData = ConversationStateSyncData(
        readStatus: ReadStatusSync(
          messageIds: messageIds,
          readAt: readAt,
          lastReadMessageId: messageIds.isNotEmpty ? messageIds.last : null,
        ),
      );

      await syncConversationState(
        conversationId: conversationId,
        stateData: stateData,
      );

      // Update conversation state manager
      await _stateManager.markMessagesAsRead(
        conversationId: conversationId,
        messageIds: messageIds,
      );

      debugPrint('Synced read status for ${messageIds.length} messages');
    } catch (e) {
      debugPrint('Error syncing read status: $e');
    }
  }

  /// Sync unread counts across devices
  Future<void> syncUnreadCounts({
    required String conversationId,
    required int unreadCount,
    required List<String> unreadMessageIds,
  }) async {
    try {
      final stateData = ConversationStateSyncData(
        unreadCount: UnreadCountSync(
          count: unreadCount,
          messageIds: unreadMessageIds,
          lastUpdated: DateTime.now(),
        ),
      );

      await syncConversationState(
        conversationId: conversationId,
        stateData: stateData,
      );

      // Update conversation state manager
      await _stateManager.updateUnreadIndicators(
        conversationId: conversationId,
        unreadCount: unreadCount,
        unreadMessageIds: unreadMessageIds,
      );

      debugPrint('Synced unread counts: $unreadCount for $conversationId');
    } catch (e) {
      debugPrint('Error syncing unread counts: $e');
    }
  }

  /// Sync scroll position across devices
  Future<void> syncScrollPosition({
    required String conversationId,
    required double scrollPosition,
    String? lastVisibleMessageId,
    int? visibleMessageCount,
  }) async {
    try {
      final stateData = ConversationStateSyncData(
        scrollPosition: ScrollPositionSync(
          position: scrollPosition,
          lastVisibleMessageId: lastVisibleMessageId,
          visibleMessageCount: visibleMessageCount ?? 0,
          timestamp: DateTime.now(),
        ),
      );

      await syncConversationState(
        conversationId: conversationId,
        stateData: stateData,
      );

      debugPrint('Synced scroll position: $scrollPosition for $conversationId');
    } catch (e) {
      debugPrint('Error syncing scroll position: $e');
    }
  }

  /// Handle conflict resolution for simultaneous actions
  Future<ConflictResolutionResult> resolveConflict({
    required String conversationId,
    required ConflictType conflictType,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    ConflictResolutionStrategy strategy = ConflictResolutionStrategy.automatic,
  }) async {
    try {
      debugPrint('Resolving conflict for $conversationId: $conflictType');

      final conflict = SyncConflict(
        id: '${conversationId}_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        conflictType: conflictType,
        localData: localData,
        remoteData: remoteData,
        detectedAt: DateTime.now(),
        strategy: strategy,
      );

      // Save conflict for tracking
      await _firestore
          .collection(_conflictResolutionCollectionName)
          .doc(conflict.id)
          .set(conflict.toFirestore());

      ConflictResolutionResult result;

      switch (strategy) {
        case ConflictResolutionStrategy.automatic:
          result = await _resolveConflictAutomatically(conflict);
          break;
        case ConflictResolutionStrategy.localWins:
          result = await _resolveConflictLocalWins(conflict);
          break;
        case ConflictResolutionStrategy.remoteWins:
          result = await _resolveConflictRemoteWins(conflict);
          break;
        case ConflictResolutionStrategy.merge:
          result = await _resolveConflictMerge(conflict);
          break;
        case ConflictResolutionStrategy.manual:
          result = ConflictResolutionResult(
            isResolved: false,
            strategy: 'manual_required',
            conflict: conflict,
          );
          break;
      }

      // Update conflict with resolution
      await _firestore
          .collection(_conflictResolutionCollectionName)
          .doc(conflict.id)
          .update({
        'isResolved': result.isResolved,
        'resolutionStrategy': result.strategy,
        'resolvedAt': Timestamp.fromDate(DateTime.now()),
        'resolutionData': result.resolvedData,
      });

      // Notify conflict resolution
      _syncEventsController.add(CrossDeviceSyncEvent(
        type: SyncEventType.conflictResolved,
        conversationId: conversationId,
        timestamp: DateTime.now(),
        data: {
          'conflictType': conflictType.name,
          'strategy': result.strategy,
          'isResolved': result.isResolved,
        },
      ));

      debugPrint('Conflict resolved: ${result.strategy}');
      return result;
    } catch (e) {
      debugPrint('Error resolving conflict: $e');
      return ConflictResolutionResult(
        isResolved: false,
        strategy: 'error',
        error: e.toString(),
      );
    }
  }

  /// Get sync status for conversation
  Future<ConversationSyncStatus> getConversationSyncStatus(String conversationId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final syncDoc = await _firestore
          .collection(_syncStateCollectionName)
          .doc('${conversationId}_${currentUser.uid}')
          .get();

      if (!syncDoc.exists) {
        return ConversationSyncStatus(
          conversationId: conversationId,
          isSynced: false,
          lastSyncTime: null,
          syncVersion: 0,
          conflictCount: 0,
        );
      }

      final syncData = ConversationStateSync.fromFirestore(syncDoc);
      
      // Get conflict count
      final conflictsSnapshot = await _firestore
          .collection(_conflictResolutionCollectionName)
          .where('conversationId', isEqualTo: conversationId)
          .where('isResolved', isEqualTo: false)
          .get();

      return ConversationSyncStatus(
        conversationId: conversationId,
        isSynced: true,
        lastSyncTime: syncData.timestamp,
        syncVersion: syncData.version,
        conflictCount: conflictsSnapshot.docs.length,
        deviceId: syncData.deviceId,
      );
    } catch (e) {
      debugPrint('Error getting conversation sync status: $e');
      return ConversationSyncStatus(
        conversationId: conversationId,
        isSynced: false,
        lastSyncTime: null,
        syncVersion: 0,
        conflictCount: 0,
      );
    }
  }

  /// Get overall sync statistics
  Future<CrossDeviceSyncStatistics> getSyncStatistics() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get sync states
      final syncStatesSnapshot = await _firestore
          .collection(_syncStateCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // Get conflicts
      final conflictsSnapshot = await _firestore
          .collection(_conflictResolutionCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      final totalConversations = syncStatesSnapshot.docs.length;
      final unresolvedConflicts = conflictsSnapshot.docs
          .where((doc) => !(doc.data()['isResolved'] ?? false))
          .length;
      final totalConflicts = conflictsSnapshot.docs.length;

      return CrossDeviceSyncStatistics(
        totalConversations: totalConversations,
        syncedConversations: totalConversations,
        unresolvedConflicts: unresolvedConflicts,
        totalConflicts: totalConflicts,
        lastSyncTime: DateTime.now(),
        activeSessions: (await _sessionManager.getUserSessions()).length,
      );
    } catch (e) {
      debugPrint('Error getting sync statistics: $e');
      return CrossDeviceSyncStatistics(
        totalConversations: 0,
        syncedConversations: 0,
        unresolvedConflicts: 0,
        totalConflicts: 0,
        lastSyncTime: null,
        activeSessions: 0,
      );
    }
  }

  // Private helper methods

  /// Start real-time sync monitoring
  Future<void> _startRealTimeSyncMonitoring() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Monitor sync state changes
      _firestore
          .collection(_syncStateCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified ||
              change.type == DocumentChangeType.added) {
            final syncData = ConversationStateSync.fromFirestore(change.doc);
            
            // Skip updates from current device
            if (syncData.deviceId == _sessionManager.currentDeviceId) {
              continue;
            }

            _handleRemoteStateUpdate(syncData);
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting real-time sync monitoring: $e');
    }
  }

  /// Start conversation state sync
  Future<void> _startConversationStateSync() async {
    try {
      // Listen to local state changes and sync them
      _stateManager.stateUpdatesStream.listen((viewState) {
        _debounceStateSync(viewState);
      });
    } catch (e) {
      debugPrint('Error starting conversation state sync: $e');
    }
  }

  /// Schedule periodic sync
  Future<void> _schedulePeriodicSync() async {
    _syncTimer?.cancel();
    
    _syncTimer = Timer.periodic(_syncInterval, (timer) async {
      await _performPeriodicSync();
    });
  }

  /// Perform periodic sync
  Future<void> _performPeriodicSync() async {
    try {
      // Sync message data
      await _messageSyncService.performIncrementalSync();
      
      // Check for conflicts
      await _checkForConflicts();
      
      debugPrint('Periodic sync completed');
    } catch (e) {
      debugPrint('Error during periodic sync: $e');
    }
  }

  /// Handle remote state update
  Future<void> _handleRemoteStateUpdate(ConversationStateSync syncData) async {
    try {
      // Check for conflicts
      final localState = _stateManager.getViewState(syncData.conversationId);
      final hasConflict = await _detectStateConflict(localState, syncData);

      if (hasConflict) {
        await _handleStateConflict(localState, syncData);
      } else {
        await _applyRemoteStateUpdate(syncData);
      }

      // Notify state update
      _stateUpdatesController.add(syncData);
    } catch (e) {
      debugPrint('Error handling remote state update: $e');
    }
  }

  /// Apply remote state update
  Future<void> _applyRemoteStateUpdate(ConversationStateSync syncData) async {
    try {
      final stateData = syncData.stateData;

      // Apply read status
      if (stateData.readStatus != null) {
        await _stateManager.markMessagesAsRead(
          conversationId: syncData.conversationId,
          messageIds: stateData.readStatus!.messageIds,
        );
      }

      // Apply unread count
      if (stateData.unreadCount != null) {
        await _stateManager.updateUnreadIndicators(
          conversationId: syncData.conversationId,
          unreadCount: stateData.unreadCount!.count,
          unreadMessageIds: stateData.unreadCount!.messageIds,
        );
      }

      // Apply scroll position (don't override current user's scroll)
      // This is typically only applied when switching devices

      debugPrint('Applied remote state update for ${syncData.conversationId}');
    } catch (e) {
      debugPrint('Error applying remote state update: $e');
    }
  }

  /// Detect state conflict
  Future<bool> _detectStateConflict(
    ConversationViewState localState,
    ConversationStateSync remoteSync,
  ) async {
    try {
      // Check if both local and remote have been updated recently
      final localUpdateTime = localState.lastUnreadUpdate;
      final remoteUpdateTime = remoteSync.timestamp;
      
      // If updates are within 5 seconds of each other, consider it a conflict
      final timeDiff = (localUpdateTime.difference(remoteUpdateTime)).abs();
      return timeDiff.inSeconds < 5;
    } catch (e) {
      debugPrint('Error detecting state conflict: $e');
      return false;
    }
  }

  /// Handle state conflict
  Future<void> _handleStateConflict(
    ConversationViewState localState,
    ConversationStateSync remoteSync,
  ) async {
    try {
      await resolveConflict(
        conversationId: localState.conversationId,
        conflictType: ConflictType.stateUpdate,
        localData: {
          'unreadCount': localState.unreadCount,
          'lastReadAt': localState.lastReadAt?.toIso8601String(),
          'scrollPosition': localState.scrollPosition,
        },
        remoteData: remoteSync.stateData.toMap(),
        strategy: ConflictResolutionStrategy.automatic,
      );
    } catch (e) {
      debugPrint('Error handling state conflict: $e');
    }
  }

  /// Debounce state sync to avoid too frequent updates
  final Map<String, Timer> _debounceTimers = {};
  
  void _debounceStateSync(ConversationViewState viewState) {
    _debounceTimers[viewState.conversationId]?.cancel();
    
    _debounceTimers[viewState.conversationId] = Timer(_stateUpdateDebounce, () async {
      final stateData = ConversationStateSyncData(
        readStatus: ReadStatusSync(
          messageIds: [],
          readAt: viewState.lastReadAt ?? DateTime.now(),
          lastReadMessageId: viewState.lastReadMessageId,
        ),
        unreadCount: UnreadCountSync(
          count: viewState.unreadCount,
          messageIds: viewState.unreadMessageIds,
          lastUpdated: viewState.lastUnreadUpdate,
        ),
        scrollPosition: ScrollPositionSync(
          position: viewState.scrollPosition,
          lastVisibleMessageId: viewState.lastVisibleMessageId,
          visibleMessageCount: viewState.visibleMessageCount,
          timestamp: viewState.lastScrollUpdate,
        ),
      );

      await syncConversationState(
        conversationId: viewState.conversationId,
        stateData: stateData,
      );
    });
  }

  /// Get next state version
  Future<int> _getNextStateVersion(String conversationId, String userId) async {
    try {
      final doc = await _firestore
          .collection(_syncStateCollectionName)
          .doc('${conversationId}_$userId')
          .get();

      if (doc.exists) {
        final currentVersion = doc.data()?['version'] ?? 0;
        return currentVersion + 1;
      }
      
      return 1;
    } catch (e) {
      debugPrint('Error getting next state version: $e');
      return 1;
    }
  }

  /// Update local conversation state
  Future<void> _updateLocalConversationState(
    String conversationId,
    ConversationStateSyncData stateData,
  ) async {
    try {
      // Update local state manager with synced data
      if (stateData.readStatus != null) {
        await _stateManager.markMessagesAsRead(
          conversationId: conversationId,
          messageIds: stateData.readStatus!.messageIds,
        );
      }

      if (stateData.unreadCount != null) {
        await _stateManager.updateUnreadIndicators(
          conversationId: conversationId,
          unreadCount: stateData.unreadCount!.count,
          unreadMessageIds: stateData.unreadCount!.messageIds,
        );
      }
    } catch (e) {
      debugPrint('Error updating local conversation state: $e');
    }
  }

  /// Check for conflicts
  Future<void> _checkForConflicts() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      final conflictsSnapshot = await _firestore
          .collection(_conflictResolutionCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .where('isResolved', isEqualTo: false)
          .get();

      for (final doc in conflictsSnapshot.docs) {
        final conflict = SyncConflict.fromFirestore(doc);
        await resolveConflict(
          conversationId: conflict.conversationId,
          conflictType: conflict.conflictType,
          localData: conflict.localData,
          remoteData: conflict.remoteData,
          strategy: conflict.strategy,
        );
      }
    } catch (e) {
      debugPrint('Error checking for conflicts: $e');
    }
  }

  /// Resolve conflict automatically
  Future<ConflictResolutionResult> _resolveConflictAutomatically(SyncConflict conflict) async {
    try {
      // For automatic resolution, prefer the most recent data
      switch (conflict.conflictType) {
        case ConflictType.readStatus:
          // For read status, prefer the later read time
          final localReadAt = DateTime.tryParse(conflict.localData['lastReadAt'] ?? '');
          final remoteReadAt = DateTime.tryParse(conflict.remoteData['lastReadAt'] ?? '');
          
          if (localReadAt != null && remoteReadAt != null) {
            final resolvedData = localReadAt.isAfter(remoteReadAt) 
                ? conflict.localData 
                : conflict.remoteData;
            
            await _applyResolvedData(conflict.conversationId, resolvedData);
            
            return ConflictResolutionResult(
              isResolved: true,
              strategy: 'automatic_latest_read',
              resolvedData: resolvedData,
            );
          }
          break;
          
        case ConflictType.unreadCount:
          // For unread count, prefer the higher count (more conservative)
          final localCount = conflict.localData['unreadCount'] ?? 0;
          final remoteCount = conflict.remoteData['unreadCount'] ?? 0;
          
          final resolvedData = localCount > remoteCount 
              ? conflict.localData 
              : conflict.remoteData;
          
          await _applyResolvedData(conflict.conversationId, resolvedData);
          
          return ConflictResolutionResult(
            isResolved: true,
            strategy: 'automatic_higher_unread',
            resolvedData: resolvedData,
          );
          
        case ConflictType.stateUpdate:
          // For general state updates, prefer remote (server) data
          await _applyResolvedData(conflict.conversationId, conflict.remoteData);
          
          return ConflictResolutionResult(
            isResolved: true,
            strategy: 'automatic_remote_wins',
            resolvedData: conflict.remoteData,
          );
          
        default:
          return ConflictResolutionResult(
            isResolved: false,
            strategy: 'automatic_failed',
            error: 'Unknown conflict type',
          );
      }
      
      return ConflictResolutionResult(
        isResolved: false,
        strategy: 'automatic_failed',
        error: 'Could not resolve automatically',
      );
    } catch (e) {
      return ConflictResolutionResult(
        isResolved: false,
        strategy: 'automatic_error',
        error: e.toString(),
      );
    }
  }

  /// Resolve conflict with local wins strategy
  Future<ConflictResolutionResult> _resolveConflictLocalWins(SyncConflict conflict) async {
    try {
      await _applyResolvedData(conflict.conversationId, conflict.localData);
      
      return ConflictResolutionResult(
        isResolved: true,
        strategy: 'local_wins',
        resolvedData: conflict.localData,
      );
    } catch (e) {
      return ConflictResolutionResult(
        isResolved: false,
        strategy: 'local_wins_error',
        error: e.toString(),
      );
    }
  }

  /// Resolve conflict with remote wins strategy
  Future<ConflictResolutionResult> _resolveConflictRemoteWins(SyncConflict conflict) async {
    try {
      await _applyResolvedData(conflict.conversationId, conflict.remoteData);
      
      return ConflictResolutionResult(
        isResolved: true,
        strategy: 'remote_wins',
        resolvedData: conflict.remoteData,
      );
    } catch (e) {
      return ConflictResolutionResult(
        isResolved: false,
        strategy: 'remote_wins_error',
        error: e.toString(),
      );
    }
  }

  /// Resolve conflict with merge strategy
  Future<ConflictResolutionResult> _resolveConflictMerge(SyncConflict conflict) async {
    try {
      // Merge local and remote data intelligently
      final mergedData = <String, dynamic>{};
      
      // Merge based on conflict type
      switch (conflict.conflictType) {
        case ConflictType.readStatus:
          // Take the latest read time and merge read message IDs
          final localReadAt = DateTime.tryParse(conflict.localData['lastReadAt'] ?? '');
          final remoteReadAt = DateTime.tryParse(conflict.remoteData['lastReadAt'] ?? '');
          
          mergedData['lastReadAt'] = (localReadAt != null && remoteReadAt != null)
              ? (localReadAt.isAfter(remoteReadAt) ? localReadAt : remoteReadAt).toIso8601String()
              : conflict.localData['lastReadAt'] ?? conflict.remoteData['lastReadAt'];
          
          // Merge message IDs
          final localIds = List<String>.from(conflict.localData['messageIds'] ?? []);
          final remoteIds = List<String>.from(conflict.remoteData['messageIds'] ?? []);
          mergedData['messageIds'] = [...localIds, ...remoteIds].toSet().toList();
          break;
          
        case ConflictType.unreadCount:
          // Take the higher unread count and merge unread message IDs
          final localCount = conflict.localData['unreadCount'] ?? 0;
          final remoteCount = conflict.remoteData['unreadCount'] ?? 0;
          mergedData['unreadCount'] = localCount > remoteCount ? localCount : remoteCount;
          
          final localUnreadIds = List<String>.from(conflict.localData['messageIds'] ?? []);
          final remoteUnreadIds = List<String>.from(conflict.remoteData['messageIds'] ?? []);
          mergedData['messageIds'] = [...localUnreadIds, ...remoteUnreadIds].toSet().toList();
          break;
          
        default:
          // For other types, merge all fields
          mergedData.addAll(conflict.localData);
          mergedData.addAll(conflict.remoteData);
          break;
      }
      
      await _applyResolvedData(conflict.conversationId, mergedData);
      
      return ConflictResolutionResult(
        isResolved: true,
        strategy: 'merge',
        resolvedData: mergedData,
      );
    } catch (e) {
      return ConflictResolutionResult(
        isResolved: false,
        strategy: 'merge_error',
        error: e.toString(),
      );
    }
  }

  /// Apply resolved data
  Future<void> _applyResolvedData(String conversationId, Map<String, dynamic> data) async {
    try {
      // Apply the resolved data to local state
      if (data.containsKey('unreadCount')) {
        await _stateManager.updateUnreadIndicators(
          conversationId: conversationId,
          unreadCount: data['unreadCount'] ?? 0,
          unreadMessageIds: List<String>.from(data['messageIds'] ?? []),
        );
      }

      if (data.containsKey('lastReadAt') && data['lastReadAt'] != null) {
        final messageIds = List<String>.from(data['messageIds'] ?? []);
        if (messageIds.isNotEmpty) {
          await _stateManager.markMessagesAsRead(
            conversationId: conversationId,
            messageIds: messageIds,
          );
        }
      }
    } catch (e) {
      debugPrint('Error applying resolved data: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    
    for (final subscription in _conversationSubscriptions.values) {
      subscription.cancel();
    }
    _conversationSubscriptions.clear();
    
    for (final subscription in _stateSubscriptions.values) {
      subscription.cancel();
    }
    _stateSubscriptions.clear();
    
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    
    _syncEventsController.close();
    _stateUpdatesController.close();
  }
}

// Data models for cross-device sync

enum SyncEventType {
  stateUpdated,
  conflictDetected,
  conflictResolved,
  syncCompleted,
  syncFailed,
}

enum ConflictType {
  readStatus,
  unreadCount,
  scrollPosition,
  stateUpdate,
  messageDelivery,
}

enum ConflictResolutionStrategy {
  automatic,
  localWins,
  remoteWins,
  merge,
  manual,
}

class CrossDeviceSyncEvent {
  final SyncEventType type;
  final String? conversationId;
  final String? deviceId;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  CrossDeviceSyncEvent({
    required this.type,
    this.conversationId,
    this.deviceId,
    required this.timestamp,
    this.data,
  });
}

class ConversationStateSync {
  final String id;
  final String conversationId;
  final String userId;
  final String deviceId;
  final ConversationStateSyncData stateData;
  final DateTime timestamp;
  final int version;

  ConversationStateSync({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.deviceId,
    required this.stateData,
    required this.timestamp,
    required this.version,
  });

  factory ConversationStateSync.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ConversationStateSync(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      userId: data['userId'] ?? '',
      deviceId: data['deviceId'] ?? '',
      stateData: ConversationStateSyncData.fromMap(data['stateData'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      version: data['version'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'userId': userId,
      'deviceId': deviceId,
      'stateData': stateData.toMap(),
      'timestamp': Timestamp.fromDate(timestamp),
      'version': version,
    };
  }
}

class ConversationStateSyncData {
  final ReadStatusSync? readStatus;
  final UnreadCountSync? unreadCount;
  final ScrollPositionSync? scrollPosition;

  ConversationStateSyncData({
    this.readStatus,
    this.unreadCount,
    this.scrollPosition,
  });

  factory ConversationStateSyncData.fromMap(Map<String, dynamic> map) {
    return ConversationStateSyncData(
      readStatus: map['readStatus'] != null 
          ? ReadStatusSync.fromMap(map['readStatus'])
          : null,
      unreadCount: map['unreadCount'] != null 
          ? UnreadCountSync.fromMap(map['unreadCount'])
          : null,
      scrollPosition: map['scrollPosition'] != null 
          ? ScrollPositionSync.fromMap(map['scrollPosition'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'readStatus': readStatus?.toMap(),
      'unreadCount': unreadCount?.toMap(),
      'scrollPosition': scrollPosition?.toMap(),
    };
  }
}

class ReadStatusSync {
  final List<String> messageIds;
  final DateTime readAt;
  final String? lastReadMessageId;

  ReadStatusSync({
    required this.messageIds,
    required this.readAt,
    this.lastReadMessageId,
  });

  factory ReadStatusSync.fromMap(Map<String, dynamic> map) {
    return ReadStatusSync(
      messageIds: List<String>.from(map['messageIds'] ?? []),
      readAt: DateTime.parse(map['readAt'] ?? DateTime.now().toIso8601String()),
      lastReadMessageId: map['lastReadMessageId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageIds': messageIds,
      'readAt': readAt.toIso8601String(),
      'lastReadMessageId': lastReadMessageId,
    };
  }
}

class UnreadCountSync {
  final int count;
  final List<String> messageIds;
  final DateTime lastUpdated;

  UnreadCountSync({
    required this.count,
    required this.messageIds,
    required this.lastUpdated,
  });

  factory UnreadCountSync.fromMap(Map<String, dynamic> map) {
    return UnreadCountSync(
      count: map['count'] ?? 0,
      messageIds: List<String>.from(map['messageIds'] ?? []),
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'count': count,
      'messageIds': messageIds,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class ScrollPositionSync {
  final double position;
  final String? lastVisibleMessageId;
  final int visibleMessageCount;
  final DateTime timestamp;

  ScrollPositionSync({
    required this.position,
    this.lastVisibleMessageId,
    required this.visibleMessageCount,
    required this.timestamp,
  });

  factory ScrollPositionSync.fromMap(Map<String, dynamic> map) {
    return ScrollPositionSync(
      position: (map['position'] ?? 0.0).toDouble(),
      lastVisibleMessageId: map['lastVisibleMessageId'],
      visibleMessageCount: map['visibleMessageCount'] ?? 0,
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'lastVisibleMessageId': lastVisibleMessageId,
      'visibleMessageCount': visibleMessageCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class SyncConflict {
  final String id;
  final String conversationId;
  final ConflictType conflictType;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime detectedAt;
  final ConflictResolutionStrategy strategy;
  final bool isResolved;
  final DateTime? resolvedAt;

  SyncConflict({
    required this.id,
    required this.conversationId,
    required this.conflictType,
    required this.localData,
    required this.remoteData,
    required this.detectedAt,
    required this.strategy,
    this.isResolved = false,
    this.resolvedAt,
  });

  factory SyncConflict.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SyncConflict(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      conflictType: ConflictType.values.firstWhere(
        (e) => e.name == data['conflictType'],
        orElse: () => ConflictType.stateUpdate,
      ),
      localData: Map<String, dynamic>.from(data['localData'] ?? {}),
      remoteData: Map<String, dynamic>.from(data['remoteData'] ?? {}),
      detectedAt: (data['detectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      strategy: ConflictResolutionStrategy.values.firstWhere(
        (e) => e.name == data['strategy'],
        orElse: () => ConflictResolutionStrategy.automatic,
      ),
      isResolved: data['isResolved'] ?? false,
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'conflictType': conflictType.name,
      'localData': localData,
      'remoteData': remoteData,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'strategy': strategy.name,
      'isResolved': isResolved,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }
}

class ConflictResolutionResult {
  final bool isResolved;
  final String strategy;
  final Map<String, dynamic>? resolvedData;
  final SyncConflict? conflict;
  final String? error;

  ConflictResolutionResult({
    required this.isResolved,
    required this.strategy,
    this.resolvedData,
    this.conflict,
    this.error,
  });
}

class ConversationSyncStatus {
  final String conversationId;
  final bool isSynced;
  final DateTime? lastSyncTime;
  final int syncVersion;
  final int conflictCount;
  final String? deviceId;

  ConversationSyncStatus({
    required this.conversationId,
    required this.isSynced,
    required this.lastSyncTime,
    required this.syncVersion,
    required this.conflictCount,
    this.deviceId,
  });

  bool get hasConflicts => conflictCount > 0;
  bool get isUpToDate => isSynced && conflictCount == 0;
}

class CrossDeviceSyncStatistics {
  final int totalConversations;
  final int syncedConversations;
  final int unresolvedConflicts;
  final int totalConflicts;
  final DateTime? lastSyncTime;
  final int activeSessions;

  CrossDeviceSyncStatistics({
    required this.totalConversations,
    required this.syncedConversations,
    required this.unresolvedConflicts,
    required this.totalConflicts,
    required this.lastSyncTime,
    required this.activeSessions,
  });

  double get syncRatio => totalConversations > 0 ? syncedConversations / totalConversations : 0.0;
  double get conflictRatio => totalConflicts > 0 ? unresolvedConflicts / totalConflicts : 0.0;
  bool get hasUnresolvedConflicts => unresolvedConflicts > 0;
  bool get isHealthy => syncRatio > 0.9 && conflictRatio < 0.1;
}