// Admin Access Widget - Shows admin options for authorized users
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/admin/admin_access_service.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/enhanced_moderation_dashboard_screen.dart';

class AdminAccessWidget extends StatefulWidget {
  const AdminAccessWidget({super.key});

  @override
  State<AdminAccessWidget> createState() => _AdminAccessWidgetState();
}

class _AdminAccessWidgetState extends State<AdminAccessWidget> {
  bool _isAdmin = false;
  bool _isCoordinator = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final isAdmin = await AdminAccessService.isCurrentUserAdmin();
      final isCoordinator = await AdminAccessService.isCurrentUserCoordinator();
      
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _isCoordinator = isCoordinator;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Don't show anything if user is not admin or coordinator
    if (!_isAdmin && !_isCoordinator) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isAdmin ? Icons.admin_panel_settings : Icons.supervisor_account,
                  color: _isAdmin ? Colors.red : AppTheme.talowaGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  _isAdmin ? 'Admin Panel' : 'Coordinator Tools',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isAdmin) ...[
              _buildAdminButton(
                'Admin Dashboard',
                'System overview and management',
                Icons.dashboard,
                Colors.red,
                _openAdminDashboard,
              ),
              const SizedBox(height: 8),
              _buildAdminButton(
                'Content Moderation',
                'Review reports and moderate content',
                Icons.report_problem,
                Colors.orange,
                _openContentModeration,
              ),
              const SizedBox(height: 8),
              _buildAdminButton(
                'User Management',
                'Manage users and permissions',
                Icons.people,
                Colors.blue,
                _openUserManagement,
              ),
            ],
            
            if (_isCoordinator && !_isAdmin) ...[
              _buildAdminButton(
                'Coordinator Dashboard',
                'Group management and analytics',
                Icons.supervisor_account,
                AppTheme.talowaGreen,
                _openCoordinatorDashboard,
              ),
              const SizedBox(height: 8),
              _buildAdminButton(
                'Group Management',
                'Manage your groups and members',
                Icons.group,
                AppTheme.talowaGreen,
                _openGroupManagement,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.2),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  void _openAdminDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminDashboardScreen(),
      ),
    );
  }

  void _openContentModeration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EnhancedModerationDashboardScreen(),
      ),
    );
  }

  void _openUserManagement() {
    // Navigate to user management screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening User Management...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _openCoordinatorDashboard() {
    // Navigate to coordinator dashboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Coordinator Dashboard...'),
        backgroundColor: AppTheme.talowaGreen,
      ),
    );
  }

  void _openGroupManagement() {
    // Navigate to group management
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Group Management...'),
        backgroundColor: AppTheme.talowaGreen,
      ),
    );
  }
}


