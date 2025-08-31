// Hidden Admin Access - Tap sequence to reveal admin login
import 'package:flutter/material.dart';
import '../../screens/admin/admin_login_screen.dart';

class HiddenAdminAccess extends StatefulWidget {
  final Widget child;
  
  const HiddenAdminAccess({
    super.key,
    required this.child,
  });

  @override
  State<HiddenAdminAccess> createState() => _HiddenAdminAccessState();
}

class _HiddenAdminAccessState extends State<HiddenAdminAccess> {
  int _tapCount = 0;
  DateTime? _lastTap;
  
  // Secret sequence: 7 taps within 10 seconds
  static const int requiredTaps = 7;
  static const int timeoutSeconds = 10;

  void _onTap() {
    final now = DateTime.now();
    
    // Reset if too much time has passed
    if (_lastTap != null && 
        now.difference(_lastTap!).inSeconds > timeoutSeconds) {
      _tapCount = 0;
    }
    
    _tapCount++;
    _lastTap = now;
    
    if (_tapCount >= requiredTaps) {
      _showAdminAccess();
      _tapCount = 0; // Reset
    } else if (_tapCount >= 3) {
      // Give a hint after 3 taps
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${requiredTaps - _tapCount} more taps for admin access'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.grey[600],
        ),
      );
    }
  }
  
  void _showAdminAccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.red),
            SizedBox(width: 8),
            Text('Admin Access'),
          ],
        ),
        content: const Text(
          'You have discovered the admin access panel. This is for authorized administrators only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminLoginScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
            ),
            child: const Text('Admin Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: widget.child,
    );
  }
}