// Admin Route Handler - Secure admin access with proper authentication
import 'package:flutter/material.dart';
import '../services/admin/enhanced_admin_auth_service.dart';
import '../screens/admin/secure_admin_login_screen.dart';
import '../screens/admin/enterprise_admin_dashboard_screen.dart';

class AdminRoute {
  /// Navigate to admin panel with proper authentication checks
  static Future<void> navigateToAdmin(BuildContext context) async {
    if (!context.mounted) return;
    
    try {
      // Check if user is already authenticated with admin role
      final accessCheck = await EnhancedAdminAuthService.checkAdminAccess();
      
      if (!context.mounted) return;
      
      if (accessCheck.success) {
        // User has admin access, go directly to dashboard
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EnterpriseAdminDashboardScreen(),
          ),
        );
      } else {
        // User needs to authenticate, show login screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SecureAdminLoginScreen(),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      
      // Error checking access, show login screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SecureAdminLoginScreen(),
        ),
      );
    }
  }

  /// Check if current user has admin access
  static Future<bool> hasAdminAccess() async {
    try {
      final accessCheck = await EnhancedAdminAuthService.checkAdminAccess();
      return accessCheck.success;
    } catch (e) {
      return false;
    }
  }

  /// Get current admin role if user has access
  static Future<String?> getCurrentAdminRole() async {
    try {
      final accessCheck = await EnhancedAdminAuthService.checkAdminAccess();
      return accessCheck.success ? accessCheck.role : null;
    } catch (e) {
      return null;
    }
  }
}