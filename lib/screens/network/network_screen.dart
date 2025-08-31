// Network Screen for TALOWA
// Shows user's referral network and team management
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/referral_code_cache_service.dart';
import '../../services/referral/comprehensive_stats_service.dart';
import '../../services/referral/referral_sharing_service.dart';
import '../../widgets/referral/simplified_referral_dashboard.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _networkData;

  @override
  void initState() {
    super.initState();
    _initializeNetwork();
  }

  Future<void> _initializeNetwork() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = AuthService.currentUser;
      if (user != null) {
        // Initialize referral code cache
        await ReferralCodeCacheService.initialize(user.uid);
        
        // Load network data
        await _loadNetworkData();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing network: $e');
      }
      setState(() {
        _error = 'Failed to load network data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNetworkData() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;

      // Get comprehensive stats
      final statsResult = await ComprehensiveStatsService.getStatsSummary(user.uid);
      
      if (statsResult.containsKey('error')) {
        throw Exception(statsResult['error']);
      }

      final currentStats = statsResult['current'] as Map<String, dynamic>;
      
      setState(() {
        _networkData = {
          'userId': user.uid,
          'referralCode': currentStats['referralCode'] ?? '',
          'directReferrals': currentStats['directReferrals'] ?? 0,
          'teamSize': currentStats['teamSize'] ?? 0,
          'currentRole': currentStats['currentRole'] ?? 'Member',
          'lastUpdate': DateTime.now(),
        };
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading network data: $e');
      }
      setState(() {
        _error = 'Failed to load network data: $e';
        _isLoading = false;
      });
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
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please log in to view your network',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
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
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshNetwork,
              tooltip: 'Refresh Network',
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showInviteDialog,
              tooltip: 'Invite People',
            ),
          ],
        ),
        body: _buildBody(),
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your network...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Network Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshNetwork,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final user = AuthService.currentUser!;
    
    // Use only the SimplifiedReferralDashboard to avoid duplication
    return RefreshIndicator(
      onRefresh: _refreshNetwork,
      child: SimplifiedReferralDashboard(
        userId: user.uid,
        onRefresh: _refreshNetwork,
      ),
    );
  }

  int _calculateMonthlyGrowth() {
    // TODO: Implement actual monthly growth calculation
    // For now, return a placeholder value
    return 0;
  }

  Future<void> _refreshNetwork() async {
    final user = AuthService.currentUser;
    if (user != null) {
      await ReferralCodeCacheService.refresh(user.uid);
      await _loadNetworkData();
    }
  }





  // Action methods
  void _showInviteDialog() {
    final referralCode = _networkData?['referralCode'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_add, color: AppTheme.talowaGreen),
            const SizedBox(width: 8),
            const Text('Invite People'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share your referral code to invite people to your network:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (referralCode.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        referralCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await ReferralSharingService.copyReferralCode(
                          referralCode,
                          context,
                        );
                      },
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy code',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await ReferralSharingService.shareReferralLink(referralCode);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share Link'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.talowaGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await ReferralSharingService.showQRCodeDialog(
                          context,
                          referralCode,
                        );
                      },
                      icon: const Icon(Icons.qr_code),
                      label: const Text('QR Code'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.talowaGreen,
                        side: BorderSide(color: AppTheme.talowaGreen),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Loading referral code...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
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

  void _shareReferralCode() async {
    final referralCode = _networkData?['referralCode'] ?? '';
    
    if (referralCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral code not available. Please try refreshing.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await ReferralSharingService.showSharingOptions(
      context,
      referralCode,
    );
  }

  /// Handle smart back navigation for network screen
  void _handleNetworkBackNavigation() {
    // Check if there's a screen in the navigation stack
    if (Navigator.of(context).canPop()) {
      // There's a screen to go back to (like referral details, sharing screen, etc.)
      Navigator.of(context).pop();
      if (kDebugMode) {
        debugPrint('🔙 Network: Navigated back in stack');
      }
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
      if (kDebugMode) {
        debugPrint('🔙 Network: At main network screen, suggesting home navigation');
      }
    }
  }
}