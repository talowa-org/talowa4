// Authentication State Manager
// Ensures persistent login sessions and prevents accidental logout

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStateManager {
  static const String _tag = 'AuthStateManager';
  static const String _sessionKey = 'user_session_active';
  static const String _lastLoginKey = 'last_login_timestamp';

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize authentication state management
  static Future<void> initialize() async {
    try {
      // Set up persistent session
      await _setupPersistentSession();

      // Listen for auth state changes but prevent unwanted logouts
      _auth.authStateChanges().listen(_handleAuthStateChange);

      debugPrint('$_tag: Authentication state manager initialized');
    } catch (e) {
      debugPrint('$_tag: Failed to initialize auth state manager: $e');
    }
  }

  /// Set up persistent session to maintain login across app restarts
  static Future<void> _setupPersistentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        // User is logged in, mark session as active
        await prefs.setBool(_sessionKey, true);
        await prefs.setInt(_lastLoginKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('$_tag: Active session detected for user: ${currentUser.uid}');
      } else {
        // No user logged in, clear session
        await prefs.setBool(_sessionKey, false);
        debugPrint('$_tag: No active session found');
      }
    } catch (e) {
      debugPrint('$_tag: Error setting up persistent session: $e');
    }
  }

  /// Handle authentication state changes
  static void _handleAuthStateChange(User? user) {
    try {
      if (user != null) {
        debugPrint('$_tag: User authenticated: ${user.uid}');
        _markSessionActive();
      } else {
        debugPrint('$_tag: User signed out');
        _markSessionInactive();
      }
    } catch (e) {
      debugPrint('$_tag: Error handling auth state change: $e');
    }
  }

  /// Mark session as active
  static Future<void> _markSessionActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      await prefs.setInt(_lastLoginKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('$_tag: Error marking session active: $e');
    }
  }

  /// Mark session as inactive
  static Future<void> _markSessionInactive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, false);
    } catch (e) {
      debugPrint('$_tag: Error marking session inactive: $e');
    }
  }

  /// Check if user has an active session
  static Future<bool> hasActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_sessionKey) ?? false;
      final currentUser = _auth.currentUser;

      // Session is active if both SharedPreferences and Firebase Auth agree
      return isActive && currentUser != null;
    } catch (e) {
      debugPrint('$_tag: Error checking active session: $e');
      return false;
    }
  }

  /// Get current authenticated user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => _auth.currentUser != null;

  /// Safely sign out user (only when explicitly requested)
  static Future<void> signOut({required bool isExplicitLogout}) async {
    try {
      if (!isExplicitLogout) {
        debugPrint('$_tag: Preventing accidental logout - not an explicit logout request');
        return;
      }

      debugPrint('$_tag: Explicit logout requested - signing out user');

      // Clear session data
      await _markSessionInactive();

      // Sign out from Firebase
      await _auth.signOut();

      debugPrint('$_tag: User successfully signed out');
    } catch (e) {
      debugPrint('$_tag: Error during sign out: $e');
    }
  }

  /// Prevent accidental logout from navigation
  static bool shouldPreventLogout() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('$_tag: No user logged in, logout prevention not needed');
      return false;
    }

    debugPrint('$_tag: User is logged in, preventing accidental logout');
    return true;
  }

  /// Get authentication stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Restore session if user was previously logged in
  static Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasActive = prefs.getBool(_sessionKey) ?? false;
      final currentUser = _auth.currentUser;

      if (wasActive && currentUser != null) {
        debugPrint('$_tag: Restoring previous session for user: ${currentUser.uid}');
        await _markSessionActive();
        return true;
      }

      debugPrint('$_tag: No previous session to restore');
      return false;
    } catch (e) {
      debugPrint('$_tag: Error restoring session: $e');
      return false;
    }
  }

  /// Get session info for debugging
  static Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_sessionKey) ?? false;
      final lastLogin = prefs.getInt(_lastLoginKey) ?? 0;
      final currentUser = _auth.currentUser;

      return {
        'isSessionActive': isActive,
        'lastLoginTimestamp': lastLogin,
        'lastLoginDate': DateTime.fromMillisecondsSinceEpoch(lastLogin).toString(),
        'hasCurrentUser': currentUser != null,
        'userId': currentUser?.uid,
        'userEmail': currentUser?.email,
      };
    } catch (e) {
      debugPrint('$_tag: Error getting session info: $e');
      return {'error': e.toString()};
    }
  }
}