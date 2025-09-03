// Authentication Wrapper
// Manages authentication state and prevents logout from navigation

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/auth_state_manager.dart';
import '../../screens/auth/welcome_screen.dart';
import '../../screens/main/main_navigation_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;
  bool _hasActiveSession = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      // Check if user has an active session
      final hasSession = await AuthStateManager.hasActiveSession();

      if (mounted) {
        setState(() {
          _hasActiveSession = hasSession;
          _isInitialized = true;
        });
      }
      
      debugPrint('AuthWrapper: Initialized with session: $hasSession');
    } catch (e) {
      debugPrint('AuthWrapper: Error initializing auth: $e');
      if (mounted) {
        setState(() {
          _hasActiveSession = false;
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: AuthStateManager.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check if user is authenticated
        final user = snapshot.data;
        final isAuthenticated = user != null && _hasActiveSession;

        debugPrint('AuthWrapper: User authenticated: $isAuthenticated');

        if (isAuthenticated) {
          return const MainNavigationScreen();
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}