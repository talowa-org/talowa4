// Blocked Users Management Screen for TALOWA
// Implements Task 18: Add security and content safety - Blocked Users UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/security/user_safety_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final UserSafetyService _safetyService = UserSafetyService();
  
  List<BlockedUser> _blockedUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = context.read<AuthProvider>().currentUser?.uid;
      if (userId == null) return;

      final blockedUsers = await _safetyService.getBlockedUsers(userId);

      setState(() {
        _blockedUsers = blockedUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(BlockedUser user) async {
    try {
      final userId = context.read<AuthProvider>().currentUser?.uid;
      if (userId == null) return;

      await _safetyService.unblockUser(
        blockerId: userId,
        blockedUserId: user.userId,
      );

      setState(() {
        _blockedUsers.removeWhere((u) => u.userId == user.userId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} has been unblocked')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unblocking user: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
              ? ErrorDisplayWidget(
                  error: _error!,
                  onRetry: _loadBlockedUsers,
                )
              : _buildBlockedUsersList(),
    );
  }

  Widget _buildBlockedUsersList() {
    if (_blockedUsers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadBlockedUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _blockedUsers.length,
        itemBuilder: (context, index) {
          final user = _blockedUsers[index];
          return _buildBlockedUserCard(user);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Blocked Users',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Users you block will appear here.\nYou can unblock them anytime.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUserCard(BlockedUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  imageUrl: user.avatarUrl,
                  name: user.name,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Blocked ${_formatDate(user.blockedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'unblock') {
                      _showUnblockConfirmation(user);
                    } else if (value == 'details') {
                      _showUserDetails(user);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'unblock',
                      child: Row(
                        children: [
                          Icon(Icons.block, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Unblock User'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (user.reason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${user.reason}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showUnblockConfirmation(user),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Unblock'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUnblockConfirmation(BlockedUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to unblock ${user.name}?'),
            const SizedBox(height: 12),
            const Text(
              'After unblocking:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('• They can send you messages again'),
            const Text('• They can see your posts and profile'),
            const Text('• They can interact with your content'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _unblockUser(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(BlockedUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user.name} - Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', user.name),
            _buildDetailRow('Blocked Date', _formatDate(user.blockedAt)),
            if (user.reason != null)
              _buildDetailRow('Reason', user.reason!),
            const SizedBox(height: 16),
            const Text(
              'Actions Available:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Unblock this user'),
            const Text('• Report if harassment continues'),
            const Text('• Contact support for help'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (user.reason?.contains('harassment') == true)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _reportContinuedHarassment(user);
              },
              child: const Text('Report'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _reportContinuedHarassment(BlockedUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Continued Harassment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Report ${user.name} for continued harassment?'),
            const SizedBox(height: 12),
            const Text(
              'This will notify our safety team to investigate further action.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitHarassmentReport(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitHarassmentReport(BlockedUser user) async {
    try {
      final userId = context.read<AuthProvider>().currentUser?.uid;
      if (userId == null) return;

      await _safetyService.reportUser(
        reporterId: userId,
        reportedUserId: user.userId,
        reason: UserReportReason.harassment,
        description: 'Continued harassment after being blocked',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Our safety team will investigate.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting report: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays > 730 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays > 60 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}