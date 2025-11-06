// User List Widget for TALOWA Messaging System
// Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 4.1, 4.2
// Task: Build real user data display and user listing functionality

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/messaging/user_list_service.dart';
import '../../core/theme/app_theme.dart';

import '../common/loading_widget.dart';
import 'user_profile_tile.dart';

/// Widget for displaying user lists with search, filtering, and pagination
class UserListWidget extends StatefulWidget {
  final String? searchQuery;
  final String? roleFilter;
  final String? locationFilter;
  final Function(UserModel)? onUserTap;
  final Function(UserModel)? onUserLongPress;
  final bool showOnlineStatus;
  final bool enableSearch;
  final bool enablePagination;
  final int itemsPerPage;

  const UserListWidget({
    super.key,
    this.searchQuery,
    this.roleFilter,
    this.locationFilter,
    this.onUserTap,
    this.onUserLongPress,
    this.showOnlineStatus = true,
    this.enableSearch = true,
    this.enablePagination = true,
    this.itemsPerPage = 20,
  });

  @override
  State<UserListWidget> createState() => _UserListWidgetState();
}

class _UserListWidgetState extends State<UserListWidget> {
  final UserListService _userListService = UserListService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<UserModel> _users = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery ?? '';
    _currentSearchQuery = widget.searchQuery ?? '';
    _initializeService();
    _loadUsers();
    _setupScrollListener();
  }

  @override
  void didUpdateWidget(UserListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reload if filters changed
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.roleFilter != widget.roleFilter ||
        oldWidget.locationFilter != widget.locationFilter) {
      _searchController.text = widget.searchQuery ?? '';
      _currentSearchQuery = widget.searchQuery ?? '';
      _loadUsers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    await _userListService.initialize();
  }

  void _setupScrollListener() {
    if (!widget.enablePagination) return;
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreUsers();
      }
    });
  }

  Future<void> _loadUsers() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _users.clear();
      _hasMore = true;
    });

    try {
      UserListResult result;
      
      if (_currentSearchQuery.isNotEmpty) {
        result = await _userListService.searchUsers(
          query: _currentSearchQuery,
          role: widget.roleFilter,
          location: widget.locationFilter,
          limit: widget.itemsPerPage,
        );
      } else {
        result = await _userListService.getAllActiveUsers(
          limit: widget.itemsPerPage,
        );
      }

      if (mounted) {
        setState(() {
          _users = result.users;
          _hasMore = result.hasMore;
          _error = result.error;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      UserListResult result;
      
      if (_currentSearchQuery.isNotEmpty) {
        result = await _userListService.searchUsers(
          query: _currentSearchQuery,
          role: widget.roleFilter,
          location: widget.locationFilter,
          limit: widget.itemsPerPage,
          loadMore: true,
        );
      } else {
        result = await _userListService.getAllActiveUsers(
          limit: widget.itemsPerPage,
          loadMore: true,
        );
      }

      if (mounted) {
        setState(() {
          _users.addAll(result.users);
          _hasMore = result.hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_currentSearchQuery == query) return;
    
    setState(() {
      _currentSearchQuery = query;
    });
    
    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_currentSearchQuery == query && mounted) {
        _loadUsers();
      }
    });
  }

  Future<void> _refreshUsers() async {
    _userListService.clearCache();
    await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        if (widget.enableSearch) _buildSearchBar(),
        
        // User list
        Expanded(
          child: _buildUserList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search users by name, phone, or location...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildUserList() {
    if (_isLoading && _users.isEmpty) {
      return const LoadingWidget(message: 'Loading users...');
    }

    if (_error != null && _users.isEmpty) {
      return _buildErrorWidget();
    }

    if (_users.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshUsers,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _users.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return _buildLoadingMoreIndicator();
          }

          final user = _users[index];
          return UserProfileTile(
            user: user,
            showOnlineStatus: widget.showOnlineStatus,
            onTap: () => widget.onUserTap?.call(user),
            onLongPress: () => widget.onUserLongPress?.call(user),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load users',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUsers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _currentSearchQuery.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'No users found' : 'No users available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching 
                ? 'Try adjusting your search terms'
                : 'Users will appear here when they join the network',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (isSearching) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}