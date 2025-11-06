// User Selection Screen for TALOWA Messaging System
// Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 4.1, 4.2
// Task: Build real user data display and user listing functionality

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/messaging/user_list_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/messages/user_list_widget.dart';


/// Screen for selecting users to start conversations with
class UserSelectionScreen extends StatefulWidget {
  final String title;
  final bool multiSelect;
  final List<String>? excludeUserIds;
  final String? roleFilter;
  final String? locationFilter;
  final Function(UserModel)? onUserSelected;
  final Function(List<UserModel>)? onUsersSelected;

  const UserSelectionScreen({
    super.key,
    this.title = 'Select User',
    this.multiSelect = false,
    this.excludeUserIds,
    this.roleFilter,
    this.locationFilter,
    this.onUserSelected,
    this.onUsersSelected,
  });

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final UserListService _userListService = UserListService();
  final Set<String> _selectedUserIds = {};
  final List<UserModel> _selectedUsers = [];
  
  String _searchQuery = '';
  String? _currentRoleFilter;
  bool _showOnlineOnly = false;

  @override
  void initState() {
    super.initState();
    _currentRoleFilter = widget.roleFilter;
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _userListService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.talowaGreen,
        elevation: AppTheme.elevationLow,
        actions: [
          if (widget.multiSelect && _selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                'Done (${_selectedUsers.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: _handleFilterAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'role_all',
                child: Row(
                  children: [
                    Icon(
                      _currentRoleFilter == null ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('All Roles'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'role_coordinator',
                child: Row(
                  children: [
                    Icon(
                      _currentRoleFilter == 'coordinator' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Coordinators'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'role_legal_advisor',
                child: Row(
                  children: [
                    Icon(
                      _currentRoleFilter == 'legal_advisor' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Legal Advisors'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'role_member',
                child: Row(
                  children: [
                    Icon(
                      _currentRoleFilter == 'member' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Members'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'online_toggle',
                child: Row(
                  children: [
                    Icon(
                      _showOnlineOnly ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Online Only'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          if (_hasActiveFilters()) _buildFilterChips(),
          
          // User list
          Expanded(
            child: UserListWidget(
              searchQuery: _searchQuery,
              roleFilter: _currentRoleFilter,
              locationFilter: widget.locationFilter,
              onUserTap: _handleUserTap,
              onUserLongPress: _handleUserLongPress,
              showOnlineStatus: true,
              enableSearch: true,
              enablePagination: true,
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.multiSelect && _selectedUsers.isNotEmpty
          ? _buildSelectionBottomBar()
          : null,
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          if (_currentRoleFilter != null)
            FilterChip(
              label: Text(_getRoleDisplayName(_currentRoleFilter!)),
              selected: true,
              onSelected: (_) => _handleFilterAction('role_all'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _handleFilterAction('role_all'),
            ),
          if (_showOnlineOnly)
            FilterChip(
              label: const Text('Online Only'),
              selected: true,
              onSelected: (_) => _handleFilterAction('online_toggle'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _handleFilterAction('online_toggle'),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedUsers.length} user${_selectedUsers.length == 1 ? '' : 's'} selected',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_selectedUsers.isNotEmpty)
                  Text(
                    _selectedUsers.map((u) => u.fullName).take(3).join(', ') +
                        (_selectedUsers.length > 3 ? '...' : ''),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _confirmSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _handleUserTap(UserModel user) {
    // Skip excluded users
    if (widget.excludeUserIds?.contains(user.id) == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user cannot be selected'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (widget.multiSelect) {
      setState(() {
        if (_selectedUserIds.contains(user.id)) {
          _selectedUserIds.remove(user.id);
          _selectedUsers.removeWhere((u) => u.id == user.id);
        } else {
          _selectedUserIds.add(user.id);
          _selectedUsers.add(user);
        }
      });
    } else {
      // Single select - return immediately
      widget.onUserSelected?.call(user);
      Navigator.pop(context, user);
    }
  }

  void _handleUserLongPress(UserModel user) {
    _showUserDetails(user);
  }

  void _handleFilterAction(String action) {
    setState(() {
      switch (action) {
        case 'role_all':
          _currentRoleFilter = null;
          break;
        case 'role_coordinator':
          _currentRoleFilter = 'coordinator';
          break;
        case 'role_legal_advisor':
          _currentRoleFilter = 'legal_advisor';
          break;
        case 'role_member':
          _currentRoleFilter = 'member';
          break;
        case 'online_toggle':
          _showOnlineOnly = !_showOnlineOnly;
          break;
      }
    });
  }

  void _confirmSelection() {
    if (_selectedUsers.isEmpty) return;
    
    widget.onUsersSelected?.call(_selectedUsers);
    Navigator.pop(context, _selectedUsers);
  }

  void _showUserDetails(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailsSheet(user: user),
    );
  }

  bool _hasActiveFilters() {
    return _currentRoleFilter != null || _showOnlineOnly;
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'coordinator':
        return 'Coordinators';
      case 'legal_advisor':
        return 'Legal Advisors';
      case 'member':
        return 'Members';
      default:
        return role;
    }
  }
}

/// Bottom sheet for displaying user details
class _UserDetailsSheet extends StatelessWidget {
  final UserModel user;

  const _UserDetailsSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // User info
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile picture and name
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.talowaGreen.withOpacity(0.2),
                  backgroundImage: user.profileImageUrl != null 
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: user.profileImageUrl == null
                      ? Text(
                          _getInitials(user.fullName),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.talowaGreen,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'NotoSansTelugu',
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.talowaGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    user.role,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.talowaGreen,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // User details
                _buildDetailRow(Icons.phone, 'Phone', user.phoneNumber),
                _buildDetailRow(Icons.location_on, 'Location', 
                    '${user.address.villageCity}, ${user.address.mandal}, ${user.address.district}'),
                _buildDetailRow(Icons.badge, 'Member ID', user.memberId),
                if (user.directReferrals > 0)
                  _buildDetailRow(Icons.people, 'Direct Referrals', '${user.directReferrals}'),
                if (user.teamSize > 0)
                  _buildDetailRow(Icons.group, 'Team Size', '${user.teamSize}'),
                
                const SizedBox(height: 24),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.talowaGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final names = name.trim().split(' ');
    if (names.isEmpty) return 'U';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }
}