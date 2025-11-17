// User List Widget with Presence Indicators
// Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 4.1, 4.2, 6.4

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/messaging/presence_model.dart';
import '../../services/messaging/user_list_service.dart';
import '../../services/messaging/presence_service.dart';
import 'presence_indicator.dart';

/// User list widget with integrated presence indicators
class UserListWithPresence extends StatefulWidget {
  final Function(UserModel)? onUserTap;
  final Function(UserModel)? onUserLongPress;
  final bool showSearchBar;
  final bool showOnlineFilter;
  final String? initialSearchQuery;
  final EdgeInsets? padding;
  final bool enablePullToRefresh;

  const UserListWithPresence({
    super.key,
    this.onUserTap,
    this.onUserLongPress,
    this.showSearchBar = true,
    this.showOnlineFilter = true,
    this.initialSearchQuery,
    this.padding,
    this.enablePullToRefresh = true,
  });

  @override
  State<UserListWithPresence> createState() => _UserListWithPresenceState();
}

class _UserListWithPresenceState extends State<UserListWithPresence> {
  final UserListService _userListService = UserListService();
  final PresenceService _presenceService = PresenceService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<UserModel> _users = [];
  Map<String, UserPresence> _presences = {};
  bool _isLoading = false;
  bool _hasMore = true;
  bool _showOnlineOnly = false;
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearchQuery ?? '';
    _searchQuery = widget.initialSearchQuery ?? '';
    
    _scrollController.addListener(_onScroll);
    _initializeServices();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      await _userListService.initialize();
      await _presenceService.initialize();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  Future<void> _loadUsers({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _error = null;
      }
    });

    try {
      UserListResult result;
      
      if (_searchQuery.isNotEmpty) {
        result = await _userListService.searchUsers(
          query: _searchQuery,
          loadMore: loadMore,
        );
      } else if (_showOnlineOnly) {
        result = await _userListService.getOnlineUsers();
      } else {
        result = await _userListService.getAllActiveUsers(
          loadMore: loadMore,
        );
      }

      if (result.isSuccess) {
        setState(() {
          if (loadMore) {
            _users.addAll(result.users);
          } else {
            _users = result.users;
          }
          _hasMore = result.hasMore;
        });

        // Load presence data for users
        await _loadPresenceData();
      } else {
        setState(() {
          _error = result.error;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPresenceData() async {
    if (_users.isEmpty) return;

    try {
      final userIds = _users.map((user) => user.id).toList();
      final presences = await _presenceService.getUserPresences(userIds);
      
      setState(() {
        _presences = presences;
      });

      // Subscribe to presence updates for visible users
      _subscribeToPresenceUpdates(userIds);
    } catch (e) {
      debugPrint('Error loading presence data: $e');
    }
  }

  void _subscribeToPresenceUpdates(List<String> userIds) {
    _presenceService.subscribeToMultiplePresences(
      userIds,
      (presences) {
        if (mounted) {
          setState(() {
            _presences.addAll(presences);
          });
        }
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _loadUsers(loadMore: true);
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    
    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == query && mounted) {
        _loadUsers();
      }
    });
  }

  void _toggleOnlineFilter() {
    setState(() {
      _showOnlineOnly = !_showOnlineOnly;
    });
    _loadUsers();
  }

  Future<void> _onRefresh() async {
    _userListService.clearCache();
    _presenceService.clearCache();
    await _loadUsers();
  }

  List<UserModel> get _filteredUsers {
    if (!_showOnlineOnly) return _users;
    
    return _users.where((user) {
      final presence = _presences[user.id];
      return presence?.isOnline ?? false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showSearchBar) _buildSearchBar(),
        if (widget.showOnlineFilter) _buildFilterBar(),
        Expanded(child: _buildUserList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search users...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: _showOnlineOnly ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                const Text('Online only'),
              ],
            ),
            selected: _showOnlineOnly,
            onSelected: (_) => _toggleOnlineFilter(),
          ),
          const Spacer(),
          OnlineUsersCountWidget(
            textStyle: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_users.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return _buildEmptyWidget();
    }

    final filteredUsers = _filteredUsers;

    Widget listView = ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: filteredUsers.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= filteredUsers.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = filteredUsers[index];
        final presence = _presences[user.id];

        return _buildUserTile(user, presence);
      },
    );

    if (widget.enablePullToRefresh) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildUserTile(UserModel user, UserPresence? presence) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: UserAvatarWithPresence(
          userId: user.id,
          userName: user.fullName,
          showPresence: true,
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.role} • ${user.address.villageCity}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            PresenceStatusWidget(
              userId: user.id,
              showStatusMessage: true,
              textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: _buildUserActions(user, presence),
        onTap: () => widget.onUserTap?.call(user),
        onLongPress: () => widget.onUserLongPress?.call(user),
      ),
    );
  }

  Widget _buildUserActions(UserModel user, UserPresence? presence) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (presence?.isAvailable ?? false)
          IconButton(
            icon: const Icon(Icons.message, size: 20),
            onPressed: () => _startConversation(user),
            tooltip: 'Send message',
          ),
        if (presence?.isAvailable ?? false)
          IconButton(
            icon: const Icon(Icons.call, size: 20),
            onPressed: () => _startCall(user),
            tooltip: 'Start call',
          ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading users',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadUsers(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No users found'
                  : _showOnlineOnly
                      ? 'No users online'
                      : 'No users available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms'
                  : _showOnlineOnly
                      ? 'No users are currently online'
                      : 'Check your internet connection',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _startConversation(UserModel user) {
    debugPrint('Starting conversation with ${user.fullName}');
    widget.onUserTap?.call(user);
  }

  void _startCall(UserModel user) {
    debugPrint('Starting call with ${user.fullName}');
  }
}