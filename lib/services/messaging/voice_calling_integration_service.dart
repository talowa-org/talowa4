import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/voice_call.dart';
import '../../models/call_quality.dart';
import '../unified_auth_service.dart';
import 'webrtc_service.dart';
import 'call_history_service.dart';
import 'incoming_call_service.dart';
import 'signaling_service.dart';
import 'user_discovery_service.dart';
import '../notifications/local_notification_service.dart';

/// Comprehensive voice calling integration service for TALOWA
/// Implements Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6
class VoiceCallingIntegrationService {
  static final VoiceCallingIntegrationService _instance = VoiceCallingIntegrationService._internal();
  factory VoiceCallingIntegrationService() => _instance;
  VoiceCallingIntegrationService._internal();

  final WebRTCService _webrtcService = WebRTCService();
  final CallHistoryService _callHistoryService = CallHistoryService();
  final IncomingCallService _incomingCallService = IncomingCallService();
  final SignalingService _signalingService = SignalingService();
  final UserDiscoveryService _userDiscoveryService = UserDiscoveryService();
  final LocalNotificationService _notificationService = LocalNotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;
  StreamSubscription<IncomingCall>? _incomingCallSubscription;
  StreamSubscription<CallStatus>? _callStatusSubscription;

  /// Initialize the voice calling integration service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize all dependent services
      await _webrtcService.initialize();
      await _signalingService.initialize();
      await _incomingCallService.initialize();
      await _userDiscoveryService.initialize();
      await _notificationService.initialize();

      // Set up event listeners
      _setupEventListeners();

      _isInitialized = true;
      debugPrint('Voice calling integration service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize voice calling integration service: $e');
      rethrow;
    }
  }

  /// Check user availability before initiating a call
  /// Requirement 3.1: Check user availability status and establish connection within 10 seconds
  Future<UserAvailabilityStatus> checkUserAvailability(String userId) async {
    try {
      // Get user's online status
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return UserAvailabilityStatus(
          isAvailable: false,
          status: 'user_not_found',
          message: 'User not found',
        );
      }

      final userData = userDoc.data()!;
      final isOnline = userData['isOnline'] ?? false;
      final lastSeen = userData['lastSeen'] as Timestamp?;
      final callStatus = userData['callStatus'] ?? 'available';

      // Check if user is currently in a call
      if (callStatus == 'in_call') {
        return UserAvailabilityStatus(
          isAvailable: false,
          status: 'busy',
          message: 'User is currently in another call',
        );
      }

      // Check if user is online
      if (!isOnline) {
        final lastSeenTime = lastSeen?.toDate();
        final timeSinceLastSeen = lastSeenTime != null 
            ? DateTime.now().difference(lastSeenTime).inMinutes
            : null;

        return UserAvailabilityStatus(
          isAvailable: false,
          status: 'offline',
          message: timeSinceLastSeen != null && timeSinceLastSeen < 60
              ? 'User was last seen $timeSinceLastSeen minutes ago'
              : 'User is offline',
          lastSeen: lastSeenTime,
        );
      }

      // User is available for calls
      return UserAvailabilityStatus(
        isAvailable: true,
        status: 'available',
        message: 'User is available for calls',
      );
    } catch (e) {
      debugPrint('Failed to check user availability: $e');
      return UserAvailabilityStatus(
        isAvailable: false,
        status: 'error',
        message: 'Failed to check user availability',
      );
    }
  }

  /// Initiate a voice call to another user
  /// Requirement 3.1: Check user availability and establish connection within 10 seconds
  Future<CallSession> initiateCall(String recipientId, {String callType = 'voice'}) async {
    try {
      // Check user availability first
      final availability = await checkUserAvailability(recipientId);
      if (!availability.isAvailable) {
        throw CallException(
          code: 'user_unavailable',
          message: availability.message,
        );
      }

      // Get current user info
      final currentUser = UnifiedAuthService.currentUser;
      if (currentUser == null) {
        throw CallException(
          code: 'not_authenticated',
          message: 'User not authenticated',
        );
      }

      // Get recipient user info
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) {
        throw CallException(
          code: 'recipient_not_found',
          message: 'Recipient user not found',
        );
      }

      final recipientData = recipientDoc.data()!;
      final recipientName = recipientData['fullName'] ?? 'Unknown User';

      // Update caller's call status
      await _firestore.collection('users').doc(currentUser.uid).update({
        'callStatus': 'calling',
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Initiate call through WebRTC service
      final callSession = await _webrtcService.initiateCall(recipientId, callType);

      // Send call notification to recipient
      await _sendCallNotification(callSession, recipientId, recipientName);

      debugPrint('Call initiated successfully: ${callSession.id}');
      return callSession;
    } catch (e) {
      debugPrint('Failed to initiate call: $e');
      rethrow;
    }
  }

  /// Accept an incoming call
  /// Requirement 3.3: Display caller information and provide accept/reject options
  Future<CallSession> acceptCall(String callId) async {
    try {
      // Update user's call status
      final currentUser = UnifiedAuthService.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'callStatus': 'in_call',
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }

      // Accept call through WebRTC service
      final callSession = await _webrtcService.acceptCall(callId);

      // Clear any missed call notifications
      await _notificationService.clearCallNotifications(callId);

      debugPrint('Call accepted successfully: $callId');
      return callSession;
    } catch (e) {
      debugPrint('Failed to accept call: $e');
      rethrow;
    }
  }

  /// Reject an incoming call
  /// Requirement 3.3: Provide accept/reject options
  Future<void> rejectCall(String callId) async {
    try {
      // Reject call through WebRTC service
      await _webrtcService.rejectCall(callId);

      // Save as missed call
      final callSession = _webrtcService.getCallSession(callId);
      if (callSession != null) {
        final currentUser = UnifiedAuthService.currentUser;
        if (currentUser != null) {
          final caller = callSession.participants.firstWhere(
            (p) => p.userId != currentUser.uid,
            orElse: () => callSession.participants.first,
          );

          final incomingCall = IncomingCall(
            id: callId,
            callerId: caller.userId,
            callerName: caller.name,
            callerRole: caller.role,
            callType: 'voice',
            timestamp: callSession.startTime,
          );

          await _callHistoryService.saveMissedCall(incomingCall);
        }
      }

      debugPrint('Call rejected successfully: $callId');
    } catch (e) {
      debugPrint('Failed to reject call: $e');
      rethrow;
    }
  }

  /// End an active call
  /// Requirement 3.4: Log call history with duration, participants, and timestamps
  Future<void> endCall(String callId) async {
    try {
      // End call through WebRTC service
      await _webrtcService.endCall(callId);

      // Update user's call status
      final currentUser = UnifiedAuthService.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'callStatus': 'available',
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('Call ended successfully: $callId');
    } catch (e) {
      debugPrint('Failed to end call: $e');
      rethrow;
    }
  }

  /// Mute/unmute audio for a call
  Future<void> muteAudio(String callId, bool mute) async {
    try {
      await _webrtcService.muteAudio(callId, mute);
      debugPrint('Audio ${mute ? 'muted' : 'unmuted'} for call: $callId');
    } catch (e) {
      debugPrint('Failed to ${mute ? 'mute' : 'unmute'} audio: $e');
      rethrow;
    }
  }

  /// Toggle speaker mode
  Future<void> toggleSpeaker(String callId, bool speakerOn) async {
    try {
      await _webrtcService.toggleSpeaker(callId, speakerOn);
      debugPrint('Speaker ${speakerOn ? 'enabled' : 'disabled'} for call: $callId');
    } catch (e) {
      debugPrint('Failed to toggle speaker: $e');
      rethrow;
    }
  }

  /// Get call quality metrics
  /// Requirement 3.6: Show connection quality indicators and adjust accordingly
  CallQuality? getCallQuality(String callId) {
    return _webrtcService.getCallQuality(callId);
  }

  /// Get active call session
  CallSession? getCallSession(String callId) {
    return _webrtcService.getCallSession(callId);
  }

  /// Get all active calls
  List<CallSession> getActiveCalls() {
    return _webrtcService.getActiveCalls();
  }

  /// Get call history
  Future<List<CallHistoryEntry>> getCallHistory({int limit = 50}) async {
    return await _callHistoryService.getCallHistory(limit: limit);
  }

  /// Get missed calls
  Future<List<MissedCallNotification>> getMissedCalls({bool unreadOnly = false}) async {
    return await _callHistoryService.getMissedCalls(unreadOnly: unreadOnly);
  }

  /// Mark missed call as read
  Future<void> markMissedCallAsRead(String callId) async {
    await _callHistoryService.markMissedCallAsRead(callId);
  }

  /// Get call statistics
  Future<Map<String, dynamic>> getCallStatistics() async {
    return await _callHistoryService.getCallStatistics();
  }

  // Event streams
  Stream<IncomingCall> get onIncomingCall => _webrtcService.onIncomingCall;
  Stream<CallStatus> get onCallStatusChange => _webrtcService.onCallStatusChange;
  Stream<CallQuality> get onCallQualityChange => _webrtcService.onCallQualityChange;

  // Private methods

  void _setupEventListeners() {
    // Listen for incoming calls
    _incomingCallSubscription = _webrtcService.onIncomingCall.listen((incomingCall) {
      _handleIncomingCall(incomingCall);
    });

    // Listen for call status changes
    _callStatusSubscription = _webrtcService.onCallStatusChange.listen((callStatus) {
      _handleCallStatusChange(callStatus);
    });
  }

  void _handleIncomingCall(IncomingCall incomingCall) async {
    try {
      // Show incoming call notification
      await _notificationService.showIncomingCallNotification(incomingCall);

      // Update user's call status
      final currentUser = UnifiedAuthService.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'callStatus': 'receiving_call',
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Failed to handle incoming call: $e');
    }
  }

  void _handleCallStatusChange(CallStatus callStatus) async {
    try {
      final callSession = _webrtcService.getCallSession(callStatus.callId);
      if (callSession == null) return;

      switch (callStatus.status) {
        case 'connected':
          await _onCallConnected(callSession);
          break;
        case 'ended':
          await _onCallEnded(callSession);
          break;
        case 'failed':
          await _onCallFailed(callSession);
          break;
        case 'missed':
          await _onCallMissed(callSession);
          break;
      }
    } catch (e) {
      debugPrint('Failed to handle call status change: $e');
    }
  }

  Future<void> _onCallConnected(CallSession callSession) async {
    // Update participants' call status
    for (final participant in callSession.participants) {
      await _firestore.collection('users').doc(participant.userId).update({
        'callStatus': 'in_call',
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _onCallEnded(CallSession callSession) async {
    // Update participants' call status
    for (final participant in callSession.participants) {
      await _firestore.collection('users').doc(participant.userId).update({
        'callStatus': 'available',
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }

    // Clear call notifications
    await _notificationService.clearCallNotifications(callSession.id);
  }

  Future<void> _onCallFailed(CallSession callSession) async {
    // Update participants' call status
    for (final participant in callSession.participants) {
      await _firestore.collection('users').doc(participant.userId).update({
        'callStatus': 'available',
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }

    // Show failure notification
    await _notificationService.showCallFailedNotification(callSession);
  }

  Future<void> _onCallMissed(CallSession callSession) async {
    // Save missed call
    final currentUser = UnifiedAuthService.currentUser;
    if (currentUser != null) {
      final caller = callSession.participants.firstWhere(
        (p) => p.userId != currentUser.uid,
        orElse: () => callSession.participants.first,
      );

      final incomingCall = IncomingCall(
        id: callSession.id,
        callerId: caller.userId,
        callerName: caller.name,
        callerRole: caller.role,
        callType: 'voice',
        timestamp: callSession.startTime,
      );

      await _callHistoryService.saveMissedCall(incomingCall);
      await _notificationService.showMissedCallNotification(incomingCall);
    }
  }

  Future<void> _sendCallNotification(CallSession callSession, String recipientId, String recipientName) async {
    try {
      // Create incoming call object
      final currentUser = UnifiedAuthService.currentUser;
      if (currentUser == null) return;

      final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final currentUserData = currentUserDoc.data();
      final callerName = currentUserData?['fullName'] ?? 'Unknown Caller';
      final callerRole = currentUserData?['role'] ?? 'member';

      final incomingCall = IncomingCall(
        id: callSession.id,
        callerId: currentUser.uid,
        callerName: callerName,
        callerRole: callerRole,
        callType: 'voice',
        timestamp: callSession.startTime,
      );

      // Send push notification
      await _notificationService.sendCallNotification(recipientId, incomingCall);
    } catch (e) {
      debugPrint('Failed to send call notification: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _incomingCallSubscription?.cancel();
    _callStatusSubscription?.cancel();
    _webrtcService.dispose();
  }
}

/// User availability status model
class UserAvailabilityStatus {
  final bool isAvailable;
  final String status;
  final String message;
  final DateTime? lastSeen;

  UserAvailabilityStatus({
    required this.isAvailable,
    required this.status,
    required this.message,
    this.lastSeen,
  });
}

/// Call exception model
class CallException implements Exception {
  final String code;
  final String message;

  CallException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'CallException($code): $message';
}