import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/voice_call.dart';
import '../../models/call_participant.dart';
import '../../models/call_quality.dart';
import '../../services/messaging/webrtc_service.dart';
import '../../widgets/messaging/call_controls_widget.dart';
import '../../widgets/messaging/call_quality_indicator.dart';
import '../../widgets/messaging/participant_avatar.dart';
import '../../widgets/onboarding/contextual_tips_widget.dart';

/// Voice call screen for active calls
class VoiceCallScreen extends StatefulWidget {
  final CallSession callSession;
  final bool isIncoming;

  const VoiceCallScreen({
    super.key,
    required this.callSession,
    this.isIncoming = false,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  final WebRTCService _webrtcService = WebRTCService();
  
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _showQualityDetails = false;
  CallSession? _currentCall;
  CallQuality? _currentQuality;

  @override
  void initState() {
    super.initState();
    _currentCall = widget.callSession;
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Start animations
    _pulseController.repeat(reverse: true);
    _fadeController.forward();

    // Listen to call status changes
    _webrtcService.onCallStatusChange.listen(_handleCallStatusChange);
    _webrtcService.onCallQualityChange.listen(_handleCallQualityChange);

    // Set system UI for call screen
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleCallStatusChange(CallStatus status) {
    if (status.callId == _currentCall?.id) {
      setState(() {
        if (_currentCall != null) {
          _currentCall = _currentCall!.copyWith(status: status.status);
        }
      });

      // Handle call end
      if (status.status == 'ended' || status.status == 'failed') {
        _endCall();
      }
    }
  }

  void _handleCallQualityChange(CallQuality quality) {
    setState(() {
      _currentQuality = quality;
      if (_currentCall != null) {
        _currentCall = _currentCall!.copyWith(quality: quality);
      }
    });
  }

  Future<void> _toggleMute() async {
    try {
      setState(() {
        _isMuted = !_isMuted;
      });
      
      if (_currentCall != null) {
        await _webrtcService.muteAudio(_currentCall!.id, _isMuted);
      }
    } catch (e) {
      debugPrint('Failed to toggle mute: $e');
      // Revert state on error
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  Future<void> _toggleSpeaker() async {
    try {
      setState(() {
        _isSpeakerOn = !_isSpeakerOn;
      });
      
      if (_currentCall != null) {
        await _webrtcService.toggleSpeaker(_currentCall!.id, _isSpeakerOn);
      }
    } catch (e) {
      debugPrint('Failed to toggle speaker: $e');
      // Revert state on error
      setState(() {
        _isSpeakerOn = !_isSpeakerOn;
      });
    }
  }

  Future<void> _endCall() async {
    try {
      if (_currentCall != null) {
        await _webrtcService.endCall(_currentCall!.id);
      }
    } catch (e) {
      debugPrint('Failed to end call: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _acceptCall() async {
    try {
      if (_currentCall != null) {
        await _webrtcService.acceptCall(_currentCall!.id);
      }
    } catch (e) {
      debugPrint('Failed to accept call: $e');
      _endCall();
    }
  }

  Future<void> _rejectCall() async {
    try {
      if (_currentCall != null) {
        await _webrtcService.rejectCall(_currentCall!.id);
      }
    } catch (e) {
      debugPrint('Failed to reject call: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  CallParticipant? _getOtherParticipant() {
    if (_currentCall == null) return null;
    
    // For now, assume current user is first participant
    return _currentCall!.participants.length > 1 
        ? _currentCall!.participants[1] 
        : null;
  }

  String _getCallStatusText() {
    if (_currentCall == null) return 'Connecting...';
    
    switch (_currentCall!.status) {
      case 'connecting':
        return widget.isIncoming ? 'Incoming call...' : 'Connecting...';
      case 'connected':
        return 'Connected â€¢ ${_formatDuration(_currentCall!.duration)}';
      case 'ended':
        return 'Call ended';
      case 'failed':
        return 'Call failed';
      default:
        return _currentCall!.status;
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final otherParticipant = _getOtherParticipant();
    final isConnected = _currentCall?.status == 'connected';
    final isIncoming = widget.isIncoming && _currentCall?.status == 'connecting';

    return ContextualTipsWidget(
      screenName: 'voice_call_screen',
      child: Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Top section with quality indicator
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.keyboard_arrow_down, 
                                     color: Colors.white, size: 28),
                    ),
                    if (_currentQuality != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _showQualityDetails = !_showQualityDetails;
                        }),
                        child: CallQualityIndicator(
                          quality: _currentQuality!,
                          showDetails: _showQualityDetails,
                        ),
                      ),
                  ],
                ),
              ),

              // Main content area
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Participant avatar
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: isConnected ? 1.0 : _pulseAnimation.value,
                          child: ParticipantAvatar(
                            participant: otherParticipant,
                            size: 120,
                            showConnectionStatus: true,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Participant name
                    Text(
                      otherParticipant?.name ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Participant role
                    if (otherParticipant?.role != null)
                      Text(
                        otherParticipant!.role.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Call status
                    Text(
                      _getCallStatusText(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Quality details (if shown)
                    if (_showQualityDetails && _currentQuality != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _currentQuality!.description,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildQualityMetric(
                                  'Latency', 
                                  '${_currentQuality!.averageLatency.round()}ms'
                                ),
                                _buildQualityMetric(
                                  'Loss', 
                                  '${_currentQuality!.packetLoss.toStringAsFixed(1)}%'
                                ),
                                _buildQualityMetric(
                                  'Jitter', 
                                  '${_currentQuality!.jitter.round()}ms'
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Call controls
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: isIncoming
                    ? _buildIncomingCallControls()
                    : CallControlsWidget(
                        isMuted: _isMuted,
                        isSpeakerOn: _isSpeakerOn,
                        onMuteToggle: _toggleMute,
                        onSpeakerToggle: _toggleSpeaker,
                        onEndCall: _endCall,
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildQualityMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Reject call button
        GestureDetector(
          onTap: _rejectCall,
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

        // Accept call button
        GestureDetector(
          onTap: _acceptCall,
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
    );
  }
}
