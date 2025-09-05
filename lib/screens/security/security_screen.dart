// Security Management Screen for TALOWA
// Comprehensive security dashboard and management interface

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/security/enterprise_security_service.dart';
import '../../widgets/security/security_dashboard_widget.dart';
import '../../widgets/security/audit_trail_widget.dart';
import '../../widgets/security/compliance_report_widget.dart';
import '../../widgets/security/security_settings_widget.dart';

class SecurityScreen extends StatefulWidget {
  final bool isAdminMode;
  
  const SecurityScreen({
    Key? key,
    this.isAdminMode = false,
  }) : super(key: key);
  
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen>
    with TickerProviderStateMixin {
  final EnterpriseSecurityService _securityService = EnterpriseSecurityService();
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Tab controller
  late TabController _tabController;
  
  // State
  bool _isLoading = true;
  Map<String, dynamic>? _securityMetrics;
  
  // Tab configuration
  final List<SecurityTab> _tabs = [
    SecurityTab(
      id: 'dashboard',
      title: 'Dashboard',
      icon: Icons.dashboard,
      description: 'Security overview and real-time metrics',
    ),
    SecurityTab(
      id: 'audit',
      title: 'Audit Trail',
      icon: Icons.history,
      description: 'Security events and audit logs',
    ),
    SecurityTab(
      id: 'compliance',
      title: 'Compliance',
      icon: Icons.assessment,
      description: 'Compliance reports and standards',
    ),
    SecurityTab(
      id: 'settings',
      title: 'Settings',
      icon: Icons.security,
      description: 'Security policies and configuration',
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTabController();
    _initializeSecurityService();
    _loadSecurityMetrics();
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }
  
  void _initializeTabController() {
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
    );
  }
  
  void _initializeSecurityService() {
    // Load initial metrics
    _loadSecurityMetrics();
    
    // Set up periodic refresh
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadSecurityMetrics();
      } else {
        timer.cancel();
      }
    });
  }
  
  Future<void> _loadSecurityMetrics() async {
    try {
      final metrics = await _securityService.getSecurityMetrics();
      
      if (mounted) {
        setState(() {
          _securityMetrics = metrics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading security metrics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  children: [
                    _buildSecurityHeader(),
                    _buildTabBar(),
                    Expanded(
                      child: _buildTabContent(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.security,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Security Center',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.isAdminMode ? 'Administrator Mode' : 'View Mode',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isAdminMode ? Colors.orange : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        if (widget.isAdminMode)
          IconButton(
            onPressed: _showSecurityActions,
            icon: const Icon(Icons.more_vert),
            tooltip: 'Security Actions',
          ),
        IconButton(
          onPressed: _refreshSecurityData,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    );
  }
  
  Widget _buildSecurityHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.1),
            Colors.orange.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enterprise Security Management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor, configure, and manage security policies for your organization',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuickStats(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: Colors.red[600],
                ),
                const SizedBox(height: 8),
                Text(
                  'SECURE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[600],
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickStats() {
    return Row(
      children: [
        _buildStatItem(
          'Active Sessions',
          _securityMetrics?['active_sessions']?.toString() ?? '0',
          Icons.people,
          Colors.blue,
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          'Threats Blocked',
          _securityMetrics?['detected_threats']?.toString() ?? '0',
          Icons.block,
          Colors.red,
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          'Compliance Score',
          '${((_securityMetrics?['compliance_score'] ?? 0.0) * 100).toStringAsFixed(1)}%',
          Icons.verified,
          Colors.green,
        ),
      ],
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        tabs: _tabs.map((tab) => Tab(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tab.icon,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  tab.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorPadding: const EdgeInsets.all(4),
      ),
    );
  }
  
  Widget _buildTabContent() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: TabBarView(
        controller: _tabController,
        children: [
          // Dashboard Tab
          const SecurityDashboardWidget(),
          
          // Audit Trail Tab
          const AuditTrailWidget(
            showFilters: true,
            maxEvents: 100,
          ),
          
          // Compliance Tab
          const ComplianceReportWidget(),
          
          // Settings Tab
          SecuritySettingsWidget(
            isAdminMode: widget.isAdminMode,
          ),
        ],
      ),
    );
  }
  
  void _showSecurityActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            _buildActionTile(
              'Force Password Reset',
              'Require all users to reset their passwords',
              Icons.lock_reset,
              Colors.orange,
              () => _showConfirmationDialog(
                'Force Password Reset',
                'This will require all users to reset their passwords on next login. Continue?',
                _forcePasswordReset,
              ),
            ),
            
            _buildActionTile(
              'Lock All Sessions',
              'Immediately terminate all active user sessions',
              Icons.logout,
              Colors.red,
              () => _showConfirmationDialog(
                'Lock All Sessions',
                'This will immediately log out all users. Continue?',
                _lockAllSessions,
              ),
            ),
            
            _buildActionTile(
              'Generate Security Report',
              'Create comprehensive security audit report',
              Icons.assessment,
              Colors.blue,
              _generateSecurityReport,
            ),
            
            _buildActionTile(
              'Export Audit Logs',
              'Download complete audit trail for analysis',
              Icons.download,
              Colors.green,
              _exportAuditLogs,
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
  
  void _showConfirmationDialog(
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    Navigator.of(context).pop(); // Close bottom sheet
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.warning,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
  
  void _forcePasswordReset() {
    // In a real implementation, this would trigger password reset
    _showActionSnackBar('Password reset initiated for all users', Colors.orange);
  }
  
  void _lockAllSessions() {
    // In a real implementation, this would terminate all sessions
    _showActionSnackBar('All user sessions have been terminated', Colors.red);
  }
  
  void _generateSecurityReport() {
    Navigator.of(context).pop(); // Close bottom sheet
    _showActionSnackBar('Security report generation started', Colors.blue);
  }
  
  void _exportAuditLogs() {
    Navigator.of(context).pop(); // Close bottom sheet
    _showActionSnackBar('Audit logs export initiated', Colors.green);
  }
  
  void _refreshSecurityData() {
    setState(() {
      _isLoading = true;
    });
    _loadSecurityMetrics();
    _showActionSnackBar('Security data refreshed', Colors.blue);
  }
  
  void _showActionSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _tabController.dispose();
    // Metrics subscription cleanup no longer needed
    super.dispose();
  }
}

// Security Tab Model
class SecurityTab {
  final String id;
  final String title;
  final IconData icon;
  final String description;
  
  const SecurityTab({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
  });
}
