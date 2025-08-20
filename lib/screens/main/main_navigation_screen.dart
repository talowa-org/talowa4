// TALOWA Main Navigation Screen - 5 Tab System
// Reference: complete-app-structure.md - Bottom Navigation (5 Main Tabs)

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../services/onboarding_service.dart';
import '../home/home_screen.dart';
import '../feed/feed_screen.dart';
import '../messages/messages_screen.dart';
import '../network/network_screen.dart';
import '../more/more_screen.dart';
import '../onboarding/onboarding_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    await OnboardingService.initialize();
    
    // Check if user needs onboarding
    if (!OnboardingService.isOnboardingCompleted()) {
      // Show messaging tutorial for new users
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInitialOnboarding();
      });
    }
  }

  void _showInitialOnboarding() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to TALOWA!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Let\'s get you started with a quick tutorial on how to use TALOWA\'s secure messaging features.',
            ),
            SizedBox(height: 16),
            Text(
              'This will only take a few minutes and will help you communicate effectively with other activists.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              OnboardingService.markOnboardingCompleted();
            },
            child: const Text('Skip for now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OnboardingScreen(
                    tutorialType: 'messaging',
                    onCompleted: () {
                      Navigator.pop(context);
                      OnboardingService.markOnboardingCompleted();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Welcome to TALOWA! You\'re ready to start communicating securely.'),
                          backgroundColor: AppTheme.talowaGreen,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Tutorial'),
          ),
        ],
      ),
    );
  }
  
  // 5 Main Tabs - Mobile Optimized
  final List<Widget> _screens = [
    const HomeScreen(),
    const FeedScreen(), // Full-featured feed screen with all advanced features
    const MessagesScreen(),
    const NetworkScreen(),
    const MoreScreen(),
  ];
  
  List<BottomNavigationBarItem> _getNavItems(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home),
        label: localizations.home,
        tooltip: 'Home Dashboard',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.dynamic_feed),
        label: localizations.feed,
        tooltip: 'Social Feed & Stories',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.chat_bubble),
        label: localizations.messages,
        tooltip: 'Messages & Communication',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.people),
        label: localizations.network,
        tooltip: 'Network & Referrals',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.more_horiz),
        label: localizations.more,
        tooltip: 'More Features & Settings',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: AppTheme.elevationMedium,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: _getNavItems(context),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.cardBackground,
          selectedItemColor: AppTheme.talowaGreen,
          unselectedItemColor: AppTheme.secondaryText,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          iconSize: 24,
          elevation: AppTheme.elevationMedium,
          // Ensure proper touch targets (44px minimum)
          selectedLabelStyle: const TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 12,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Add haptic feedback for better UX
    _provideFeedback();
    
    // Track navigation analytics
    _trackNavigation(index);
  }
  
  void _provideFeedback() {
    // Add haptic feedback for tab selection
    // This helps users confirm their selection
    try {
      // Note: Import 'package:flutter/services.dart' for HapticFeedback
      // HapticFeedback.lightImpact();
    } catch (e) {
      // Haptic feedback not available on all devices
      debugPrint('Haptic feedback not available: $e');
    }
  }
  
  void _trackNavigation(int index) {
    // Track navigation analytics for user behavior analysis
    final tabNames = ['Home', 'Feed', 'Messages', 'Network', 'More'];
    debugPrint('Navigation: User switched to ${tabNames[index]} tab');
    
    // TODO: Implement analytics tracking
    // AnalyticsService.trackEvent('tab_navigation', {
    //   'tab_name': tabNames[index],
    //   'tab_index': index,
    //   'timestamp': DateTime.now().toIso8601String(),
    // });
  }
}

// Navigation Helper Class
class NavigationHelper {
  static void navigateToTab(BuildContext context, int tabIndex) {
    // Helper method to navigate to specific tab from anywhere in the app
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainNavigationScreen(),
      ),
      (route) => false,
    );
  }
  
  static void navigateToHome(BuildContext context) => navigateToTab(context, 0);
  static void navigateToFeed(BuildContext context) => navigateToTab(context, 1);
  static void navigateToMessages(BuildContext context) => navigateToTab(context, 2);
  static void navigateToNetwork(BuildContext context) => navigateToTab(context, 3);
  static void navigateToMore(BuildContext context) => navigateToTab(context, 4);
}