// Group Detail Screen for TALOWA Messaging System
// Reference: in-app-communication/requirements.md - Group Management

import 'package:flutter/material.dart';
import '../../models/messaging/group_model.dart';
import '../../services/messaging/group_service.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/common/loading_widget.dart';
import 'group_settings_screen.dart';
import 'group_members_screen.dart';
import 'bulk_message_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailScreen({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final GroupService _groupService = GroupService();
  late GroupModel _group;
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _currentUserId = AuthService.currentUser?.uid;
    _refreshGroup();
  }

  Future<void> _refreshGroup() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final updatedGroup = await _groupService.getGroup(_group.id);
      if (updatedGroup != null) {
        setState(() {
          _group = updatedGroup;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing group: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.emergencyRedValue),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentUserId != null) {
      try {
        await _groupService.removeMember(
          groupId: _group.id,
          userId: _currentUserId!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left group successfully')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error leaving group: $e'),
              backgroundColor: const Color(AppConstants.emergencyRedValue),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMember = _currentUserId != null ? _group.getMember(_currentUserId!) : null;
    final isAdmin = currentMember?.groupRole == GroupRole.admin;
    final isCoordinator = currentMember?.groupRole == GroupRole.coordinator;
    final canManage = isAdmin || isCoordinator;

    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        backgroundColor: const Color(AppConstants.talowaGreenValue),
        foregroundColor: Colors.white,
        actions: [
          if (canManage)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Group Settings'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'bulk_message',
                  child: ListTile(
                    leading: Icon(Icons.send),
                    title: Text('Send Bulk Message'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (isAdmin)
                  const PopupMenuItem(
                    value: 'analytics',
                    child: ListTile(
                      leading: Icon(Icons.analytics),
                      title: Text('View Analytics'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          PopupMenuButton<String>(
            onSelected: _handleUserMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.exit_to_app, color: Colors.red),
                  title: Text('Leave Group', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshGroup,
        child: _isLoading ? const LoadingWidget() : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGroupHeader(),
        const SizedBox(height: 24),
        _buildGroupInfo(),
        const SizedBox(height: 24),
        _buildMembersSection(),
        const SizedBox(height: 24),
        _buildActionsSection(),
      ],
    );
  }

  Widget _buildGroupHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: _getGroupTypeColor(_group.type),
              backgroundImage: _group.avatarUrl != null 
                  ? NetworkImage(_group.avatarUrl!)
                  : null,
              child: _group.avatarUrl == null
                  ? Icon(
                      _getGroupTypeIcon(_group.type),
                      color: Colors.white,
                      size: 32,
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              _group.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_group.description.isNotEmpty)
              Text(
                _group.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getGroupTypeColor(_group.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _group.type.displayName,
                style: TextStyle(
                  color: _getGroupTypeColor(_group.type),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.people,
              'Members',
              '${_group.memberCount} / ${_group.maxMembers}',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.location_on,
              'Location',
              '${_group.location.locationName} (${_group.location.level})',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Created',
              _formatDate(_group.createdAt),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.update,
              'Last Updated',
              _formatDate(_group.updatedAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    final currentMember = _currentUserId != null ? _group.getMember(_currentUserId!) : null;
    final canManageMembers = currentMember != null && _group.canAddMembers(_currentUserId!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Members (${_group.memberCount})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToMembers(),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Show first few members
            ...(_group.members.take(3).map((member) => _buildMemberTile(member))),
            if (_group.memberCount > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _navigateToMembers(),
                  child: Text('View ${_group.memberCount - 3} more members'),
                ),
              ),
            ],
            if (canManageMembers) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddMemberDialog(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Members'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.talowaGreenValue),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(GroupMember member) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(AppConstants.talowaGreenValue),
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(member.name),
      subtitle: Text(member.role),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getRoleColor(member.groupRole).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          member.groupRole.displayName,
          style: TextStyle(
            color: _getRoleColor(member.groupRole),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    final currentMember = _currentUserId != null ? _group.getMember(_currentUserId!) : null;
    final canSendMessages = currentMember != null && _group.canSendMessages(_currentUserId!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (canSendMessages)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToBulkMessage(),
                  icon: const Icon(Icons.send),
                  label: const Text('Send Message to Group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.talowaGreenValue),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _navigateToMembers(),
                icon: const Icon(Icons.people),
                label: const Text('View All Members'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGroupTypeColor(GroupType type) {
    switch (type) {
      case GroupType.village:
        return const Color(AppConstants.talowaGreenValue);
      case GroupType.mandal:
        return const Color(AppConstants.legalBlueValue);
      case GroupType.district:
        return const Color(AppConstants.warningOrangeValue);
      case GroupType.campaign:
        return const Color(AppConstants.successGreenValue);
      case GroupType.legalCase:
        return const Color(AppConstants.emergencyRedValue);
      case GroupType.custom:
        return Colors.purple;
    }
  }

  IconData _getGroupTypeIcon(GroupType type) {
    switch (type) {
      case GroupType.village:
        return Icons.home;
      case GroupType.mandal:
        return Icons.location_city;
      case GroupType.district:
        return Icons.map;
      case GroupType.campaign:
        return Icons.campaign;
      case GroupType.legalCase:
        return Icons.gavel;
      case GroupType.custom:
        return Icons.group;
    }
  }

  Color _getRoleColor(GroupRole role) {
    switch (role) {
      case GroupRole.admin:
        return const Color(AppConstants.emergencyRedValue);
      case GroupRole.coordinator:
        return const Color(AppConstants.legalBlueValue);
      case GroupRole.member:
        return const Color(AppConstants.talowaGreenValue);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'settings':
        _navigateToSettings();
        break;
      case 'bulk_message':
        _navigateToBulkMessage();
        break;
      case 'analytics':
        _showAnalytics();
        break;
    }
  }

  void _handleUserMenuAction(String action) {
    switch (action) {
      case 'leave':
        _leaveGroup();
        break;
    }
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupSettingsScreen(group: _group),
      ),
    ).then((_) => _refreshGroup());
  }

  void _navigateToMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupMembersScreen(group: _group),
      ),
    ).then((_) => _refreshGroup());
  }

  void _navigateToBulkMessage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BulkMessageScreen(group: _group),
      ),
    );
  }

  void _showAddMemberDialog() {
    // TODO: Implement add member dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add member functionality coming soon')),
    );
  }

  void _showAnalytics() async {
    try {
      final analytics = await _groupService.getGroupAnalytics(_group.id);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Group Analytics'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Members: ${analytics.totalMembers}'),
                Text('Active Members: ${analytics.activeMembers}'),
                Text('Coordinators: ${analytics.coordinators}'),
                Text('Admins: ${analytics.admins}'),
                Text('Messages: ${analytics.messageCount}'),
                Text('Activity Rate: ${(analytics.activityRate * 100).toStringAsFixed(1)}%'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: $e'),
            backgroundColor: const Color(AppConstants.emergencyRedValue),
          ),
        );
      }
    }
  }
}