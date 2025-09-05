// Group List Screen for TALOWA Messaging System
// Reference: in-app-communication/requirements.md - Group Management

import 'package:flutter/material.dart';
import '../../models/messaging/group_model.dart';
import '../../services/messaging/group_service.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import 'group_detail_screen.dart';
import 'create_group_screen.dart';
import 'group_discovery_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final GroupService _groupService = GroupService();
  List<GroupModel> _groups = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final groups = await _groupService.getUserGroups();
      
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _searchGroups(String query) async {
    if (query.isEmpty) {
      _loadGroups();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final groups = await _groupService.searchGroups(query: query);
      
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<GroupModel> get _filteredGroups {
    if (_searchQuery.isEmpty) return _groups;
    
    return _groups.where((group) =>
        group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        group.description.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        backgroundColor: const Color(AppConstants.talowaGreenValue),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.explore),
            onPressed: () => _navigateToDiscovery(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateGroup(),
        backgroundColor: const Color(AppConstants.talowaGreenValue),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading groups...');
    }

    if (_error != null) {
      return ErrorDisplayWidget(
        error: _error!,
        onRetry: _loadGroups,
      );
    }

    if (_filteredGroups.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredGroups.length,
      itemBuilder: (context, index) {
        final group = _filteredGroups[index];
        return _buildGroupCard(group);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No groups found' : 'No groups match your search',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty 
                ? 'Join or create groups to start collaborating'
                : 'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty) ...[
            ElevatedButton.icon(
              onPressed: () => _navigateToCreateGroup(),
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.talowaGreenValue),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _navigateToDiscovery(),
              icon: const Icon(Icons.explore),
              label: const Text('Discover Groups'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupCard(GroupModel group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _getGroupTypeColor(group.type),
          backgroundImage: group.avatarUrl != null 
              ? NetworkImage(group.avatarUrl!)
              : null,
          child: group.avatarUrl == null
              ? Icon(
                  _getGroupTypeIcon(group.type),
                  color: Colors.white,
                  size: 20,
                )
              : null,
        ),
        title: Text(
          group.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              group.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  '${group.memberCount} members',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    group.location.locationName,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getGroupTypeColor(group.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                group.type.displayName,
                style: TextStyle(
                  color: _getGroupTypeColor(group.type),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _navigateToGroupDetail(group),
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

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Groups'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter group name or description...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onSubmitted: (value) {
            Navigator.of(context).pop();
            _searchGroups(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _searchQuery = '';
              });
              _loadGroups();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _searchGroups(_searchQuery);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _navigateToGroupDetail(GroupModel group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(group: group),
      ),
    ).then((_) => _loadGroups());
  }

  void _navigateToCreateGroup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    ).then((_) => _loadGroups());
  }

  void _navigateToDiscovery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const GroupDiscoveryScreen(),
      ),
    ).then((_) => _loadGroups());
  }
}

