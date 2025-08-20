import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/referral/referral_code_generator.dart';

/// Simplified referral dashboard widget
class SimplifiedReferralDashboard extends StatefulWidget {
  final String userId;
  final VoidCallback? onRefresh;

  const SimplifiedReferralDashboard({
    Key? key,
    required this.userId,
    this.onRefresh,
  }) : super(key: key);

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

      // Get user data directly from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      
      // Ensure user has a referral code
      String referralCode = userData['referralCode'] as String? ?? '';
      if (referralCode.isEmpty || !referralCode.startsWith('TAL')) {
        // Generate a new referral code
        referralCode = await ReferralCodeGenerator.ensureReferralCode(widget.userId);
      }

      // Get referral statistics
      final directReferrals = await _getDirectReferrals(referralCode);
      final teamSize = await _getTeamSize(widget.userId);

      final status = {
        'userId': widget.userId,
        'referralCode': referralCode,
        'activeDirectReferrals': directReferrals,
        'activeTeamSize': teamSize,
        'currentRole': userData['currentRole'] ?? 'member',
        'membershipPaid': true, // Always true in simplified system
        'roleProgression': _calculateRoleProgression(directReferrals, teamSize, userData['currentRole'] ?? 'member'),
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
    // Simple role progression logic
    final roles = ['member', 'activist', 'organizer', 'team_leader', 'coordinator'];
    final requirements = [
      {'directReferrals': 0, 'teamSize': 0},
      {'directReferrals': 2, 'teamSize': 5},
      {'directReferrals': 5, 'teamSize': 15},
      {'directReferrals': 10, 'teamSize': 50},
      {'directReferrals': 20, 'teamSize': 150},
    ];

    final currentIndex = roles.indexOf(currentRole);
    if (currentIndex == -1 || currentIndex >= roles.length - 1) {
      return null; // Already at highest role or invalid role
    }

    final nextRoleIndex = currentIndex + 1;
    final nextRole = roles[nextRoleIndex];
    final nextRequirements = requirements[nextRoleIndex];

    final directProgress = ((directReferrals / nextRequirements['directReferrals']!) * 100).clamp(0, 100);
    final teamProgress = ((teamSize / nextRequirements['teamSize']!) * 100).clamp(0, 100);
    final overallProgress = ((directProgress + teamProgress) / 2).round();

    return {
      'nextRole': {
        'role': nextRole,
        'name': _formatRole(nextRole),
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
    };
  }

  Future<void> _copyReferralCode() async {
    if (_referralStatus?['referralCode'] != null) {
      await Clipboard.setData(ClipboardData(text: _referralStatus!['referralCode']));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral code copied to clipboard!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _shareReferralLink() async {
    if (_referralStatus?['referralCode'] != null) {
      final referralCode = _referralStatus!['referralCode'];
      final referralLink = 'https://talowa.web.app/join?ref=$referralCode';
      
      await Clipboard.setData(ClipboardData(text: referralLink));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral link copied to clipboard!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
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
                    onPressed: _shareReferralLink,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Show QR code
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('QR Code'),
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
    if (roleProgression == null) return const SizedBox.shrink();

    final nextRole = roleProgression['nextRole'];
    if (nextRole == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
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
                'You have reached the highest role in the system.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final progress = roleProgression['progress'];
    final directProgress = progress?['directReferrals']?['progress'] ?? 0;
    final teamProgress = progress?['teamSize']?['progress'] ?? 0;
    final overallProgress = progress?['overallProgress'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next Role: ${_formatRole(nextRole['role'])}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
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
            onPressed: () {
              widget.onRefresh?.call();
              _loadReferralStatus();
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