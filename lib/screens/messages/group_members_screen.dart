// Group Members Screen for TALOWA Messaging System
// Reference: in-app-communication/requirements.md - Group Member Management

import 'package:flutter/material.dart';
import '../../models/messaging/group_model.dart';
import '../../services/messaging/group_service.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_constants.dart';

class GroupMembersScreen extends StatefulWidget {
  final GroupModel group;

  const GroupMembersScreen({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final GroupService _groupService = GroupService();
  late GroupModel _group;
  String _searchQuery = '';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _currentUserId = AuthService.currentUser?.uid;
  }

  List<GroupMember> get _filteredMembers {
    if (_searchQuery.isEmpty) return _group.members;
    
    return _group.members.where((member) =>
        member.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        member.role.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Future<void> _updateMemberRole(GroupMember member, GroupRole newRole) async {
    try {
      await _groupService.updateMemberRole(
        groupId: _group.id,
        userId: member.userId,
        newRole: newRole,
      );

      // Update local state
      setState(() {
        final index = _group.members.indexWhere((m) => m.userId == member.userId);
        if (index != -1) {
          _group = _group.copyWith(
            members: [
              ..._group.members.sublist(0, index),
              member.copyWith(groupRole: newRole),
              ..._group.members.sublist(index + 1),
            ],
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name}\'s role updated to ${newRole.displayName}'),
            backgroundColor: const Color(AppConstants.successGreenValue),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: const Color(AppConstants.emergencyRedValue),
          ),
        );
      }
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove ${member.name} from this group?'),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _groupService.removeMember(
          groupId: _group.id,
          userId: member.userId,
        );

        // Update local state
        setState(() {
          _group = _group.copyWith(
            members: _group.members.where((m) => m.userId != member.userId).toList(),
            memberCount: _group.memberCount - 1,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${member.name} removed from group'),
              backgroundColor: const Color(AppConstants.successGreenValue),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing member: $e'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Members (${_group.memberCount})'),
        backgroundColor: const Color(AppConstants.talowaGreenValue),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Searching for: "$_searchQuery"',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildMembersList(isAdmin),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(bool isAdmin) {
    final filteredMembers = _filteredMembers;

    if (filteredMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No members found' : 'No members match your search',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Sort members by role (admin, coordinator, member)
    filteredMembers.sort((a, b) {
      final roleOrder = {
        GroupRole.admin: 0,
        GroupRole.coordinator: 1,
        GroupRole.member: 2,
      };
      final aOrder = roleOrder[a.groupRole] ?? 3;
      final bOrder = roleOrder[b.groupRole] ?? 3;
      
      if (aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }
      return a.name.compareTo(b.name);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredMembers.length,
      itemBuilder: (context, index) {
        final member = filteredMembers[index];
        return _buildMemberCard(member, isAdmin);
      },
    );
  }

  Widget _buildMemberCard(GroupMember member, bool isAdmin) {
    final isCurrentUser = member.userId == _currentUserId;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(member.groupRole),
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              member.role,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
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
                const SizedBox(width: 8),
                Text(
                  'Joined ${_formatDate(member.joinedAt)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isAdmin && !isCurrentUser
            ? PopupMenuButton<String>(
                onSelected: (action) => _handleMemberAction(action, member),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'change_role',
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings),
                      title: Text('Change Role'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.remove_circle, color: Colors.red),
                      title: Text('Remove', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
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

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Members'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name or role...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onSubmitted: (value) {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _searchQuery = '';
              });
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _handleMemberAction(String action, GroupMember member) {
    switch (action) {
      case 'change_role':
        _showChangeRoleDialog(member);
        break;
      case 'remove':
        _removeMember(member);
        break;
    }
  }

  void _showChangeRoleDialog(GroupMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${member.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: GroupRole.values.map((role) {
            final isSelected = member.groupRole == role;
            return RadioListTile<GroupRole>(
              title: Text(role.displayName),
              value: role,
              groupValue: member.groupRole,
              onChanged: isSelected ? null : (newRole) {
                Navigator.of(context).pop();
                if (newRole != null) {
                  _updateMemberRole(member, newRole);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}