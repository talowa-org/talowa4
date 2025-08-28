import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/referral/referral_code_generator.dart';
import '../../services/referral/stats_refresh_service.dart';
import '../../services/referral/referral_sharing_service.dart';
import '../../services/referral/comprehensive_stats_service.dart';

/// Simplified referral dashboard widget
class SimplifiedReferralDashboard extends StatefulWidget {
  final String userId;
  final VoidCallback? onRefresh;

  const SimplifiedReferralDashboard({
    super.key,
    required this.userId,
    this.onRefresh,
  });

  @override
  State<SimplifiedReferralDashboard> createState() => _SimplifiedReferralDashboardState();
}

class _SimplifiedReferralDashboardState extends State<SimplifiedReferralDashboard> {
  Map<String, dynamic>? _referralStatus;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReferralStatus();
  }

  Future<void> _loadReferralStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get comprehensive stats (this will auto-update if needed)
      final statsResult = await ComprehensiveStatsService.getStatsSummary(widget.userId);
      
      if (statsResult.containsKey('error')) {
        throw Exception(statsResult['error']);
      }

      final currentStats = statsResult['current'] as Map<String, dynamic>;
      final roleProgression = statsResult['roleProgression'];

      // Ensure user has a referral code
      String referralCode = currentStats['referralCode'] as String? ?? '';
      if (referralCode.isEmpty || !ReferralCodeGenerator.hasValidTALPrefix(referralCode)) {
        // Generate a new referral code
        referralCode = await ReferralCodeGenerator.ensureReferralCode(widget.userId);
      }

      final status = {
        'userId': widget.userId,
        'referralCode': referralCode,
        'activeDirectReferrals': currentStats['directReferrals'] ?? 0,
        'activeTeamSize': currentStats['teamSize'] ?? 0,
        'currentRole': currentStats['currentRole'] ?? 'Member',
        'currentRoleLevel': 1, // Will be calculated from role
        'membershipPaid': true, // Assume paid for now
        'roleProgression': roleProgression,
      };
      
      setState(() {
        _referralStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<int> _getDirectReferrals(String referralCode) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('referredBy', isEqualTo: referralCode)
          .get();
      return query.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTeamSize(String userId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .get();
      return query.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Map<String, dynamic>? _calculateRoleProgression(int directReferrals, int teamSize, String currentRole) {
    // Updated to use Talowa's complete 9-level role system
    final roles = [
      'Member',
      'Active Member', 
      'Team Leader',
      'Area Coordinator',
      'Mandal Coordinator',
      'Constituency Coordinator',
      'District Coordinator',
      'Zonal Coordinator',
      'State Coordinator'
    ];
    
    final requirements = [
      {'directReferrals': 0, 'teamSize': 0},           // Member
      {'directReferrals': 10, 'teamSize': 10},         // Active Member
      {'directReferrals': 20, 'teamSize': 100},        // Team Leader
      {'directReferrals': 40, 'teamSize': 700},        // Area Coordinator
      {'directReferrals': 80, 'teamSize': 6000},       // Mandal Coordinator
      {'directReferrals': 160, 'teamSize': 50000},     // Constituency Coordinator
      {'directReferrals': 320, 'teamSize': 500000},    // District Coordinator
      {'directReferrals': 500, 'teamSize': 1000000},   // Zonal Coordinator
      {'directReferrals': 1000, 'teamSize': 3000000},  // State Coordinator
    ];

    // Find current role index (case insensitive)
    int currentIndex = -1;
    for (int i = 0; i < roles.length; i++) {
      if (roles[i].toLowerCase().replaceAll(' ', '_') == currentRole.toLowerCase() ||
          roles[i].toLowerCase() == currentRole.toLowerCase()) {
        currentIndex = i;
        break;
      }
    }
    
    // Default to Member if role not found
    if (currentIndex == -1) {
      currentIndex = 0;
    }

    // Check if already at highest role
    if (currentIndex >= roles.length - 1) {
      return null; // Already at highest role
    }

    // Find the highest eligible role based on current stats
    int eligibleIndex = currentIndex;
    for (int i = currentIndex + 1; i < roles.length; i++) {
      final req = requirements[i];
      if (directReferrals >= req['directReferrals']! && teamSize >= req['teamSize']!) {
        eligibleIndex = i;
      } else {
        break; // Stop at first unmet requirement
      }
    }

    // If eligible for promotion, show that role, otherwise show next role
    final targetIndex = eligibleIndex > currentIndex ? eligibleIndex : currentIndex + 1;
    final nextRole = roles[targetIndex];
    final nextRequirements = requirements[targetIndex];

    final directProgress = nextRequirements['directReferrals']! > 0 
        ? ((directReferrals / nextRequirements['directReferrals']!) * 100).clamp(0, 100)
        : 100.0;
    final teamProgress = nextRequirements['teamSize']! > 0
        ? ((teamSize / nextRequirements['teamSize']!) * 100).clamp(0, 100)
        : 100.0;
    
    // Overall progress is the minimum of both requirements (both must be met)
    final overallProgress = (directProgress * teamProgress / 100).clamp(0, 100).round();

    return {
      'nextRole': {
        'role': nextRole.toLowerCase().replaceAll(' ', '_'),
        'name': nextRole,
      },
      'progress': {
        'directReferrals': {
          'current': directReferrals,
          'required': nextRequirements['directReferrals'],
          'progress': directProgress.round(),
        },
        'teamSize': {
          'current': teamSize,
          'required': nextRequirements['teamSize'],
          'progress': teamProgress.round(),
        },
        'overallProgress': overallProgress,
      },
      'readyForPromotion': eligibleIndex > currentIndex,
    };
  }

  Future<void> _copyReferralCode() async {
    if (_referralStatus?['referralCode'] != null) {
      await ReferralSharingService.copyReferralCode(
        _referralStatus!['referralCode'],
        context,
      );
    }
  }

  Future<void> _shareReferralLink() async {
    if (_referralStatus?['referralCode'] != null) {
      await ReferralSharingService.shareReferralLink(
        _referralStatus!['referralCode'],
        userName: _getUserName(),
      );
    }
  }

  Future<void> _showSharingOptions() async {
    if (_referralStatus?['referralCode'] != null) {
      await ReferralSharingService.showSharingOptions(
        context,
        _referralStatus!['referralCode'],
        userName: _getUserName(),
      );
    }
  }

  Future<void> _showQRCode() async {
    if (_referralStatus?['referralCode'] != null) {
      await ReferralSharingService.showQRCodeDialog(
        context,
        _referralStatus!['referralCode'],
        userName: _getUserName(),
      );
    }
  }

  String? _getUserName() {
    // Try to get user name from Firebase Auth or user data
    // For now, return null - can be enhanced later
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading referral data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReferralStatus,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_referralStatus == null) {
      return const Center(
        child: Text('No referral data available'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReferralStatus,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildReferralCodeCard(),
            const SizedBox(height: 16),
            _buildStatsCards(),
            const SizedBox(height: 16),
            _buildRoleProgressCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.people,
                color: Colors.green[700],
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Simplified Referral System',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'One-step referrals with instant activation',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard() {
    final referralCode = _referralStatus!['referralCode'] ?? 'N/A';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Referral Code',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _copyReferralCode,
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy referral code',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showSharingOptions,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showQRCode,
                    icon: const Icon(Icons.qr_code),
                    label: const Text('QR Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _shareReferralLink,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Quick Share'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      if (_referralStatus?['referralCode'] != null) {
                        await ReferralSharingService.copyReferralLink(
                          _referralStatus!['referralCode'],
                          context,
                        );
                      }
                    },
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Copy Link'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final directReferrals = _referralStatus!['activeDirectReferrals'] ?? 0;
    final teamSize = _referralStatus!['activeTeamSize'] ?? 0;
    final currentRole = _referralStatus!['currentRole'] ?? 'member';

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Direct Referrals',
            value: directReferrals.toString(),
            icon: Icons.person_add,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Team Size',
            value: teamSize.toString(),
            icon: Icons.groups,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Role',
            value: _formatRole(currentRole),
            icon: Icons.star,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleProgressCard() {
    final roleProgression = _referralStatus!['roleProgression'];
    if (roleProgression == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Maximum Role Achieved!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have reached the highest role: State Coordinator',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final nextRole = roleProgression['nextRole'];
    final progress = roleProgression['progress'];
    final readyForPromotion = roleProgression['readyForPromotion'] ?? false;
    final directProgress = progress?['directReferrals']?['progress'] ?? 0;
    final teamProgress = progress?['teamSize']?['progress'] ?? 0;
    final overallProgress = progress?['overallProgress'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Next Role: ${nextRole['name']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (readyForPromotion)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'READY!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (readyForPromotion) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.celebration, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Congratulations! You qualify for promotion. The system will automatically update your role.',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildProgressItem(
              'Direct Referrals',
              progress?['directReferrals']?['current'] ?? 0,
              progress?['directReferrals']?['required'] ?? 0,
              directProgress,
            ),
            const SizedBox(height: 12),
            _buildProgressItem(
              'Team Size',
              progress?['teamSize']?['current'] ?? 0,
              progress?['teamSize']?['required'] ?? 0,
              teamProgress,
            ),
            const SizedBox(height: 16),
            Text(
              'Overall Progress: $overallProgress%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: overallProgress >= 100 ? Colors.green : null,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: overallProgress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                overallProgress >= 100 ? Colors.green : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String title, int current, int required, int progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text('$current / $required'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 100 ? Colors.green : Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              setState(() => _isLoading = true);
              
              // Force refresh stats using comprehensive service
              await ComprehensiveStatsService.updateUserStats(widget.userId);
              
              widget.onRefresh?.call();
              await _loadReferralStatus();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Statistics'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Show referral history
                },
                icon: const Icon(Icons.history),
                label: const Text('History'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Show leaderboard
                },
                icon: const Icon(Icons.leaderboard),
                label: const Text('Leaderboard'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatRole(String role) {
    return role
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}