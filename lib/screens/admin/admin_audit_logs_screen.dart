// Admin Audit Logs Screen - View transparency logs and admin actions
import 'package:flutter/material.dart';
import '../../services/admin/enhanced_admin_auth_service.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final logs = await EnhancedAdminAuthService.getAuditLogs(limit: 100);

      setState(() {
        _auditLogs = logs;
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
        title: const Text('Audit Logs'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAuditLogs,
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
            Text('Loading audit logs...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text('Error loading logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[800])),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAuditLogs, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_auditLogs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No audit logs found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Admin actions will appear here'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAuditLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _auditLogs.length,
        itemBuilder: (context, index) {
          final log = _auditLogs[index];
          return _buildAuditLogCard(log);
        },
      ),
    );
  }

  Widget _buildAuditLogCard(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? 'unknown';
    final adminUid = log['adminUid'] as String? ?? 'Unknown';
    final targetUid = log['targetUid'] as String?;
    final details = log['details'] as Map<String, dynamic>? ?? {};
    
    // Parse timestamp
    DateTime? timestamp;
    if (log['timestamp'] != null) {
      try {
        timestamp = DateTime.parse(log['timestamp'].toString());
      } catch (e) {
        // Handle Firestore Timestamp
        if (log['timestamp'].runtimeType.toString().contains('Timestamp')) {
          timestamp = (log['timestamp'] as dynamic).toDate();
        }
      }
    }

    Color actionColor = Colors.blue;
    IconData actionIcon = Icons.info;
    
    switch (action) {
      case 'assign_role':
        actionColor = Colors.green;
        actionIcon = Icons.admin_panel_settings;
        break;
      case 'revoke_role':
        actionColor = Colors.red;
        actionIcon = Icons.remove_circle;
        break;
      case 'moderate_ban_user':
        actionColor = Colors.red;
        actionIcon = Icons.block;
        break;
      case 'moderate_unban_user':
        actionColor = Colors.green;
        actionIcon = Icons.restore;
        break;
      case 'flag_suspicious_referrals':
        actionColor = Colors.orange;
        actionIcon = Icons.flag;
        break;
      case 'validate_access':
        actionColor = Colors.purple;
        actionIcon = Icons.security;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(actionIcon, color: actionColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatActionName(action),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Admin: ${adminUid.substring(0, 8)}...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (timestamp != null)
                        Text(
                          _formatDateTime(timestamp),
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    action.toUpperCase(),
                    style: TextStyle(color: actionColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            
            if (targetUid != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Target: ${targetUid.substring(0, 8)}...', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
            
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Details:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    ...details.entries.map((entry) => Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 11),
                    )).toList(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatActionName(String action) {
    switch (action) {
      case 'assign_role':
        return 'Role Assigned';
      case 'revoke_role':
        return 'Role Revoked';
      case 'moderate_ban_user':
        return 'User Banned';
      case 'moderate_unban_user':
        return 'User Unbanned';
      case 'flag_suspicious_referrals':
        return 'Flagged Suspicious Activity';
      case 'validate_access':
        return 'Access Validation';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

