import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/voice_call.dart';
import '../../services/messaging/voice_calling_integration_service.dart';

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
  final VoiceCallingIntegrationService _voiceService = VoiceCallingIntegrationService();
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  String _callDuration = '00:00';
  String _callStatus = 'Connecting...';
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _pulseController.repeat(reverse: true);
    
    _updateCallStatus();
    _startDurationTimer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateCallStatus() {
    setState(() {
      switch (widget.callSession.status) {
        case 'connecting':
          _callStatus = 'Connecting...';
          break;
        case 'connected':
          _callStatus = 'Connected';
          break;
        case 'ended':
          _callStatus = 'Call Ended';
          break;
        case 'failed':
          _callStatus = 'Call Failed';
          break;
        default:
          _callStatus = 'Unknown';
      }
    });
  }

  void _startDurationTimer() {
    // Update call duration every second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && widget.callSession.isActive) {
        final duration = widget.callSession.duration;
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        setState(() {
          _callDuration = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        });
        _startDurationTimer();
      }
    });
  }

  Future<void> _endCall() async {
    try {
      await _voiceService.endCall(widget.callSession.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Failed to end call: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _toggleMute() async {
    try {
      await _voiceService.muteAudio(widget.callSession.id, !_isMuted);
      setState(() {
        _isMuted = !_isMuted;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to toggle mute: $e');
    }
  }

  Future<void> _toggleSpeaker() async {
    try {
      await _voiceService.toggleSpeaker(widget.callSession.id, !_isSpeakerOn);
      setState(() {
        _isSpeakerOn = !_isSpeakerOn;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to toggle speaker: $e');
    }
  }

  String _getOtherParticipantName() {
    final currentUser = widget.callSession.participants.first;
    final otherParticipant = widget.callSession.participants.firstWhere(
      (p) => p.userId != currentUser.userId,
      orElse: () => widget.callSession.participants.first,
    );
    return otherParticipant.name;
  }

  String _getOtherParticipantRole() {
    final currentUser = widget.callSession.participants.first;
    final otherParticipant = widget.callSession.participants.firstWhere(
      (p) => p.userId != currentUser.userId,
      orElse: () => widget.callSession.participants.first,
    );
    return otherParticipant.role;
  }

  String _getParticipantInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return name.substring(0, 1).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    widget.isIncoming ? 'Incoming Call' : 'Outgoing Call',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            
            // Call info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Participant avatar
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: widget.callSession.status == 'connected' ? 1.0 : _pulseAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.withValues(alpha: 0.2),
                                Colors.blue,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getParticipantInitials(_getOtherParticipantName()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Participant name
                  Text(
                    _getOtherParticipantName(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Participant role
                  Text(
                    _getOtherParticipantRole().toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Call status
                  Text(
                    _callStatus,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 16,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Call duration
                  if (widget.callSession.status == 'connected')
                    Text(
                      _callDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            
            // Call controls
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isMuted ? Colors.red : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  
                  // End call button
                  GestureDetector(
                    onTap: _endCall,
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
                  
                  // Speaker button
                  GestureDetector(
                    onTap: _toggleSpeaker,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isSpeakerOn ? Colors.blue : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Call quality indicator
            if (widget.callSession.status == 'connected')
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.signal_cellular_4_bar,
                      color: _getQualityColor(),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getQualityText(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getQualityColor() {
    final quality = _voiceService.getCallQuality(widget.callSession.id);
    if (quality == null) return Colors.grey;
    
    switch (quality.qualityLevel) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getQualityText() {
    final quality = _voiceService.getCallQuality(widget.callSession.id);
    if (quality == null) return 'Checking quality...';
    
    return quality.description;
  }
}