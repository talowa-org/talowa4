// âš ï¸ CRITICAL WARNING - AUTHENTICATION SYSTEM PROTECTION âš ï¸
// This is the WORKING welcome screen from Checkpoint 7
// DO NOT MODIFY without explicit user approval
// See: AUTHENTICATION_PROTECTION_STRATEGY.md
// Working commit: 3a00144 (Checkpoint 6 base)
// Last verified: September 3rd, 2025

// Welcome Screen for TALOWA - Real User Experience
// First screen users see when opening the app

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../auth/login.dart';
import 'mobile_entry_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _fadeController.forward();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      _slideController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5), // Light gray background like in the image
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildHeroSection(),
                  ),

                  const SizedBox(height: 40),

                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildActionSection(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),

        // App Logo - Mountain icon like in the image
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: AppTheme.talowaGreen,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              // Mountain peaks icon
              Icon(Icons.terrain, size: 70, color: Colors.white),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // Organization Name
        const Text(
          'Telangana Assigned Land Owners Welfare\nAssociation',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryText,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Mission Statement
        const Text(
          'Empowering landowners, preserving rights, and\nuniting voices across Telangana.',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.secondaryText,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildActionSection() {
    return Column(
      children: [
        // Login Button (Primary - Green filled)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.login, size: 20),
            label: const Text(
              'Login',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Register Button (Secondary - Green outlined)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MobileEntryScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.talowaGreen,
              side: const BorderSide(color: AppTheme.talowaGreen, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: Colors.white,
            ),
            icon: const Icon(
              Icons.app_registration,
              size: 20,
              color: AppTheme.talowaGreen,
            ),
            label: const Text(
              'Join TALOWA Movement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.talowaGreen,
              ),
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Copyright Information
        Text(
          'Â© 2025 TALOWA. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryText.withOpacity(0.7),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}

