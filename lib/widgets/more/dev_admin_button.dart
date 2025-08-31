// Development Admin Button - Quick access for testing (remove in production)
import 'package:flutter/material.dart';
import '../../screens/admin/admin_login_screen.dart';

class DevAdminButton extends StatelessWidget {
  const DevAdminButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    bool isDebugMode = false;
    assert(isDebugMode = true); // This only executes in debug mode
    
    if (!isDebugMode) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminLoginScreen(),
            ),
          );
        },
        icon: const Icon(Icons.admin_panel_settings),
        label: const Text('DEV: Admin Login'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }
}