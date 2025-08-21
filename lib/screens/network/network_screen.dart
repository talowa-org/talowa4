// Network Screen for TALOWA
// Shows user's referral network and team management
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/referral_code_cache_service.dart';
import '../../widgets/referral/simplified_referral_dashboard.dart';

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
        ),
        body: const Center(
          child: Text('Please log in to view your network'),
        ),
      );
    }

    return Scaffold(
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back within app, don't logout
            Navigator.of(context).maybePop();
          },
        ),
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
      body: SimplifiedReferralDashboard(
        userId: user.uid,
        onRefresh: () {
          // Refresh the referral code cache
          ReferralCodeCacheService.refresh(user.uid);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showInviteDialog,
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        tooltip: 'Invite People',
        heroTag: "network_invite",
        child: const Icon(Icons.person_add),
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
}