import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/referral/referral_statistics_service.dart';
import '../../services/referral/role_progression_service.dart';
import '../../services/referral/universal_link_service.dart';
import 'enhanced_qr_widget.dart';

/// Main referral dashboard widget
class ReferralDashboardWidget extends StatefulWidget {
  final String userId;
  final VoidCallback? onRefresh;
  
  const ReferralDashboardWidget({
    Key? key,
    required this.userId,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<ReferralDashboardWidget> createState() => _ReferralDashboardWidgetState();
}

class _ReferralDashboardWidgetState extends State<ReferralDashboardWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _userStats;
  Map<String, dynamic>? _roleStatus;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        ReferralStatisticsService.getStatisticsSummary(widget.userId),
        RoleProgressionService.getRoleProgressionStatus(widget.userId),
      ]);

      setState(() {
        _userStats = futures[0];
        _roleStatus = futures[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your referral dashboard...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error loading dashboard'),
            SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Header with referral code
            _buildReferralCodeHeader(),
            
            // Quick stats cards
            _buildQuickStatsCards(),
            
            // Role progression
            _buildRoleProgressionCard(),
            
            // Tab view for detailed sections
            _buildTabSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeHeader() {
    final userStats = _userStats?['user'] ?? {};
    final referralCode = userStats['referralCode'] ?? 'LOADING...';
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Your Referral Code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  referralCode,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Theme.of(context).primaryColor,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(width: 16),
                IconButton(
                  onPressed: () => _copyReferralCode(referralCode),
                  icon: Icon(Icons.copy, color: Theme.of(context).primaryColor),
                  tooltip: 'Copy referral code',
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.share,
                label: 'Share',
                onPressed: () => _shareReferralCode(referralCode),
              ),
              _buildActionButton(
                icon: Icons.qr_code,
                label: 'QR Code',
                onPressed: () => _showQRCode(referralCode),
              ),
              _buildActionButton(
                icon: Icons.link,
                label: 'Copy Link',
                onPressed: () => _copyReferralLink(referralCode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
            iconSize: 24,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsCards() {
    final userStats = _userStats?['user'] ?? {};
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Direct Referrals',
              value: '${userStats['directReferrals'] ?? 0}',
              subtitle: '${userStats['activeDirectReferrals'] ?? 0} active',
              icon: Icons.people,
              color: Colors.blue,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Team Size',
              value: '${userStats['teamSize'] ?? 0}',
              subtitle: '${userStats['activeTeamSize'] ?? 0} active',
              icon: Icons.groups,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleProgressionCard() {
    final roleStatus = _roleStatus ?? {};
    final currentRole = roleStatus['currentRole'] ?? 'member';
    final nextRole = roleStatus['nextRole'];
    final progress = roleStatus['progress'];
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Role Progression',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Current role
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Current Role: ${_formatRoleName(currentRole)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            
            if (nextRole != null) ...[
              SizedBox(height: 16),
              Text(
                'Next Role: ${_formatRoleName(nextRole['role'])}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              
              if (progress != null) ...[
                // Direct referrals progress
                _buildProgressBar(
                  label: 'Direct Referrals',
                  current: progress['directReferrals']['current'],
                  required: progress['directReferrals']['required'],
                  progress: progress['directReferrals']['progress'],
                ),
                SizedBox(height: 8),
                
                // Team size progress
                _buildProgressBar(
                  label: 'Team Size',
                  current: progress['teamSize']['current'],
                  required: progress['teamSize']['required'],
                  progress: progress['teamSize']['progress'],
                ),
              ],
            ] else ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Congratulations! You\'ve reached the highest role.',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.amber[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required int current,
    required int required,
    required int progress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$current / $required',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 100 ? Colors.green : Theme.of(context).primaryColor,
          ),
        ),
        SizedBox(height: 2),
        Text(
          '$progress% complete',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildTabSection() {
    return Container(
      height: 400,
      margin: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Team'),
                Tab(text: 'Growth'),
                Tab(text: 'QR Code'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildTeamTab(),
                  _buildGrowthTab(),
                  _buildQRCodeTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final pendingVsActive = _userStats?['pendingVsActive'] ?? {};
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referral Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          // Activation rates
          if (pendingVsActive.isNotEmpty) ...[
            _buildActivationRateCard(
              'Direct Referrals',
              pendingVsActive['directReferrals'] ?? {},
            ),
            SizedBox(height: 12),
            _buildActivationRateCard(
              'Team Members',
              pendingVsActive['teamSize'] ?? {},
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivationRateCard(String title, Map<String, dynamic> data) {
    final total = data['total'] ?? 0;
    final active = data['active'] ?? 0;
    final pending = data['pending'] ?? 0;
    final rate = data['activationRate'] ?? 0;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: $total'),
                    Text('Active: $active'),
                    Text('Pending: $pending'),
                  ],
                ),
              ),
              CircularProgressIndicator(
                value: total > 0 ? active / total : 0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  rate >= 70 ? Colors.green : 
                  rate >= 40 ? Colors.orange : Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Activation Rate: $rate%',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: rate >= 70 ? Colors.green : 
                     rate >= 40 ? Colors.orange : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab() {
    return Center(
      child: Text('Team details coming soon...'),
    );
  }

  Widget _buildGrowthTab() {
    final weeklyGrowth = _userStats?['weeklyGrowth'] ?? {};
    final growth = weeklyGrowth['growth'] ?? {};
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Growth',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          _buildGrowthMetric('Direct Referrals', growth['directReferrals'] ?? 0),
          SizedBox(height: 8),
          _buildGrowthMetric('Team Size', growth['teamSize'] ?? 0),
          SizedBox(height: 8),
          _buildGrowthMetric('Active Team', growth['activeTeamSize'] ?? 0),
        ],
      ),
    );
  }

  Widget _buildGrowthMetric(String label, int growth) {
    final isPositive = growth > 0;
    final isNegative = growth < 0;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.withOpacity(0.1) :
               isNegative ? Colors.red.withOpacity(0.1) :
               Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up :
            isNegative ? Icons.trending_down :
            Icons.trending_flat,
            color: isPositive ? Colors.green :
                   isNegative ? Colors.red :
                   Colors.grey,
          ),
          SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            '${growth > 0 ? '+' : ''}$growth',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green :
                     isNegative ? Colors.red :
                     Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeTab() {
    final userStats = _userStats?['user'] ?? {};
    final referralCode = userStats['referralCode'] ?? '';
    
    if (referralCode.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: EnhancedQRWidget(
        referralCode: referralCode,
        userName: userStats['fullName'],
        size: 200,
      ),
    );
  }

  String _formatRoleName(String role) {
    return role.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Future<void> _copyReferralCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Referral code copied!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copyReferralLink(String code) async {
    final link = UniversalLinkService.generateReferralLink(code);
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Referral link copied!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareReferralCode(String code) async {
    // This would integrate with the enhanced sharing service
    final link = UniversalLinkService.generateReferralLink(code);
    // await EnhancedSharingService.shareReferralCode(
    //   referralCode: code,
    //   referralLink: link,
    //   userName: _userStats?['user']?['fullName'],
    // );
  }

  void _showQRCode(String code) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your QR Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              EnhancedQRWidget(
                referralCode: code,
                userName: _userStats?['user']?['fullName'],
                size: 250,
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
