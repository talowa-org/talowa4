// Admin Role Management Screen - Manage admin roles and permissions
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin/enhanced_admin_auth_service.dart';

enum AdminRole {
  superAdmin('super_admin'),
  moderator('moderator'),
  regionalAdmin('regional_admin'),
  auditor('auditor');

  const AdminRole(this.value);
  final String value;
  
  static AdminRole fromString(String value) {
    return AdminRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => AdminRole.moderator,
    );
  }
}

class AdminRoleManagementScreen extends StatefulWidget {
  const AdminRoleManagementScreen({super.key});

  @override
  State<AdminRoleManagementScreen> createState() => _AdminRoleManagementScreenState();
}

class _AdminRoleManagementScreenState extends State<AdminRoleManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _adminUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdminUsers();
  }

  Future<void> _loadAdminUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['super_admin', 'moderator', 'regional_admin', 'auditor'])
          .get();

      setState(() {
        _adminUsers = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
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
        title: const Text('Role Management'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdminUsers,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAssignRoleDialog,
        backgroundColor: Colors.purple[800],
        child: const Icon(Icons.add, color: Colors.white),
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
            Text('Loading admin users...'),
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
            Text('Error loading data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[800])),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAdminUsers, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_adminUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.admin_panel_settings, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No admin users found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Use the + button to assign admin roles'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAdminUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _adminUsers.length,
        itemBuilder: (context, index) {
          final user = _adminUsers[index];
          return _buildAdminUserCard(user);
        },
      ),
    );
  }

  Widget _buildAdminUserCard(Map<String, dynamic> user) {
    final role = user['role'] as String? ?? 'member';
    final region = user['region'] as String?;
    
    Color roleColor = Colors.blue;
    IconData roleIcon = Icons.person;
    
    switch (role) {
      case 'super_admin':
        roleColor = Colors.red;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'moderator':
        roleColor = Colors.orange;
        roleIcon = Icons.gavel;
        break;
      case 'regional_admin':
        roleColor = Colors.green;
        roleIcon = Icons.location_on;
        break;
      case 'auditor':
        roleColor = Colors.purple;
        roleIcon = Icons.visibility;
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
                CircleAvatar(
                  backgroundColor: roleColor.withValues(alpha: 0.1),
                  child: Icon(roleIcon, color: roleColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] as String? ?? 'Unknown User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        user['phoneNumber'] as String? ?? 'No phone',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if (user['email'] != null)
                        Text(
                          user['email'] as String,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            
            if (region != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Region: $region', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showUserDetails(user),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRoleChangeDialog(user),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Change Role'),
                    style: ElevatedButton.styleFrom(backgroundColor: roleColor, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignRoleDialog() {
    final uidController = TextEditingController();
    AdminRole selectedRole = AdminRole.moderator;
    final regionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Admin Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uidController,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  border: OutlineInputBorder(),
                  helperText: 'Enter the Firebase UID of the user',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AdminRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: AdminRole.values.map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role.value.replaceAll('_', ' ').toUpperCase()),
                )).toList(),
                onChanged: (role) => setState(() => selectedRole = role!),
              ),
              if (selectedRole == AdminRole.regionalAdmin) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: regionController,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                    helperText: 'e.g., Telangana, Andhra Pradesh',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _assignRole(
                uidController.text,
                selectedRole,
                regionController.text.isEmpty ? null : regionController.text,
              ),
              child: const Text('Assign Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleChangeDialog(Map<String, dynamic> user) {
    AdminRole selectedRole = AdminRole.values.firstWhere(
      (role) => role.value == user['role'],
      orElse: () => AdminRole.moderator,
    );
    final regionController = TextEditingController(text: user['region'] as String? ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Change Role: ${user['name'] ?? 'Unknown'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AdminRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'New Role',
                  border: OutlineInputBorder(),
                ),
                items: AdminRole.values.map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role.value.replaceAll('_', ' ').toUpperCase()),
                )).toList(),
                onChanged: (role) => setState(() => selectedRole = role!),
              ),
              if (selectedRole == AdminRole.regionalAdmin) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: regionController,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _revokeRole(user['id']),
                icon: const Icon(Icons.remove_circle),
                label: const Text('Revoke Admin Role'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _assignRole(
                user['id'],
                selectedRole,
                regionController.text.isEmpty ? null : regionController.text,
              ),
              child: const Text('Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? 'User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ID: ${user['id']}'),
              Text('Phone: ${user['phoneNumber'] ?? 'Unknown'}'),
              Text('Email: ${user['email'] ?? 'Not provided'}'),
              Text('Role: ${user['role'] ?? 'member'}'),
              if (user['region'] != null) Text('Region: ${user['region']}'),
              if (user['roleAssignedAt'] != null)
                Text('Role Assigned: ${_formatDateTime((user['roleAssignedAt'] as Timestamp).toDate())}'),
              if (user['roleAssignedBy'] != null) Text('Assigned By: ${user['roleAssignedBy']}'),
            ],
          ),
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

  Future<void> _assignRole(String targetUid, AdminRole role, String? region) async {
    if (targetUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a user ID'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      Navigator.of(context).pop(); // Close dialog

      final result = await EnhancedAdminAuthService.assignAdminRole(
        targetUid: targetUid,
        role: role.value,
        region: region,
      );

      if (result.success) {
        _loadAdminUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message), backgroundColor: Colors.red),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning role: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _revokeRole(String targetUid) async {
    try {
      Navigator.of(context).pop(); // Close dialog

      final result = await EnhancedAdminAuthService.revokeAdminRole(targetUid: targetUid);

      if (result.success) {
        _loadAdminUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message), backgroundColor: Colors.red),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error revoking role: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}