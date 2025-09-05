import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../models/voice_call.dart';
import '../../models/turn_credentials.dart';

/// Signaling service for WebRTC call coordination
class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;

  // Event callbacks
  Function(String callId, RTCSessionDescription offer)? onOffer;
  Function(String callId, RTCSessionDescription answer)? onAnswer;
  Function(String callId, RTCIceCandidate candidate)? onIceCandidate;
  Function(IncomingCall incomingCall)? onIncomingCall;

  /// Initialize the signaling service
  Future<void> initialize() async {
    try {
      // TODO: Get signaling server URL from config
      const signalingServerUrl = 'ws://localhost:3001'; // Development server
      
      _socket = IO.io(signalingServerUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _setupSocketListeners();
      _socket!.connect();

      // Wait for connection
      await _waitForConnection();
      
      debugPrint('Signaling service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize signaling service: $e');
      rethrow;
    }
  }

  /// Connect to signaling server with user authentication
  Future<void> connect(String userId, String authToken) async {
    try {
      _currentUserId = userId;
      
      if (_socket != null && !_isConnected) {
        _socket!.emit('authenticate', {
          'userId': userId,
          'authToken': authToken,
        });
      }
    } catch (e) {
      debugPrint('Failed to connect to signaling server: $e');
      rethrow;
    }
  }

  /// Send WebRTC offer
  Future<void> sendOffer(String callId, RTCSessionDescription offer) async {
    try {
      if (_socket != null && _isConnected) {
        _socket!.emit('offer', {
          'callId': callId,
          'offer': {
            'type': offer.type,
            'sdp': offer.sdp,
          },
        });
      } else {
        throw Exception('Signaling server not connected');
      }
    } catch (e) {
      debugPrint('Failed to send offer: $e');
      rethrow;
    }
  }

  /// Send WebRTC answer
  Future<void> sendAnswer(String callId, RTCSessionDescription answer) async {
    try {
      if (_socket != null && _isConnected) {
        _socket!.emit('answer', {
          'callId': callId,
          'answer': {
            'type': answer.type,
            'sdp': answer.sdp,
          },
        });
      } else {
        throw Exception('Signaling server not connected');
      }
    } catch (e) {
      debugPrint('Failed to send answer: $e');
      rethrow;
    }
  }

  /// Send ICE candidate
  Future<void> sendIceCandidate(String callId, RTCIceCandidate candidate) async {
    try {
      if (_socket != null && _isConnected) {
        _socket!.emit('ice-candidate', {
          'callId': callId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      } else {
        throw Exception('Signaling server not connected');
      }
    } catch (e) {
      debugPrint('Failed to send ICE candidate: $e');
      rethrow;
    }
  }

  /// Create a call room for multiple participants
  Future<String> createCallRoom(List<String> participants) async {
    try {
      if (_socket != null && _isConnected) {
        final completer = Completer<String>();
        
        _socket!.emit('create-room', {
          'participants': participants,
        });

        _socket!.once('room-created', (data) {
          completer.complete(data['roomId']);
        });

        return await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Room creation timeout'),
        );
      } else {
        throw Exception('Signaling server not connected');
      }
    } catch (e) {
      debugPrint('Failed to create call room: $e');
      rethrow;
    }
  }

  /// Join a call room
  Future<void> joinCallRoom(String roomId, String userId) async {
    try {
      if (_socket != null && _isConnected) {
        _socket!.emit('join-room', {
          'roomId': roomId,
          'userId': userId,
        });
      } else {
        throw Exception('Signaling server not connected');
      }
    } catch (e) {
      debugPrint('Failed to join call room: $e');
      rethrow;
    }
  }

  /// Leave a call room
  Future<void> leaveCallRoom(String roomId, String userId) async {
    try {
      if (_socket != null && _isConnected) {
        _socket!.emit('leave-room', {
          'roomId': roomId,
          'userId': userId,
        });
      } else {
        throw Exception('Signaling server not connected');
      }
    } catch (e) {
      debugPrint('Failed to leave call room: $e');
      rethrow;
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall(String callId) async {
    try {
      if (_socket != null && _isConnected) {
        _socket!.emit('reject-call', {
          'callId': callId,
        });
      } else {
        throw Exception('Signaling server not connected');
      }
    } catch (e) {
      debugPrint('Failed to reject call: $e');
      rethrow;
    }
  }

  /// End an active call
  Future<void> endCall(String callId) async {
    try {
      if (_socket != null && _isConnected) {
        _socket!.emit('end-call', {
          'callId': callId,
        });
      } else {
        throw Exception('Signaling server not connected');
      }
    } catch (e) {
      debugPrint('Failed to end call: $e');
      rethrow;
    }
  }

  /// Get TURN server credentials
  Future<TurnCredentials?> getTurnCredentials() async {
    try {
      if (_socket != null && _isConnected) {
        final completer = Completer<TurnCredentials?>();
        
        _socket!.emit('get-turn-credentials');

        _socket!.once('turn-credentials', (data) {
          if (data != null && data['urls'] != null) {
            completer.complete(TurnCredentials(
              urls: data['urls'],
              username: data['username'] ?? '',
              credential: data['credential'] ?? '',
            ));
          } else {
            completer.complete(null);
          }
        });

        return await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get TURN credentials: $e');
      return null;
    }
  }

  /// Get optimal TURN server based on user location
  Future<TurnServer?> getOptimalTurnServer(String userLocation) async {
    try {
      if (_socket != null && _isConnected) {
        final completer = Completer<TurnServer?>();
        
        _socket!.emit('get-optimal-turn-server', {
          'location': userLocation,
        });

        _socket!.once('optimal-turn-server', (data) {
          if (data != null && data['url'] != null) {
            completer.complete(TurnServer(
              url: data['url'],
              region: data['region'] ?? '',
              latency: data['latency'] ?? 0,
            ));
          } else {
            completer.complete(null);
          }
        });

        return await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get optimal TURN server: $e');
      return null;
    }
  }

  // Private methods

  void _setupSocketListeners() {
    _socket!.on('connect', (_) {
      _isConnected = true;
      debugPrint('Connected to signaling server');
    });

    _socket!.on('disconnect', (_) {
      _isConnected = false;
      debugPrint('Disconnected from signaling server');
    });

    _socket!.on('authenticated', (data) {
      debugPrint('Authenticated with signaling server: ${data['userId']}');
    });

    _socket!.on('offer', (data) {
      final callId = data['callId'];
      final offerData = data['offer'];
      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      
      if (onOffer != null) {
        onOffer!(callId, offer);
      }
    });

    _socket!.on('answer', (data) {
      final callId = data['callId'];
      final answerData = data['answer'];
      final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
      
      if (onAnswer != null) {
        onAnswer!(callId, answer);
      }
    });

    _socket!.on('ice-candidate', (data) {
      final callId = data['callId'];
      final candidateData = data['candidate'];
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      
      if (onIceCandidate != null) {
        onIceCandidate!(callId, candidate);
      }
    });

    _socket!.on('incoming-call', (data) {
      final incomingCall = IncomingCall(
        id: data['callId'],
        callerId: data['callerId'],
        callerName: data['callerName'] ?? 'Unknown',
        callerRole: data['callerRole'] ?? 'member',
        callType: data['callType'] ?? 'voice',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      
      if (onIncomingCall != null) {
        onIncomingCall!(incomingCall);
      }
    });

    _socket!.on('call-ended', (data) {
      final callId = data['callId'];
      debugPrint('Call ended: $callId');
    });

    _socket!.on('call-rejected', (data) {
      final callId = data['callId'];
      debugPrint('Call rejected: $callId');
    });

    _socket!.on('error', (data) {
      debugPrint('Signaling server error: $data');
    });
  }

  Future<void> _waitForConnection() async {
    int attempts = 0;
    const maxAttempts = 10;
    
    while (!_isConnected && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    
    if (!_isConnected) {
      throw Exception('Failed to connect to signaling server after $maxAttempts attempts');
    }
  }

  /// Disconnect from signaling server
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
    _isConnected = false;
    _currentUserId = null;
  }

  /// Check if connected to signaling server
  bool get isConnected => _isConnected;

  /// Get current user ID
  String? get currentUserId => _currentUserId;
}

/// TURN server information
class TurnServer {
  final String url;
  final String region;
  final int latency;

  TurnServer({
    required this.url,
    required this.region,
    required this.latency,
  });
}
