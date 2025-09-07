import 'package:flutter/material.dart';

/// Call controls widget for voice calls
class CallControlsWidget extends StatelessWidget {
  final bool isMuted;
  final bool isSpeakerOn;
  final VoidCallback onMuteToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onEndCall;

  const CallControlsWidget({
    super.key,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.onMuteToggle,
    required this.onSpeakerToggle,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute/Unmute button
        _buildControlButton(
          icon: isMuted ? Icons.mic_off : Icons.mic,
          isActive: isMuted,
          onTap: onMuteToggle,
          backgroundColor: isMuted ? Colors.red : Colors.white.withValues(alpha: 0.2),
          iconColor: isMuted ? Colors.white : Colors.white,
        ),

        // End call button
        _buildControlButton(
          icon: Icons.call_end,
          isActive: false,
          onTap: onEndCall,
          backgroundColor: Colors.red,
          iconColor: Colors.white,
          size: 70,
        ),

        // Speaker toggle button
        _buildControlButton(
          icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          isActive: isSpeakerOn,
          onTap: onSpeakerToggle,
          backgroundColor: isSpeakerOn ? Colors.blue : Colors.white.withValues(alpha: 0.2),
          iconColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color iconColor,
    double size = 60,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: size * 0.4,
        ),
      ),
    );
  }
}

