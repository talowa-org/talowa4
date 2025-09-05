import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NavigationGuardService {
  static bool _isInitialized = false;
  
  /// Initialize the navigation guard service
  static void initialize() {
    if (!_isInitialized) {
      _isInitialized = true;
      debugPrint('NavigationGuardService initialized');
    }
  }
  
  /// Check if user is authenticated
  static bool isAuthenticated() {
    return FirebaseAuth.instance.currentUser != null;
  }
  
  /// Guard navigation to protected routes
  static bool canNavigate(String route) {
    // Public routes that don't require authentication
    const publicRoutes = [
      '/welcome',
      '/login',
      '/register',
      '/forgot-password',
    ];
    
    if (publicRoutes.contains(route)) {
      return true;
    }
    
    // All other routes require authentication
    return isAuthenticated();
  }
  
  /// Navigate with authentication check
  static Future<void> navigateWithGuard(
    BuildContext context,
    String route, {
    Map<String, dynamic>? arguments,
    bool replace = false,
  }) async {
    if (canNavigate(route)) {
      if (replace) {
        Navigator.pushReplacementNamed(context, route, arguments: arguments);
      } else {
        Navigator.pushNamed(context, route, arguments: arguments);
      }
    } else {
      // Redirect to login if not authenticated
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/welcome',
        (route) => false,
      );
    }
  }
  
  /// Show access denied message
  static void showAccessDenied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please login to access this feature'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
