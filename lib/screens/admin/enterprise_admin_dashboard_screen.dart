// Enterprise Admin Dashboard Screen - Complete admin control panel
// Implements all requirements from ADMIN_SYSTEM.md specification
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/admin/enhanced_admin_auth_service.dart';
import '../../services/admin/admin_dashboard_enhanced_service.dart';
import 'enhanced_moderation_screen.dart';
import 'enhanced_moderation_dashboard_screen.dart';
import 'admin_role_management_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_analytics_screen.dart';
import 'secure_admin_login_screen.dart';

class EnterpriseAdminDashboardScreen extends StatefulWidget {
  const EnterpriseAdminDashboardScreen({super.key});

  @override
  State<EnterpriseAdminDashboardScreen> createState() => _EnterpriseAdminDashboardScreenState();
}

class _EnterpriseAdminDashboardScreenState extends State<EnterpriseAdminDashboardScreen> {
  AdminSessionInfo? _sessionInfo;
  Map<String, dynamic>? _dashboardStats;
  Map<String, dynamic>? _predictiveInsights;
  List<Map<String, dynamic>> _adminAlerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    try {
      // Validate session first
      final isValidSession = await EnhancedAdminAuthService.validateSession();
      if (!isValidSession) {
        _redirectToLogin();
        return;
      }

      await _loadDashboardData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load session info
      final sessionInfo = await EnhancedAdminAuthService.getSessionInfo();
      if (sessionInfo == null) {
        _redirectToLogin();
        return;
      }

      // Load dashboard data in parallel
      final futures = await Future.wait([
        AdminDashboardEnhancedService.getDashboardStats(),
        AdminDashboardEnhancedService.getPredictiveInsights(),
        _loadAdminAlerts(),
      ]);

      setState(() {
        _sessionInfo = sessionInfo;
        _dashboardStats = futures[0] as Map<String, dynamic>;
        _predictiveInsights = futures[1] as Map<String, dynamic>;
        _adminAlerts = futures[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadAdminAlerts() async {
    // Mock implementation - replace with actual service call
    return [
      {
        'id': '1',
        'type': 'security',
        'message': 'Multiple failed login attempts detected',
        'severity': 'high',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      },
      {
        'id': '2',
        'type': 'system',
        'message': 'Database response time increased',
        'severity': 'medium',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      },
    ];
  }

  void _redirectToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SecureAdminLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      drawer: _buildNavigationDrawer(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('TALOWA Admin Portal'),
      backgroundColor: Colors.red[800],
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        // Session timer
        if (_sessionInfo != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _sessionInfo!.sessionRemainingMinutes < 5 
                  ? Colors.orange.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: _sessionInfo!.sessionRemainingMinutes < 5 
                      ? Colors.orange[200] 
                      : Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_sessionInfo!.sessionRemainingMinutes}m',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _sessionInfo!.sessionRemainingMinutes < 5 
                        ? Colors.orange[200] 
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        
        // Role indicator
        if (_sessionInfo != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _sessionInfo!.role.replaceAll('_', ' ').toUpperCase(),
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
        
        // Profile menu
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                subtitle: Text(_sessionInfo?.email ?? 'Admin'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Logout', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationDrawer() {
    if (_sessionInfo == null) return const SizedBox();

    final permissions = _sessionInfo!.permissions;
    final hasAllPermissions = permissions.contains('*');

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[800]!, Colors.red[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  _sessionInfo!.role.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_sessionInfo!.region != null)
                  Text(
                    'Region: ${_sessionInfo!.region}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                Text(
                  _sessionInfo!.email ?? 'Admin User',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  selected: true,
                  onTap: () => Navigator.pop(context),
                ),
                
                if (hasAllPermissions || permissions.contains('moderate_content'))
                  ListTile(
                    leading: const Icon(Icons.gavel),
                    title: const Text('Content Moderation'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EnhancedModerationDashboardScreen(),
                        ),
                      );
                    },
                  ),
                
                if (hasAllPermissions)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Role Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminRoleManagementScreen(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
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
            Text('Loading admin dashboard...'),
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
            // Welcome header with session info
            _buildWelcomeHeader(),
            const SizedBox(height: 24),
            
            // Key metrics dashboard
            _buildKeyMetricsGrid(),
            const SizedBox(height: 24),
            
            // Admin actions based on role
            _buildRoleBasedActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final user = FirebaseAuth.instance.currentUser;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[800]!, Colors.red[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
                    Text(
                      'Welcome, ${_sessionInfo?.role.replaceAll('_', ' ').toUpperCase() ?? 'Admin'}',
                      style: const TextStyle(
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
        ],
      ),
    );
  }

  Widget _buildKeyMetricsGrid() {
    final userStats = _dashboardStats?['userStats'] as Map<String, dynamic>? ?? {};
    final referralStats = _dashboardStats?['referralStats'] as Map<String, dynamic>? ?? {};

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Active Users',
          '${userStats['activeUsers'] ?? 0}',
          '${userStats['activeUserPercentage'] ?? 0}% of total',
          Icons.people_alt,
          Colors.blue,
        ),
        _buildMetricCard(
          'Total Referrals',
          '${referralStats['totalReferrals'] ?? 0}',
          '${referralStats['conversionRate'] ?? 0}% conversion',
          Icons.share,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title, 
    String value, 
    String subtitle, 
    IconData icon, 
    Color color,
  ) {
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

  Widget _buildRoleBasedActions() {
    if (_sessionInfo == null) return const SizedBox();

    final permissions = _sessionInfo!.permissions;
    final hasAllPermissions = permissions.contains('*');

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
            if (hasAllPermissions || permissions.contains('moderate_content'))
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
            
            if (hasAllPermissions)
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

  // Event handlers
  void _handleMenuAction(String action) {
    switch (action) {
      case 'profile':
        _showProfileDialog();
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${_sessionInfo?.email ?? 'N/A'}'),
            Text('Role: ${_sessionInfo?.role ?? 'N/A'}'),
            if (_sessionInfo?.region != null)
              Text('Region: ${_sessionInfo!.region}'),
            Text('Session: ${_sessionInfo?.sessionRemainingMinutes ?? 0} minutes remaining'),
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout from the admin panel?'),
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

    if (confirm == true) {
      await EnhancedAdminAuthService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SecureAdminLoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
