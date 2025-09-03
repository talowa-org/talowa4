// Enhanced Admin Dashboard Screen - Enterprise-grade admin interface
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/admin/enhanced_admin_auth_service.dart';
import '../../services/admin/admin_dashboard_enhanced_service.dart';
import 'enhanced_moderation_screen.dart';
import 'admin_role_management_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_analytics_screen.dart';

class EnhancedAdminDashboardScreen extends StatefulWidget {
  const EnhancedAdminDashboardScreen({super.key});

  @override
  State<EnhancedAdminDashboardScreen> createState() => _EnhancedAdminDashboardScreenState();
}

class _EnhancedAdminDashboardScreenState extends State<EnhancedAdminDashboardScreen> {
  Map<String, dynamic>? _dashboardStats;
  Map<String, dynamic>? _predictiveInsights;
  String? _currentUserRole;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Verify admin access
      final accessCheck = await EnhancedAdminAuthService.checkAdminAccess();
      if (!accessCheck.success) {
        throw Exception('Admin access denied: ${accessCheck.message}');
      }

      setState(() {
        _currentUserRole = accessCheck.role;
      });

      // Load dashboard data in parallel
      final futures = await Future.wait([
        AdminDashboardEnhancedService.getDashboardStats(),
        AdminDashboardEnhancedService.getPredictiveInsights(),
      ]);

      setState(() {
        _dashboardStats = futures[0];
        _predictiveInsights = futures[1];
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        actions: [
          // Role indicator
          if (_currentUserRole != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _currentUserRole!.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
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
            Text('Loading dashboard...'),
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
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            _buildWelcomeHeader(),
            const SizedBox(height: 24),
            
            // Quick stats cards
            _buildQuickStatsGrid(),
            const SizedBox(height: 24),
            
            // Admin actions grid
            _buildAdminActionsGrid(),
            const SizedBox(height: 24),
            
            // Growth chart section
            _buildGrowthSection(),
            const SizedBox(height: 24),
            
            // Real-time events
            _buildRealTimeEvents(),
            const SizedBox(height: 24),
            
            // Predictive insights
            _buildPredictiveInsights(),
            const SizedBox(height: 24),
            
            // System health
            _buildSystemHealth(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final userStats = _dashboardStats?['userStats'] as Map<String, dynamic>? ?? {};
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[800]!, Colors.red[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome, Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user?.email != null)
                      Text(
                        user!.email!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(
                'Total Users',
                '${userStats['totalUsers'] ?? 0}',
                Icons.people,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                'Active Today',
                '${userStats['newUsersToday'] ?? 0}',
                Icons.trending_up,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    final userStats = _dashboardStats?['userStats'] as Map<String, dynamic>? ?? {};
    final referralStats = _dashboardStats?['referralStats'] as Map<String, dynamic>? ?? {};
    final fraudStats = _dashboardStats?['fraudDetection'] as Map<String, dynamic>? ?? {};
    final systemHealth = _dashboardStats?['systemHealth'] as Map<String, dynamic>? ?? {};

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Active Users',
          '${userStats['activeUsers'] ?? 0}',
          '${userStats['activeUserPercentage'] ?? 0}% of total',
          Icons.people_alt,
          Colors.blue,
        ),
        _buildStatCard(
          'Total Referrals',
          '${referralStats['totalReferrals'] ?? 0}',
          '${referralStats['conversionRate'] ?? 0}% conversion',
          Icons.share,
          Colors.green,
        ),
        _buildStatCard(
          'Flagged Activities',
          '${fraudStats['pendingFlags'] ?? 0}',
          'Need attention',
          Icons.flag,
          Colors.orange,
        ),
        _buildStatCard(
          'System Health',
          systemHealth['status'] == 'healthy' ? 'Healthy' : 'Issues',
          '${systemHealth['dbResponseTime'] ?? 0}ms response',
          Icons.health_and_safety,
          systemHealth['status'] == 'healthy' ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionsGrid() {
    final isSuperAdmin = _currentUserRole == 'super_admin';
    final isModerator = _currentUserRole == 'super_admin' || _currentUserRole == 'moderator';
    final isAuditor = _currentUserRole == 'super_admin' || _currentUserRole == 'auditor';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: [
            if (isModerator)
              _buildActionCard(
                'Content Moderation',
                Icons.gavel,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EnhancedModerationScreen(),
                  ),
                ),
              ),
            
            if (isSuperAdmin)
              _buildActionCard(
                'Role Management',
                Icons.admin_panel_settings,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminRoleManagementScreen(),
                  ),
                ),
              ),
            
            if (isAuditor)
              _buildActionCard(
                'Audit Logs',
                Icons.history,
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminAuditLogsScreen(),
                  ),
                ),
              ),
            
            _buildActionCard(
              'Analytics',
              Icons.analytics,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAnalyticsScreen(),
                ),
              ),
            ),
            
            _buildActionCard(
              'Flag Suspicious',
              Icons.security,
              Colors.red,
              _flagSuspiciousActivities,
            ),
            
            _buildActionCard(
              'System Health',
              Icons.monitor_heart,
              Colors.teal,
              () => _showSystemHealthDialog(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthSection() {
    final growthStats = _dashboardStats?['growthStats'] as Map<String, dynamic>? ?? {};
    final dailyGrowth = growthStats['dailyGrowth'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Growth Trends (Last 30 Days)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${growthStats['weeklyGrowthRate'] ?? 0}% weekly',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Simple growth visualization
          SizedBox(
            height: 100,
            child: dailyGrowth.isNotEmpty
                ? _buildSimpleChart(dailyGrowth)
                : const Center(child: Text('No growth data available')),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleChart(List<dynamic> dailyGrowth) {
    final maxValue = dailyGrowth
        .map((day) => (day['newUsers'] as int? ?? 0))
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    if (maxValue == 0) {
      return const Center(child: Text('No data to display'));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: dailyGrowth.map<Widget>((day) {
        final value = (day['newUsers'] as int? ?? 0).toDouble();
        final height = (value / maxValue * 80).clamp(2.0, 80.0);
        
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            height: height,
            decoration: BoxDecoration(
              color: Colors.blue[400],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRealTimeEvents() {
    final activeEvents = _dashboardStats?['activeEvents'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Real-time Events',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          if (activeEvents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No recent events'),
              ),
            )
          else
            ...activeEvents.take(5).map<Widget>((event) {
              final severity = event['severity'] as String? ?? 'info';
              Color severityColor = Colors.blue;
              
              switch (severity) {
                case 'high':
                  severityColor = Colors.red;
                  break;
                case 'medium':
                  severityColor = Colors.orange;
                  break;
                default:
                  severityColor = Colors.blue;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: severityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        event['message'] as String? ?? 'Unknown event',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildPredictiveInsights() {
    final insights = _predictiveInsights ?? {};
    final trends = insights['trends'] as List<dynamic>? ?? [];
    final recommendations = insights['recommendations'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Predictive Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          if (trends.isNotEmpty) ...[
            const Text(
              'Trends:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...trends.map<Widget>((trend) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(trend.toString())),
                ],
              ),
            )).toList(),
            const SizedBox(height: 12),
          ],
          
          if (recommendations.isNotEmpty) ...[
            const Text(
              'Recommendations:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...recommendations.map<Widget>((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(rec.toString())),
                ],
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemHealth() {
    final systemHealth = _dashboardStats?['systemHealth'] as Map<String, dynamic>? ?? {};
    final status = systemHealth['status'] as String? ?? 'unknown';
    final dbResponseTime = systemHealth['dbResponseTime'] as int? ?? 0;
    final uptime = systemHealth['uptime'] as String? ?? 'Unknown';

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help;

    switch (status) {
      case 'healthy':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'warning':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'System Health',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DB Response Time',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${dbResponseTime}ms',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uptime',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      uptime,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _flagSuspiciousActivities() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Scanning for suspicious activities...'),
            ],
          ),
        ),
      );

      final result = await EnhancedAdminAuthService.flagSuspiciousReferrals();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Scan Complete'),
            content: Text(
              'Found ${result['flaggedCount'] ?? 0} suspicious activities.\n'
              'Check the moderation screen for details.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        // Refresh dashboard
        _loadDashboardData();
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning activities: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSystemHealthDialog() {
    final systemHealth = _dashboardStats?['systemHealth'] as Map<String, dynamic>? ?? {};
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Health Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthItem('Status', systemHealth['status'] ?? 'Unknown'),
            _buildHealthItem('DB Response', '${systemHealth['dbResponseTime'] ?? 0}ms'),
            _buildHealthItem('Uptime', systemHealth['uptime'] ?? 'Unknown'),
            _buildHealthItem('Errors (24h)', '${systemHealth['errorCount24h'] ?? 0}'),
            _buildHealthItem('Warnings (24h)', '${systemHealth['warningCount24h'] ?? 0}'),
            _buildHealthItem('Alerts (24h)', '${systemHealth['alertCount24h'] ?? 0}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }
}