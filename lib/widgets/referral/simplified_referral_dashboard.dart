import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/referral/referral_code_generator.dart';
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

      // Force update stats first to ensure accuracy
      await ComprehensiveStatsService.updateUserStats(widget.userId);

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
        'membershipPaid': currentStats['membershipPaid'] ?? false, // Use actual payment status
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.network_check, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No referral data available'),
          ],
        ),
      );
    }

    // Wrap with StreamBuilder for real-time updates
    return StreamBuilder<Map<String, dynamic>>(
      stream: ComprehensiveStatsService.streamUserStats(widget.userId),
      builder: (context, snapshot) {
        // Update local data if stream has new data
        if (snapshot.hasData && _referralStatus != null) {
          final streamData = snapshot.data!;
          _referralStatus!['activeDirectReferrals'] = streamData['directReferrals'] ?? 0;
          _referralStatus!['activeTeamSize'] = streamData['teamSize'] ?? 0;
          _referralStatus!['currentRole'] = streamData['currentRole'] ?? 'Member';
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
                const SizedBox(height: 16),
                _buildRecentReferralNotifications(),
                const SizedBox(height: 16),
                _buildReferralCodeCard(),
                const SizedBox(height: 16),
                _buildStatsCards(),
                const SizedBox(height: 16),
                _buildRoleProgressCard(),
                const SizedBox(height: 16),
                _buildTestingButtonsCard(),
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        );
      },
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final directReferrals = _referralStatus!['activeDirectReferrals'] ?? 0;
    final totalTeamSize = _referralStatus!['activeTeamSize'] ?? 0;
    final currentRole = _referralStatus!['currentRole'] ?? 'member';

    return Column(
      children: [
        // First row - Direct vs Team Size
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Direct Referrals',
                value: directReferrals.toString(),
                subtitle: 'People you invited',
                icon: Icons.person_add,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Team Size',
                value: totalTeamSize.toString(),
                subtitle: 'All levels including direct',
                icon: Icons.groups,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row - Role and Network Depth
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Current Role',
                value: _formatRole(currentRole),
                subtitle: 'Your rank',
                icon: Icons.star,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Network Depth',
                value: _calculateNetworkDepth(directReferrals, totalTeamSize),
                subtitle: 'Levels deep',
                icon: Icons.account_tree,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _calculateNetworkDepth(int directReferrals, int totalTeamSize) {
    if (directReferrals == 0) return '0';
    if (totalTeamSize <= directReferrals) return '1';
    
    // Estimate network depth based on team size vs direct referrals
    // This is an approximation since we don't have exact level data
    final indirectReferrals = totalTeamSize - directReferrals;
    if (indirectReferrals <= directReferrals * 2) return '2';
    if (indirectReferrals <= directReferrals * 5) return '3';
    if (indirectReferrals <= directReferrals * 10) return '4';
    return '5+';
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
    final requirements = roleProgression['requirements'];
    final readyForPromotion = roleProgression['readyForPromotion'] ?? false;
    final directProgress = requirements?['directReferrals']?['progress'] ?? 0;
    final teamProgress = requirements?['teamSize']?['progress'] ?? 0;
    final overallProgress = roleProgression['overallProgress'] ?? 0;

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
                        'Congratulations! You qualify for promotion and will be notified when new members join with your referral code.',
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
              requirements?['directReferrals']?['current'] ?? 0,
              requirements?['directReferrals']?['required'] ?? 0,
              directProgress,
            ),
            const SizedBox(height: 12),
            _buildProgressItem(
              'Team Size',
              requirements?['teamSize']?['current'] ?? 0,
              requirements?['teamSize']?['required'] ?? 0,
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Show referral history
                  _showReferralHistory();
                },
                icon: const Icon(Icons.history),
                label: const Text('History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentReferralNotifications() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ComprehensiveStatsService.streamRecentReferrals(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recentReferrals = snapshot.data!;
        
        return Card(
          color: Colors.green.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.celebration, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Referrals',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...recentReferrals.take(3).map((referral) {
                  final joinedAt = (referral['joinedAt'] as Timestamp?)?.toDate();
                  final timeAgo = joinedAt != null 
                      ? _formatTimeAgo(DateTime.now().difference(joinedAt))
                      : 'Recently';
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${referral['fullName']} joined your network',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (recentReferrals.length > 3) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${recentReferrals.length - 3} more joined recently',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimeAgo(Duration difference) {
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showReferralHistory() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    'Referral History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: ComprehensiveStatsService.getReferralHistory(widget.userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading referral history...'),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: ${snapshot.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showReferralHistory(); // Retry
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final history = snapshot.data ?? [];

                    if (history.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No Referrals Yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start sharing your referral code to build your network!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Statistics Summary
                        FutureBuilder<Map<String, dynamic>>(
                          future: ComprehensiveStatsService.getReferralStatistics(widget.userId),
                          builder: (context, statsSnapshot) {
                            if (statsSnapshot.hasData) {
                              final stats = statsSnapshot.data!;
                              return Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem('Total', stats['totalReferrals'].toString()),
                                    _buildStatItem('Active', stats['activeReferrals'].toString()),
                                    _buildStatItem('Paid', stats['paidMembers'].toString()),
                                    _buildStatItem('Recent', stats['recentReferrals'].toString()),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        // Referral List
                        Expanded(
                          child: ListView.builder(
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final referral = history[index];
                              final joinedAt = referral['joinedAt'] as DateTime?;
                              final location = referral['location'] as Map<String, dynamic>;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: referral['isActive'] ? Colors.green : Colors.grey,
                                    child: Text(
                                      (referral['fullName'] as String).isNotEmpty 
                                          ? (referral['fullName'] as String)[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(
                                    referral['fullName'] ?? 'Unknown User',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Role: ${referral['currentRole']}'),
                                      if (location['district']?.isNotEmpty == true)
                                        Text('Location: ${location['district']}, ${location['state']}'),
                                      if (joinedAt != null)
                                        Text('Joined: ${_formatDate(joinedAt)}'),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (referral['membershipPaid'] == true)
                                        const Icon(Icons.favorite, color: Colors.orange, size: 16), // Supporter badge
                                      if (referral['isActive'] == true)
                                        const Icon(Icons.circle, color: Colors.green, size: 8)
                                      else
                                        const Icon(Icons.circle, color: Colors.grey, size: 8),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatRole(String role) {
    return role
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildTestingButtonsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Testing Tools',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateMockReferrals,
                    icon: const Icon(Icons.group_add),
                    label: const Text('Generate 10 Referrals'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateTeamSize,
                    icon: const Icon(Icons.groups),
                    label: const Text('Generate Team of 100'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'These buttons generate mock data for testing role promotion functionality.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateMockReferrals() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();
      
      // Generate 10 mock referrals
      for (int i = 1; i <= 10; i++) {
        final mockUserId = 'mock_user_${DateTime.now().millisecondsSinceEpoch}_$i';
        final referralDoc = FirebaseFirestore.instance
            .collection('referrals')
            .doc();
        
        batch.set(referralDoc, {
          'referrerId': widget.userId,
          'referredUserId': mockUserId,
          'referralCode': _referralStatus?['referralCode'] ?? 'TEST_CODE',
          'timestamp': now.subtract(Duration(days: i)),
          'status': 'completed',
          'mockData': true,
        });
        
        // Create mock user profile
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(mockUserId);
        
        batch.set(userDoc, {
          'name': 'Test User $i',
          'email': 'testuser$i@example.com',
          'phoneNumber': '+91${9000000000 + i}',
          'createdAt': now.subtract(Duration(days: i)),
          'referredBy': _referralStatus?['referralCode'] ?? 'TEST_CODE',
          'mockData': true,
        });
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Generated 10 mock referrals successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Refresh the data
        await _loadReferralStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating referrals: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _generateTeamSize() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();
      
      // Generate 100 mock team members (indirect referrals)
      for (int i = 1; i <= 100; i++) {
        final mockUserId = 'mock_team_${DateTime.now().millisecondsSinceEpoch}_$i';
        final referrerId = i <= 10 ? widget.userId : 'mock_user_${DateTime.now().millisecondsSinceEpoch}_${(i % 10) + 1}';
        
        final referralDoc = FirebaseFirestore.instance
            .collection('referrals')
            .doc();
        
        batch.set(referralDoc, {
          'referrerId': referrerId,
          'referredUserId': mockUserId,
          'referralCode': _referralStatus?['referralCode'] ?? 'TEST_CODE',
          'timestamp': now.subtract(Duration(hours: i)),
          'status': 'completed',
          'teamMember': true,
          'rootReferrer': widget.userId,
          'mockData': true,
        });
        
        // Create mock team member profile
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(mockUserId);
        
        batch.set(userDoc, {
          'name': 'Team Member $i',
          'email': 'teammember$i@example.com',
          'phoneNumber': '+91${8000000000 + i}',
          'createdAt': now.subtract(Duration(hours: i)),
          'referredBy': _referralStatus?['referralCode'] ?? 'TEST_CODE',
          'rootReferrer': widget.userId,
          'mockData': true,
        });
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Generated team of 100 members successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Refresh the data
        await _loadReferralStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating team: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}


