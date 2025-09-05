import 'package:flutter/material.dart';
import '../../models/call_participant.dart';

/// Participant avatar widget for voice calls
class ParticipantAvatar extends StatelessWidget {
  final CallParticipant? participant;
  final double size;
  final bool showConnectionStatus;

  const ParticipantAvatar({
    super.key,
    required this.participant,
    this.size = 80,
    this.showConnectionStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main avatar
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getAvatarColor().withOpacity(0.8),
                _getAvatarColor(),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              _getInitials(),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Connection status indicator
        if (showConnectionStatus && participant != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: _getConnectionColor(),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),

        // Mute indicator
        if (participant?.isMuted == true)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_off,
                color: Colors.white,
                size: size * 0.15,
              ),
            ),
          ),
      ],
    );
  }

  String _getInitials() {
    if (participant?.name == null || participant!.name.isEmpty) {
      return '?';
    }

    final nameParts = participant!.name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else {
      return participant!.name.substring(0, 1).toUpperCase();
    }
  }

  Color _getAvatarColor() {
    if (participant?.name == null) {
      return Colors.grey;
    }

    // Generate color based on name hash
    final hash = participant!.name.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
    ];

    return colors[hash.abs() % colors.length];
  }

  Color _getConnectionColor() {
    if (participant == null) return Colors.grey;

    switch (participant!.connectionQuality) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'poor':
        return Colors.orange;
      case 'disconnected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
