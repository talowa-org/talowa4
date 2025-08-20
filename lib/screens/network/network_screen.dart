// Network Screen for TALOWA
// Shows user's referral network and team management
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/referral_code_cache_service.dart';
import 'dart:async';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _directReferralsSubscription;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> _directReferrals = [];
  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeReferralCodeCache();
    _setupRealtimeStreams();
  }

  void _initializeReferralCodeCache() {
    final user = AuthService.currentUser;
    if (user != null) {
      ReferralCodeCacheService.initialize(user.uid);
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _directReferralsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _setupRealtimeStreams() {
    final user = AuthService.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Stream user data for real-time updates
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists) {
        setState(() {
          userData = userDoc.data();
          _isLoading = false;
        });

        // Set up direct referrals stream now that we have user data
        _setupDirectReferralsStream();
      }
    }, onError: (error) {
      debugPrint('Error streaming user data: $error');
      setState(() {
        _isLoading = false;
      });
    });

  }

  void _setupDirectReferralsStream() {
    final userReferralCode = userData?['referralCode'];
    if (userReferralCode == null) return;

    // Stream direct referrals for real-time updates
    _directReferralsSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('referredBy', isEqualTo: userReferralCode)
        .snapshots()
        .listen((querySnapshot) {
      final referrals = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        referrals.add({
          'id': doc.id,
          'name': data['fullName'] ?? 'Unknown',
          'joinDate': _formatDate(data['createdAt']),
          'status': data['status'] ?? 'pending',
          'referrals': data['directReferralCount'] ?? 0,
          'isActive': data['status'] == 'active',
          'membershipPaid': data['membershipPaid'] ?? false,
        });
      }

      setState(() {
        _directReferrals = referrals;
      });

      // Load team members (indirect referrals)
      _loadTeamMembers();
    }, onError: (error) {
      debugPrint('Error streaming direct referrals: $error');
    });
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Unknown';
      }

      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<void> _loadTeamMembers() async {
    try {
      final teamMembers = <Map<String, dynamic>>[];

      // Get all users in the referral chain
      for (final referral in _directReferrals) {
        final referralId = referral['id'];

        // Get indirect referrals (level 2)
        final indirectQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('referredBy', isEqualTo: referralId)
            .get();

        for (final doc in indirectQuery.docs) {
          final data = doc.data();
          teamMembers.add({
            'id': doc.id,
            'name': data['fullName'] ?? 'Unknown',
            'level': 'Level 2',
            'referrer': referral['name'],
            'isActive': data['status'] == 'active',
            'joinDate': _formatDate(data['createdAt']),
          });
        }
      }

      setState(() {
        _teamMembers = teamMembers;
      });
    } catch (e) {
      debugPrint('Error loading team members: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Direct'),
            Tab(text: 'Team'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildDirectReferralsTab(),
                _buildTeamTab(),
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
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Network Stats Cards
          _buildNetworkStats(),
          
          const SizedBox(height: 24),
          
          // Referral Code Card
          _buildReferralCodeCard(),
          
          const SizedBox(height: 24),
          
          // Performance Chart
          _buildPerformanceChart(),
          
          const SizedBox(height: 24),
          
          // Recent Activity
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildDirectReferralsTab() {
    return Column(
      children: [
        // Header with count
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Icon(Icons.people, color: AppTheme.talowaGreen),
              const SizedBox(width: 8),
              Text(
                'Direct Referrals (${_directReferrals.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Referrals list
        Expanded(
          child: _directReferrals.isEmpty
              ? _buildEmptyState('No direct referrals yet', 'Invite people to join your network')
              : ListView.builder(
                  itemCount: _directReferrals.length,
                  itemBuilder: (context, index) {
                    final referral = _directReferrals[index];
                    return _buildReferralTile(referral);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTeamTab() {
    return Column(
      children: [
        // Header with count
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Icon(Icons.groups, color: AppTheme.talowaGreen),
              const SizedBox(width: 8),
              Text(
                'Team Members (${_teamMembers.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Team list
        Expanded(
          child: _teamMembers.isEmpty
              ? _buildEmptyState('No team members yet', 'Your referrals will appear here as they join')
              : ListView.builder(
                  itemCount: _teamMembers.length,
                  itemBuilder: (context, index) {
                    final member = _teamMembers[index];
                    return _buildTeamMemberTile(member);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNetworkStats() {
    final directReferralCount = userData?['directReferralCount'] ?? 0;
    final totalTeamSize = userData?['totalTeamSize'] ?? 0;
    final activeMembers = _directReferrals.where((r) => r['isActive'] == true).length +
                         _teamMembers.where((m) => m['isActive'] == true).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Direct Referrals',
            '$directReferralCount',
            Icons.person_add,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Team Size',
            '$totalTeamSize',
            Icons.groups,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Active Members',
            '$activeMembers',
            Icons.trending_up,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeCard() {
    return StreamBuilder<String?>(
      stream: ReferralCodeCacheService.codeStream,
      initialData: ReferralCodeCacheService.currentCode,
      builder: (context, snapshot) {
        final referralCode = snapshot.data ?? ReferralCodeCacheService.currentCode;

        return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.talowaGreen, AppTheme.talowaGreen.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Referral Code',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    referralCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyReferralCode(referralCode),
                  icon: const Icon(Icons.copy, color: Colors.white),
                  tooltip: 'Copy Code',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          const Text(
            'Share this code with others to invite them to your network',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildPerformanceChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Network Growth',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Simple bar chart representation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildChartBar('Jan', 5, 40),
              _buildChartBar('Feb', 8, 60),
              _buildChartBar('Mar', 12, 80),
              _buildChartBar('Apr', 15, 100),
              _buildChartBar('May', 18, 120),
            ],
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'Steady growth in your network over the past 5 months',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(String month, int value, double height) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.talowaGreen,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          month,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final activities = [
      {'type': 'join', 'name': 'Priya Sharma', 'time': '2 hours ago'},
      {'type': 'referral', 'name': 'Rajesh Kumar', 'time': '1 day ago'},
      {'type': 'join', 'name': 'Sunita Devi', 'time': '3 days ago'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          ...activities.map((activity) => _buildActivityTile(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity) {
    IconData icon;
    Color color;
    String message;

    switch (activity['type']) {
      case 'join':
        icon = Icons.person_add;
        color = Colors.green;
        message = '${activity['name']} joined your network';
        break;
      case 'referral':
        icon = Icons.share;
        color = Colors.blue;
        message = '${activity['name']} made a referral';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        message = 'Unknown activity';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  activity['time'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralTile(Map<String, dynamic> referral) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.talowaGreen,
        child: Text(
          referral['name'][0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        referral['name'],
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Joined: ${referral['joinDate']}'),
          Text('Status: ${referral['status']}'),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${referral['referrals']}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.talowaGreen,
            ),
          ),
          const Text(
            'referrals',
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
      onTap: () => _showMemberDetails(referral),
    );
  }

  Widget _buildTeamMemberTile(Map<String, dynamic> member) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: member['isActive'] ? AppTheme.talowaGreen : Colors.grey,
        child: Text(
          member['name'][0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        member['name'],
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Level: ${member['level']}'),
          Text('Referrer: ${member['referrer']}'),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: member['isActive'] ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          member['isActive'] ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: 12,
            color: member['isActive'] ? Colors.green : Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: () => _showMemberDetails(member),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showInviteDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Invite People'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share your referral code to invite people to your network:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ReferralCodeCacheService.currentCode,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _shareReferralCode();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.talowaGreen),
            child: const Text('Share', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _shareReferralCode() {
    final referralCode = ReferralCodeCacheService.currentCode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Referral Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.talowaGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                referralCode,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Share via:'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareButton(Icons.message, 'SMS', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening SMS app...')),
                  );
                }),
                _buildShareButton(Icons.share, 'WhatsApp', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening WhatsApp...')),
                  );
                }),
                _buildShareButton(Icons.copy, 'Copy', () {
                  Navigator.pop(context);
                  _copyReferralCode(referralCode);
                }),
              ],
            ),
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

  Widget _buildShareButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.talowaGreen.withOpacity(0.1),
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _copyReferralCode(String code) {
    // Simulate clipboard copy
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Referral code $code copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Share',
          textColor: Colors.white,
          onPressed: () => _shareReferralCode(),
        ),
      ),
    );
  }

  void _showMemberDetails(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${member['status'] ?? (member['isActive'] ? 'Active' : 'Inactive')}'),
            if (member['joinDate'] != null) Text('Joined: ${member['joinDate']}'),
            if (member['level'] != null) Text('Level: ${member['level']}'),
            if (member['referrer'] != null) Text('Referrer: ${member['referrer']}'),
            if (member['referrals'] != null) Text('Referrals: ${member['referrals']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to member profile or chat
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.talowaGreen),
            child: const Text('Contact', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}