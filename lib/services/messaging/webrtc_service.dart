import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/voice_call.dart';
import '../../models/call_participant.dart';
import '../../models/call_quality.dart';
import 'signaling_service.dart';
import 'call_quality_monitor.dart';
import 'call_history_service.dart';

/// WebRTC service for handling voice calls in TALOWA
class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  final SignalingService _signalingService = SignalingService();
  final CallQualityMonitor _qualityMonitor = CallQualityMonitor();
  final CallHistoryService _callHistoryService = CallHistoryService();
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _localStreams = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, CallSession> _activeCalls = {};
  
  // Event controllers
  final StreamController<IncomingCall> _incomingCallController = StreamController.broadcast();
  final StreamController<CallStatus> _callStatusController = StreamController.broadcast();
  final StreamController<CallQuality> _callQualityController = StreamController.broadcast();

  // Configuration for TURN/STUN servers
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // TURN servers will be added dynamically from signaling service
    ],
    'sdpSemantics': 'unified-plan',
  };

  // Streams for listening to events
  Stream<IncomingCall> get onIncomingCall => _incomingCallController.stream;
  Stream<CallStatus> get onCallStatusChange => _callStatusController.stream;
  Stream<CallQuality> get onCallQualityChange => _callQualityController.stream;

  /// Initialize the WebRTC service
  Future<void> initialize() async {
    try {
      await _signalingService.initialize();
      _setupSignalingListeners();
      debugPrint('WebRTC Service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize WebRTC Service: $e');
      rethrow;
    }
  }

  /// Initiate a voice call to another user
  Future<CallSession> initiateCall(String recipientId, String callType) async {
    try {
      final callId = _generateCallId();
      final callSession = CallSession(
        id: callId,
        participants: [
          CallParticipant(
            userId: await _getCurrentUserId(),
            name: await _getCurrentUserName(),
            role: 'caller',
            isMuted: false,
            connectionQuality: 'connecting',
          ),
          CallParticipant(
            userId: recipientId,
            name: await _getUserName(recipientId),
            role: 'recipient',
            isMuted: false,
            connectionQuality: 'connecting',
          ),
        ],
        status: 'connecting',
        startTime: DateTime.now().millisecondsSinceEpoch,
        quality: CallQuality(
          averageLatency: 0,
          packetLoss: 0,
          jitter: 0,
          audioQuality: 'connecting',
        ),
        isEncrypted: true,
      );

      _activeCalls[callId] = callSession;

      // Create peer connection
      final peerConnection = await _createPeerConnection(callId);
      _peerConnections[callId] = peerConnection;

      // Get user media (audio only for voice calls)
      final localStream = await _getUserMedia(callType == 'video');
      _localStreams[callId] = localStream;

      // Add local stream to peer connection
      localStream.getTracks().forEach((track) {
        peerConnection.addTrack(track, localStream);
      });

      // Create and send offer
      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      
      await _signalingService.sendOffer(callId, offer);

      // Start quality monitoring
      await _qualityMonitor.startMonitoring(callId, peerConnection);

      _callStatusController.add(CallStatus(callId: callId, status: 'connecting'));
      
      return callSession;
    } catch (e) {
      debugPrint('Failed to initiate call: $e');
      rethrow;
    }
  }

  /// Accept an incoming call
  Future<CallSession> acceptCall(String callId) async {
    try {
      final callSession = _activeCalls[callId];
      if (callSession == null) {
        throw Exception('Call not found: $callId');
      }

      // Create peer connection
      final peerConnection = await _createPeerConnection(callId);
      _peerConnections[callId] = peerConnection;

      // Get user media
      final localStream = await _getUserMedia(false); // Voice only for now
      _localStreams[callId] = localStream;

      // Add local stream to peer connection
      localStream.getTracks().forEach((track) {
        peerConnection.addTrack(track, localStream);
      });

      // Update call status
      callSession.status = 'connected';
      callSession.startTime = DateTime.now().millisecondsSinceEpoch;
      _activeCalls[callId] = callSession;

      // Start quality monitoring
      await _qualityMonitor.startMonitoring(callId, peerConnection);

      _callStatusController.add(CallStatus(callId: callId, status: 'connected'));

      return callSession;
    } catch (e) {
      debugPrint('Failed to accept call: $e');
      rethrow;
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall(String callId) async {
    try {
      await _signalingService.rejectCall(callId);
      await _cleanupCall(callId);
      _callStatusController.add(CallStatus(callId: callId, status: 'rejected'));
    } catch (e) {
      debugPrint('Failed to reject call: $e');
      rethrow;
    }
  }

  /// End an active call
  Future<void> endCall(String callId) async {
    try {
      await _signalingService.endCall(callId);
      await _cleanupCall(callId);
      _callStatusController.add(CallStatus(callId: callId, status: 'ended'));
    } catch (e) {
      debugPrint('Failed to end call: $e');
      rethrow;
    }
  }

  /// Mute/unmute audio for a call
  Future<void> muteAudio(String callId, bool mute) async {
    try {
      final localStream = _localStreams[callId];
      if (localStream != null) {
        final audioTracks = localStream.getAudioTracks();
        for (final track in audioTracks) {
          track.enabled = !mute;
        }
        
        // Update call session
        final callSession = _activeCalls[callId];
        if (callSession != null) {
          final currentUser = await _getCurrentUserId();
          final participant = callSession.participants.firstWhere(
            (p) => p.userId == currentUser,
            orElse: () => callSession.participants.first,
          );
          participant.isMuted = mute;
          _activeCalls[callId] = callSession;
        }
      }
    } catch (e) {
      debugPrint('Failed to mute/unmute audio: $e');
      rethrow;
    }
  }

  /// Toggle speaker mode
  Future<void> toggleSpeaker(String callId, bool speakerOn) async {
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (e) {
      debugPrint('Failed to toggle speaker: $e');
      rethrow;
    }
  }

  /// Get current call quality metrics
  CallQuality? getCallQuality(String callId) {
    final callSession = _activeCalls[callId];
    return callSession?.quality;
  }

  /// Get active call session
  CallSession? getCallSession(String callId) {
    return _activeCalls[callId];
  }

  /// Get all active calls
  List<CallSession> getActiveCalls() {
    return _activeCalls.values.toList();
  }

  // Private methods

  Future<RTCPeerConnection> _createPeerConnection(String callId) async {
    // Get TURN credentials from signaling service
    final turnCredentials = await _signalingService.getTurnCredentials();
    if (turnCredentials != null) {
      _configuration['iceServers'].add({
        'urls': turnCredentials.urls,
        'username': turnCredentials.username,
        'credential': turnCredentials.credential,
      });
    }

    final peerConnection = await createPeerConnection(_configuration);

    // Set up event listeners
    peerConnection.onIceCandidate = (candidate) {
      _signalingService.sendIceCandidate(callId, candidate);
    };

    peerConnection.onAddStream = (stream) {
      _remoteStreams[callId] = stream;
      debugPrint('Remote stream added for call: $callId');
    };

    peerConnection.onConnectionState = (state) {
      debugPrint('Connection state changed: $state for call: $callId');
      _handleConnectionStateChange(callId, state);
    };

    peerConnection.onIceConnectionState = (state) {
      debugPrint('ICE connection state: $state for call: $callId');
      _handleIceConnectionStateChange(callId, state);
    };

    return peerConnection;
  }

  Future<MediaStream> _getUserMedia(bool video) async {
    final constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video,
    };

    return await navigator.mediaDevices.getUserMedia(constraints);
  }

  void _setupSignalingListeners() {
    _signalingService.onOffer = (callId, offer) async {
      await _handleOffer(callId, offer);
    };

    _signalingService.onAnswer = (callId, answer) async {
      await _handleAnswer(callId, answer);
    };

    _signalingService.onIceCandidate = (callId, candidate) async {
      await _handleIceCandidate(callId, candidate);
    };

    _signalingService.onIncomingCall = (incomingCall) {
      _incomingCallController.add(incomingCall);
    };
  }

  Future<void> _handleOffer(String callId, RTCSessionDescription offer) async {
    try {
      final peerConnection = _peerConnections[callId];
      if (peerConnection != null) {
        await peerConnection.setRemoteDescription(offer);
        
        final answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        
        await _signalingService.sendAnswer(callId, answer);
      }
    } catch (e) {
      debugPrint('Failed to handle offer: $e');
    }
  }

  Future<void> _handleAnswer(String callId, RTCSessionDescription answer) async {
    try {
      final peerConnection = _peerConnections[callId];
      if (peerConnection != null) {
        await peerConnection.setRemoteDescription(answer);
      }
    } catch (e) {
      debugPrint('Failed to handle answer: $e');
    }
  }

  Future<void> _handleIceCandidate(String callId, RTCIceCandidate candidate) async {
    try {
      final peerConnection = _peerConnections[callId];
      if (peerConnection != null) {
        await peerConnection.addCandidate(candidate);
      }
    } catch (e) {
      debugPrint('Failed to handle ICE candidate: $e');
    }
  }

  void _handleConnectionStateChange(String callId, RTCPeerConnectionState state) {
    String status;
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        status = 'connected';
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        status = 'disconnected';
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        status = 'failed';
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        status = 'ended';
        break;
      default:
        status = 'connecting';
    }

    _callStatusController.add(CallStatus(callId: callId, status: status));
  }

  void _handleIceConnectionStateChange(String callId, RTCIceConnectionState state) {
    // Monitor connection quality based on ICE state
    final callSession = _activeCalls[callId];
    if (callSession != null) {
      String quality;
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          quality = 'excellent';
          break;
        case RTCIceConnectionState.RTCIceConnectionStateChecking:
          quality = 'good';
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          quality = 'poor';
          break;
        default:
          quality = 'connecting';
      }

      callSession.quality.audioQuality = quality;
      _callQualityController.add(callSession.quality);
    }
  }

  Future<void> _cleanupCall(String callId) async {
    // Save call to history
    final callSession = _activeCalls[callId];
    if (callSession != null) {
      callSession.endTime = DateTime.now().millisecondsSinceEpoch;
      await _callHistoryService.saveCallToHistory(callSession);
    }

    // Stop quality monitoring
    _qualityMonitor.stopMonitoring(callId);

    // Close peer connection
    final peerConnection = _peerConnections[callId];
    if (peerConnection != null) {
      await peerConnection.close();
      _peerConnections.remove(callId);
    }

    // Stop local stream
    final localStream = _localStreams[callId];
    if (localStream != null) {
      localStream.getTracks().forEach((track) => track.stop());
      _localStreams.remove(callId);
    }

    // Remove remote stream
    _remoteStreams.remove(callId);

    // Remove call session
    _activeCalls.remove(callId);
  }

  String _generateCallId() {
    return 'call_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (9000 * (DateTime.now().microsecond / 1000000))).round()}';
  }

  Future<String> _getCurrentUserId() async {
    // TODO: Get from auth service
    return 'current_user_id';
  }

  Future<String> _getCurrentUserName() async {
    // TODO: Get from user service
    return 'Current User';
  }

  Future<String> _getUserName(String userId) async {
    // TODO: Get from user service
    return 'User $userId';
  }

  /// Dispose resources
  void dispose() {
    _incomingCallController.close();
    _callStatusController.close();
    _callQualityController.close();
    
    // Cleanup all active calls
    for (final callId in _activeCalls.keys.toList()) {
      _cleanupCall(callId);
    }
  }
}

/// Call status update model
class CallStatus {
  final String callId;
  final String status;

  CallStatus({required this.callId, required this.status});
}
