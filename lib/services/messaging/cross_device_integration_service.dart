// Cross-Device Integration Service for TALOWA
// Implements Task 9: Cross-device compatibility and data synchronization - Integration Layer
// Reference: in-app-communication/requirements.md - Requirements 8.1, 8.2, 8.3, 8.4, 8.5, 8.6

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import 'device_session_manager.dart';
import 'cross_device_sync_service.dart';
import 'conversation_state_manager.dart';
import 'message_sync_service.dart';


class CrossDeviceIntegrationService {
  static final CrossDeviceIntegrationService _instance = CrossDeviceIntegrationService._internal();
  factory CrossDeviceIntegrationService() => _instance;
  CrossDeviceIntegrationService._internal();

  final DeviceSessionManager _sessionManager = DeviceSessionManager();
  final CrossDeviceSyncService _syncService = CrossDeviceSyncService();
  final ConversationStateManager _stateManager = ConversationStateManager();
  final MessageSyncService _messageSyncService = MessageSyncService();

  
  final StreamController<CrossDeviceIntegrationEvent> _eventsController = 
      StreamController<CrossDeviceIntegrationEvent>.broadcast();
  
  bool _isInitialized = false;
  StreamSubscription? _authSubscription;
  StreamSubscription? _sessionEventsSubscription;
  StreamSubscription? _syncEventsSubscription;
  
  // Getters
  Stream<CrossDeviceIntegrationEvent> get eventsStream => _eventsController.stream;
  bool get isInitialized => _isInitialized;

  /// Initialize cross-device integration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Cross-Device Integration Service');
      
      // Initialize all components
      await _sessionManager.initialize();
      await _syncService.initialize();
      await _stateManager.initialize();
      await _messageSyncService.initialize();
      
      // Setup event listeners
      _setupEventListeners();
      
      // Setup authentication monitoring
      _setupAuthenticationMonitoring();
      
      // Perform initial sync
      await _performInitialSync();
      
      _isInitialized = true;
      
      // Notify initialization complete
      _eventsController.add(CrossDeviceIntegrationEvent(
        type: IntegrationEventType.initialized,
        timestamp: DateTime.now(),
        data: {'success': true},
      ));
      
      debugPrint('Cross-Device Integration Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing cross-device integration: $e');
      
      _eventsController.add(CrossDeviceIntegrationEvent(
        type: IntegrationEventType.initializationFailed,
        timestamp: DateTime.now(),
        data: {'error': e.toString()},
      ));
      
      rethrow;
    }
  }

  /// Handle user login with cross-device setup
  Future<void> handleUserLogin() async {
    try {
      debugPrint('Handling user login for cross-device integration');
      
      // Create or update device session
      await _sessionManager.createDeviceSession();
      
      // Perform full sync to get latest data
      await _messageSyncService.performFullSync();
      
      // Notify login handled
      _eventsController.add(CrossDeviceIntegrationEvent(
        type: IntegrationEventType.userLoggedIn,
        timestamp: DateTime.now(),
        data: {'deviceId': _sessionManager.currentDeviceId},
      ));
      
      debugPrint('User login handled successfully');
    } catch (e) {
      debugPrint('Error handling user login: $e');
      
      _eventsController.add(CrossDeviceIntegrationEvent(
        type: IntegrationEventType.loginFailed,
        timestamp: DateTime.now(),
        data: {'error': e.toString()},
      ));
    }
  }

  /// Handle user logout with cleanup
  Future<void> handleUserLogout({
    bool terminateAllSessions = false,
    bool clearLocalData = true,
  }) async {
    try {
      debugPrint('Handling user logout with cross-device cleanup');
      
      // Perform secure logout
      await _sessionManager.performSecureLogout(
        terminateAllSessions: terminateAllSessions,
        clearLocalData: clearLocalData,
      );
      
      // Stop all services
      await _stopAllServices();
      
      // Notify logout handled
      _eventsController.add(CrossDeviceIntegrationEvent(
        type: IntegrationEventType.userLoggedOut,
        timestamp: DateTime.now(),
        data: {
          'terminatedAllSessions': terminateAllSessions,
          'clearedLocalData': clearLocalData,
        },
      ));
      
      debugPrint('User logout handled successfully');
    } catch (e) {
      debugPrint('Error handling user logout: $e');
      
      _eventsController.add(CrossDeviceIntegrationEvent(
        type: IntegrationEventType.logoutFailed,
        timestamp: DateTime.now(),
        data: {'error': e.toString()},
      ));
    }
  }

  /// Handle message sent with cross-device sync
  Future<void> handleMessageSent({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      // Update session activity
      await _sessionManager.updateSessionActivity();
      
      // Sync conversation state
      await _syncConversationStateAfterMessage(conversationId);
      
      // Notify message sent
      _eventsController.add(CrossDeviceIntegrationEvent(
        type: IntegrationEventType.messageSent,
        timestamp: DateTime.now(),
        data: {
          'conversationId': conversationId,
          'messageId': messageId,
        },
      ));
    } catch (e) {
      debugPrint('Error handling message sent: $e');
    }
  }

  /// Handle message read with cross-device sync
  Future<void> handleMessagesRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    try {
      // Sync read status across devices
      await _syncService.syncReadStatus(
        conversationId: conversationId,
        messageIds: messageIds,
        readAt: DateTime.now(),
      );
      
      // Update session activity
      await _sessionManager.updateSessionActivity();
      
      // Notify messages read
      _eventsController.add(CrossDeviceIntegrationEvent(
        type: IntegrationEventType.messagesRead,
        timestamp: DateTime.now(),
        data: {
          'conversationId': conversationId,
          'messageCount': messageIds.length,
        },
      ));
    } catch (e) {
      debugPrint('Error handling messages read: $e');
    }
  }

  /// Get comprehensive device and sync status
  Future<CrossDeviceStatus> getStatus() async {
    try {
      final sessionStats = await _sessionManager.getSessionStatistics();
      final syncStats = await _syncService.getSyncStatistics();
      final stateStats = _stateManager.getStateStats();
      
      return CrossDeviceStatus(
        isInitialized: _isInitialized,
        currentDevice: _sessionManager.currentSession,
        sessionStatistics: sessionStats,
        syncStatistics: syncStats,
        stateStatistics: stateStats,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting cross-device status: $e');
      return CrossDeviceStatus(
        isInitialized: false,
        currentDevice: null,
        sessionStatistics: SessionStatistics(
          totalSessions: 0,
          activeSessions: 0,
          recentSessions: 0,
          currentSession: null,
          deviceTypes: {},
          platforms: {},
        ),
        syncStatistics: CrossDeviceSyncStatistics(
          totalConversations: 0,
          syncedConversations: 0,
          unresolvedConflicts: 0,
          totalConflicts: 0,
          lastSyncTime: null,
          activeSessions: 0,
        ),
        stateStatistics: ConversationStateStats(
          totalConversations: 0,
          conversationsWithUnread: 0,
          totalUnreadMessages: 0,
          activeConversations: 0,
        ),
        lastUpdated: DateTime.now(),
      );
    }
  }

  // Private helper methods

  /// Setup event listeners
  void _setupEventListeners() {
    // Listen to session events
    _sessionEventsSubscription = _sessionManager.sessionEventsStream.listen((event) {
      _handleSessionEvent(event);
    });
    
    // Listen to sync events
    _syncEventsSubscription = _syncService.syncEventsStream.listen((event) {
      _handleSyncEvent(event);
    });
  }

  /// Setup authentication monitoring
  void _setupAuthenticationMonitoring() {
    _authSubscription = AuthService.authStateChanges.listen((user) async {
      if (user != null) {
        // User logged in
        await handleUserLogin();
      } else {
        // User logged out
        await _stopAllServices();
      }
    });
  }

  /// Handle session events
  void _handleSessionEvent(DeviceSessionEvent event) {
    switch (event.type) {
      case SessionEventType.newSessionDetected:
        _eventsController.add(CrossDeviceIntegrationEvent(
          type: IntegrationEventType.newDeviceDetected,
          timestamp: event.timestamp,
          data: {
            'deviceName': event.session?.displayName,
            'deviceType': event.session?.deviceType.name,
          },
        ));
        break;
      case SessionEventType.sessionTerminated:
        _eventsController.add(CrossDeviceIntegrationEvent(
          type: IntegrationEventType.deviceDisconnected,
          timestamp: event.timestamp,
          data: {'sessionId': event.sessionId},
        ));
        break;
      default:
        break;
    }
  }

  /// Handle sync events
  void _handleSyncEvent(CrossDeviceSyncEvent event) {
    switch (event.type) {
      case SyncEventType.conflictDetected:
        _eventsController.add(CrossDeviceIntegrationEvent(
          type: IntegrationEventType.conflictDetected,
          timestamp: event.timestamp,
          data: event.data,
        ));
        break;
      case SyncEventType.conflictResolved:
        _eventsController.add(CrossDeviceIntegrationEvent(
          type: IntegrationEventType.conflictResolved,
          timestamp: event.timestamp,
          data: event.data,
        ));
        break;
      case SyncEventType.syncCompleted:
        _eventsController.add(CrossDeviceIntegrationEvent(
          type: IntegrationEventType.syncCompleted,
          timestamp: event.timestamp,
          data: event.data,
        ));
        break;
      default:
        break;
    }
  }

  /// Perform initial sync
  Future<void> _performInitialSync() async {
    try {
      // Check if user is authenticated
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;
      
      // Perform incremental sync to get latest data
      await _messageSyncService.performIncrementalSync();
      
      debugPrint('Initial sync completed');
    } catch (e) {
      debugPrint('Error during initial sync: $e');
    }
  }

  /// Sync conversation state after message
  Future<void> _syncConversationStateAfterMessage(String conversationId) async {
    try {
      final viewState = _stateManager.getViewState(conversationId);
      
      // Sync unread count (will be 0 for sender)
      await _syncService.syncUnreadCounts(
        conversationId: conversationId,
        unreadCount: viewState.unreadCount,
        unreadMessageIds: viewState.unreadMessageIds,
      );
    } catch (e) {
      debugPrint('Error syncing conversation state after message: $e');
    }
  }

  /// Stop all services
  Future<void> _stopAllServices() async {
    try {
      await _authSubscription?.cancel();
      await _sessionEventsSubscription?.cancel();
      await _syncEventsSubscription?.cancel();
      
      _isInitialized = false;
      
      debugPrint('All cross-device services stopped');
    } catch (e) {
      debugPrint('Error stopping services: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _stopAllServices();
    _eventsController.close();
    _sessionManager.dispose();
    _syncService.dispose();
    _stateManager.dispose();
    _messageSyncService.dispose();
  }
}

// Data models for cross-device integration

enum IntegrationEventType {
  initialized,
  initializationFailed,
  userLoggedIn,
  loginFailed,
  userLoggedOut,
  logoutFailed,
  messageSent,
  messagesRead,
  conversationOpened,
  newDeviceDetected,
  deviceDisconnected,
  conflictDetected,
  conflictResolved,
  syncCompleted,
  forceSyncCompleted,
  forceSyncFailed,
  conflictsResolved,
}

class CrossDeviceIntegrationEvent {
  final IntegrationEventType type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  CrossDeviceIntegrationEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });
}

class CrossDeviceStatus {
  final bool isInitialized;
  final DeviceSession? currentDevice;
  final SessionStatistics sessionStatistics;
  final CrossDeviceSyncStatistics syncStatistics;
  final ConversationStateStats stateStatistics;
  final DateTime lastUpdated;

  CrossDeviceStatus({
    required this.isInitialized,
    required this.currentDevice,
    required this.sessionStatistics,
    required this.syncStatistics,
    required this.stateStatistics,
    required this.lastUpdated,
  });

  bool get isHealthy => 
      isInitialized && 
      syncStatistics.isHealthy && 
      sessionStatistics.activeSessions > 0;

  bool get hasMultipleDevices => sessionStatistics.activeSessions > 1;
  bool get hasConflicts => syncStatistics.hasUnresolvedConflicts;
  bool get needsSync => !syncStatistics.isHealthy;
}