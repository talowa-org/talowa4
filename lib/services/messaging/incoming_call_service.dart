import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/voice_call.dart';
import '../../screens/messaging/voice_call_screen.dart';
import '../notifications/local_notification_service.dart';
import 'webrtc_service.dart';
import 'call_history_service.dart';

/// Service for handling incoming call notifications and UI
class IncomingCallService {
  static final IncomingCallService _instance = IncomingCallService._internal();
  factory IncomingCallService() => _instance;
  IncomingCallService._internal();

  final WebRTCService _webrtcService = WebRTCService();
  final CallHistoryService _callHistoryService = CallHistoryService();
  final LocalNotificationService _notificationService = LocalNotificationService();

  OverlayEntry? _currentCallOverlay;
  IncomingCall? _currentIncomingCall;
  Timer? _callTimeoutTimer;

  /// Initialize the incoming call service
  Future<void> initialize() async {
    try {
      // Listen for incoming calls
      _webrtcService.onIncomingCall.listen(_handleIncomingCall);
      
      debugPrint('Incoming call service initialized');
    } catch (e) {
      debugPrint('Failed to initialize incoming call service: $e');
    }
  }

  /// Handle incoming call
  void _handleIncomingCall(IncomingCall incomingCall) {
    try {
      _currentIncomingCall = incomingCall;
      
      // Show incoming call notification
      _showIncomingCallNotification(incomingCall);
      
      // Show incoming call overlay
      _showIncomingCallOverlay(incomingCall);
      
      // Set timeout for missed call
      _setCallTimeout(incomingCall);
      
      // Vibrate device
      _vibrateForIncomingCall();
      
      debugPrint('Handling incoming call: ${incomingCall.id}');
    } catch (e) {
      debugPrint('Failed to handle incoming call: $e');
    }
  }

  /// Show incoming call notification
  Future<void> _showIncomingCallNotification(IncomingCall incomingCall) async {
    try {
      await _notificationService.showIncomingCallNotification(
        callId: incomingCall.id,
        callerName: incomingCall.callerName,
        callerRole: incomingCall.callerRole,
      );
    } catch (e) {
      debugPrint('Failed to show incoming call notification: $e');
    }
  }

  /// Show incoming call overlay
  void _showIncomingCallOverlay(IncomingCall incomingCall) {
    try {
      // Remove any existing overlay
      _removeIncomingCallOverlay();

      final context = _getOverlayContext();
      if (context == null) return;

      _currentCallOverlay = OverlayEntry(
        builder: (context) => IncomingCallOverlay(
          incomingCall: incomingCall,
          onAccept: () => _acceptCall(incomingCall),
          onReject: () => _rejectCall(incomingCall),
          onDismiss: () => _dismissCallOverlay(),
        ),
      );

      Overlay.of(context).insert(_currentCallOverlay!);
    } catch (e) {
      debugPrint('Failed to show incoming call overlay: $e');
    }
  }

  /// Accept incoming call
  Future<void> _acceptCall(IncomingCall incomingCall) async {
    try {
      _removeIncomingCallOverlay();
      _cancelCallTimeout();
      
      final callSession = await _webrtcService.acceptCall(incomingCall.id);
      
      final context = _getNavigatorContext();
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VoiceCallScreen(
              callSession: callSession,
              isIncoming: true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to accept call: $e');
      _rejectCall(incomingCall);
    }
  }

  /// Reject incoming call
  Future<void> _rejectCall(IncomingCall incomingCall) async {
    try {
      _removeIncomingCallOverlay();
      _cancelCallTimeout();
      
      await _webrtcService.rejectCall(incomingCall.id);
      
      // Clear current incoming call
      _currentIncomingCall = null;
    } catch (e) {
      debugPrint('Failed to reject call: $e');
    }
  }

  /// Handle missed call (timeout)
  Future<void> _handleMissedCall(IncomingCall incomingCall) async {
    try {
      _removeIncomingCallOverlay();
      
      // Save as missed call
      await _callHistoryService.saveMissedCall(incomingCall);
      
      // Show missed call notification
      await _notificationService.showMissedCallNotification(
        callId: incomingCall.id,
        callerName: incomingCall.callerName,
        callerRole: incomingCall.callerRole,
      );
      
      // Clear current incoming call
      _currentIncomingCall = null;
      
      debugPrint('Call missed: ${incomingCall.id}');
    } catch (e) {
      debugPrint('Failed to handle missed call: $e');
    }
  }

  /// Set call timeout timer
  void _setCallTimeout(IncomingCall incomingCall) {
    _cancelCallTimeout();
    
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      _handleMissedCall(incomingCall);
    });
  }

  /// Cancel call timeout timer
  void _cancelCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  /// Remove incoming call overlay
  void _removeIncomingCallOverlay() {
    _currentCallOverlay?.remove();
    _currentCallOverlay = null;
  }

  /// Dismiss call overlay without accepting/rejecting
  void _dismissCallOverlay() {
    _removeIncomingCallOverlay();
  }

  /// Vibrate device for incoming call
  void _vibrateForIncomingCall() {
    try {
      HapticFeedback.heavyImpact();
      
      // Repeat vibration pattern
      Timer.periodic(const Duration(seconds: 2), (timer) {
        if (_currentIncomingCall == null) {
          timer.cancel();
          return;
        }
        HapticFeedback.heavyImpact();
      });
    } catch (e) {
      debugPrint('Failed to vibrate for incoming call: $e');
    }
  }

  /// Get overlay context
  BuildContext? _getOverlayContext() {
    // This would need to be set by the main app
    // For now, return null and handle gracefully
    return null;
  }

  /// Get navigator context
  BuildContext? _getNavigatorContext() {
    // This would need to be set by the main app
    // For now, return null and handle gracefully
    return null;
  }

  /// Check if there's an active incoming call
  bool get hasActiveIncomingCall => _currentIncomingCall != null;

  /// Get current incoming call
  IncomingCall? get currentIncomingCall => _currentIncomingCall;

  /// Dispose resources
  void dispose() {
    _removeIncomingCallOverlay();
    _cancelCallTimeout();
    _currentIncomingCall = null;
  }
}

/// Incoming call overlay widget
class IncomingCallOverlay extends StatefulWidget {
  final IncomingCall incomingCall;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDismiss;

  const IncomingCallOverlay({
    super.key,
    required this.incomingCall,
    required this.onAccept,
    required this.onReject,
    required this.onDismiss,
  });

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.4,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1A1A),
                Color(0xFF2A2A2A),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Caller info
                Text(
                  'Incoming Call',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Caller avatar (animated)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.8),
                              Colors.blue,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getCallerInitials(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Caller name
                Text(
                  widget.incomingCall.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Caller role
                Text(
                  widget.incomingCall.callerRole.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Call controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject button
                    GestureDetector(
                      onTap: widget.onReject,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    
                    // Accept button
                    GestureDetector(
                      onTap: widget.onAccept,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCallerInitials() {
    final name = widget.incomingCall.callerName;
    if (name.isEmpty) return '?';
    
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return name.substring(0, 1).toUpperCase();
    }
  }
}