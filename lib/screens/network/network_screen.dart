// Network Screen for TALOWA
// Shows user's referral network and team management
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/referral_code_cache_service.dart';
import '../../widgets/referral/simplified_referral_dashboard.dart';
import '../../widgets/referral/realtime_stats_widget.dart';
import '../../widgets/network/network_stats_card.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  @override
  void initState() {
    super.initState();
    _initializeReferralCodeCache();
  }

  void _initializeReferralCodeCache() {
    final user = AuthService.currentUser;
    if (user != null) {
      ReferralCodeCacheService.initialize(user.uid);
    }
  }



  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Network'),
          backgroundColor: AppTheme.talowaGreen,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false, // Remove back button for logged out users
        ),
        body: const Center(
          child: Text('Please log in to view your network'),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Smart back navigation for network tab
          _handleNetworkBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Network',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppTheme.talowaGreen,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false, // Remove back button since this is a tab
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showInviteDialog,
              tooltip: 'Invite People',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareReferralCode,
              tooltip: 'Share Referral Code',
            ),
          ],
        ),
        body: Column(
          children: [
            // Real-time stats header
            RealtimeStatsWidget(
              userId: user.uid,
              builder: (stats) => NetworkStatsCard(
                totalTeamSize: stats['teamSize'] ?? 0,
                directReferrals: stats['directReferrals'] ?? 0,
                monthlyGrowth: 0, // TODO: Calculate monthly growth
                currentRole: stats['currentRole'] ?? 'Member',
              ),
            ),
            // Referral dashboard
            Expanded(
              child: SimplifiedReferralDashboard(
                userId: user.uid,
                onRefresh: () {
                  // Refresh the referral code cache
                  ReferralCodeCacheService.refresh(user.uid);
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showInviteDialog,
          backgroundColor: AppTheme.talowaGreen,
          foregroundColor: Colors.white,
          tooltip: 'Invite People',
          heroTag: "network_invite",
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }





  // Action methods
  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite People'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Use the referral dashboard below to share your referral code and invite people to your network.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _shareReferralCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Use the referral dashboard below to share your code'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// Handle smart back navigation for network screen
  void _handleNetworkBackNavigation() {
    // Check if there's a screen in the navigation stack
    if (Navigator.of(context).canPop()) {
      // There's a screen to go back to (like referral details, sharing screen, etc.)
      Navigator.of(context).pop();
      debugPrint('🔙 Network: Navigated back in stack');
    } else {
      // No stack, we're at the main network tab - go to home
      // This will be handled by the main navigation screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🏠 Press back again to go to Home'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue,
        ),
      );
      debugPrint('🔙 Network: At main network screen, suggesting home navigation');
    }
  }
}