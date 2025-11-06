// User Selection Screen for TALOWA Messaging
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/messaging/integrated_messaging_service.dart';

class UserSelectionScreen extends StatefulWidget {
  final String title;
  final bool multiSelect;
  final Function(UserModel)? onUserSelected;
  final Function(List<UserModel>)? onUsersSelected;

  const UserSelectionScreen({
    super.key,
    required this.title,
    this.multiSelect = false,
    this.onUserSelected,
    this.onUsersSelected,
  });

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final IntegratedMessagingService _messagingService = IntegratedMessagingService();
  
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  List<UserModel> _selectedUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
      });
      _searchUsers(query);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredUsers = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _messagingService.searchUsers(query);
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching users: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleUserSelection(UserModel user) {
    setState(() {
      if (_selectedUsers.contains(user)) {
        _selectedUsers.remove(user);
      } else {
        if (widget.multiSelect) {
          _selectedUsers.add(user);
        } else {
          _selectedUsers = [user];
        }
      }
    });
  }

  void _handleSelection() {
    if (_selectedUsers.isEmpty) return;

    if (widget.multiSelect) {
      widget.onUsersSelected?.call(_selectedUsers);
    } else {
      widget.onUserSelected?.call(_selectedUsers.first);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _handleSelection,
              child: Text(
                widget.multiSelect 
                    ? 'Select (${_selectedUsers.length})'
                    : 'Select',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Selected users (for multi-select)
          if (widget.multiSelect && _selectedUsers.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected (${_selectedUsers.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.talowaGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _selectedUsers[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Chip(
                            avatar: CircleAvatar(
                              backgroundColor: AppTheme.talowaGreen,
                              child: Text(
                                user.fullName.isNotEmpty ? user.fullName[0] : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            label: Text(user.fullName),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _toggleUserSelection(user),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Users list
          Expanded(
            child: _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Search for users to start a conversation',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_search,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_searchQuery"',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching with a different name or phone number',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final isSelected = _selectedUsers.contains(user);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isSelected ? AppTheme.talowaGreen : Colors.grey[400],
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            user.fullName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text('${user.role} • ${user.phoneNumber}'),
          trailing: widget.multiSelect
              ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleUserSelection(user),
                  activeColor: AppTheme.talowaGreen,
                )
              : isSelected
                  ? const Icon(
                      Icons.check_circle,
                      color: AppTheme.talowaGreen,
                    )
                  : null,
          onTap: () {
            if (widget.multiSelect) {
              _toggleUserSelection(user);
            } else {
              _toggleUserSelection(user);
              _handleSelection();
            }
          },
        );
      },
    );
  }
}