// Emergency Broadcast Button Widget
// Task 9: Build emergency broadcast system - UI Component
// Requirements: 5.5 - Quick access for coordinators

import 'package:flutter/material.dart';
import '../../screens/emergency/emergency_broadcast_screen.dart';
import '../../services/auth/auth_service.dart';

class EmergencyBroadcastButton extends StatelessWidget {
  final bool isFloatingAction;
  final VoidCallback? onPressed;

  const EmergencyBroadcastButton({
    super.key,
    this.isFloatingAction = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkCoordinatorPermissions(),
      builder: (context, snapshot) {
        // Only show button for coordinators
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }

        if (isFloatingAction) {
          return FloatingActionButton.extended(
            onPressed: () => _handlePress(context),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.campaign),
            label: const Text('Emergency Alert'),
            heroTag: 'emergency_broadcast',
          );
        }

        return ElevatedButton.icon(
          onPressed: () => _handlePress(context),
          icon: const Icon(Icons.campaign),
          label: const Text('Emergency Broadcast'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
      },
    );
  }

  void _handlePress(BuildContext context) {
    if (onPressed != null) {
      onPressed!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmergencyBroadcastScreen(),
        ),
      );
    }
  }

  Future<bool> _checkCoordinatorPermissions() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return false;

      // Check if user has coordinator role
      // This would typically check the user's role from Firestore
      // For now, we'll assume any authenticated user can be a coordinator
      return true;
    } catch (e) {
      return false;
    }
  }
}

// Quick Emergency Actions Widget for Home Screen
class QuickEmergencyActions extends StatelessWidget {
  const QuickEmergencyActions({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkCoordinatorPermissions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Emergency Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToEmergencyBroadcast(context),
                        icon: const Icon(Icons.campaign),
                        label: const Text('Send Alert'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToBroadcastHistory(context),
                        icon: const Icon(Icons.history),
                        label: const Text('History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToEmergencyBroadcast(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyBroadcastScreen(),
      ),
    );
  }

  void _navigateToBroadcastHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BroadcastHistoryScreen(),
      ),
    );
  }

  Future<bool> _checkCoordinatorPermissions() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return false;

      // Check if user has coordinator role
      // This would typically check the user's role from Firestore
      return true;
    } catch (e) {
      return false;
    }
  }
}

// Emergency Alert Banner for displaying received emergency alerts
class EmergencyAlertBanner extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const EmergencyAlertBanner({
    super.key,
    required this.title,
    required this.message,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ðŸš¨ $title',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
