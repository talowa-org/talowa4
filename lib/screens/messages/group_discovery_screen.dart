// Group Discovery Screen for TALOWA Messaging System
// Reference: in-app-communication/requirements.md - Geographic Group Discovery

import 'package:flutter/material.dart';
import '../../models/messaging/group_model.dart';
import '../../models/user_model.dart';
import '../../services/messaging/group_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import 'group_detail_screen.dart';

class GroupDiscoveryScreen extends StatefulWidget {
  const GroupDiscoveryScreen({super.key});

  @override
  State<GroupDiscoveryScreen> createState() => _GroupDiscoveryScreenState();
}

class _GroupDiscoveryScreenState extends State<GroupDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final GroupService _groupService = GroupService();
  final DatabaseService _databaseService = DatabaseService();
  
  late TabController _tabController;
  List<GroupModel> _discoveredGroups = [];
  List<GroupModel> _villageGroups = [];
  List<GroupModel> _mandalGroups = [];
  List<GroupModel> _districtGroups = [];
  
  bool _isLoading = true;
  String? _error;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        final userDoc = await _databaseService.getUser(currentUser.uid);
        if (userDoc != null) {
          setState(() {
            _currentUser = userDoc;
          });
          _discoverGroups();
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _discoverGroups() async {
    if (_currentUser == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Discover all groups
      final allGroups = await _groupService.discoverGroups();
      
      // Get groups by specific locations
      final villageGroups = await _groupService.getGroupsByLocation(
        GeographicScope(
          level: AppConstants.levelVillage,
          locationId: _currentUser!.address.villageCity,
          locationName: _currentUser!.address.villageCity,
        ),
      );

      final mandalGroups = await _groupService.getGroupsByLocation(
        GeographicScope(
          level: AppConstants.levelMandal,
          locationId: _currentUser!.address.mandal,
          locationName: _currentUser!.address.mandal,
        ),
      );

      final districtGroups = await _groupService.getGroupsByLocation(
        GeographicScope(
          level: AppConstants.levelDistrict,
          locationId: _currentUser!.address.district,
          locationName: _currentUser!.address.district,
        ),
      );

      setState(() {
        _discoveredGroups = allGroups;
        _villageGroups = villageGroups.where((g) => !g.isMember(_currentUser!.id)).toList();
        _mandalGroups = mandalGroups.where((g) => !g.isMember(_currentUser!.id)).toList();
        _districtGroups = districtGroups.where((g) => !g.isMember(_currentUser!.id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGroup(GroupModel group) async {
    try {
      await _groupService.addMember(
        groupId: group.id,
        userId: _currentUser!.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${group.name} successfully!'),
            backgroundColor: const Color(AppConstants.successGreenValue),
          ),
        );
        _discoverGroups(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining group: $e'),
            backgroundColor: const Color(AppConstants.emergencyRedValue),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Groups'),
        backgroundColor: const Color(AppConstants.talowaGreenValue),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Village'),
            Tab(text: 'Mandal'),
            Tab(text: 'District'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _discoverGroups,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Discovering groups...');
    }

    if (_error != null) {
      return ErrorDisplayWidget(
        error: _error!,
        onRetry: _discoverGroups,
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildGroupList(_discoveredGroups, 'No groups found in your area'),
        _buildGroupList(_villageGroups, 'No village groups found'),
        _buildGroupList(_mandalGroups, 'No mandal groups found'),
        _buildGroupList(_districtGroups, 'No district groups found'),
      ],
    );
  }

  Widget _buildGroupList(List<GroupModel> groups, String emptyMessage) {
    if (groups.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupCard(group);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.explore_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later or create your own group',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(GroupModel group) {
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getGroupTypeColor(group.type).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          group.type.displayName,
                          style: TextStyle(
                            color: _getGroupTypeColor(group.type),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildJoinButton(group),
              ],
            ),
            if (group.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                group.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
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
                    '${group.location.locationName} (${group.location.level})',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => _navigateToGroupDetail(group),
                  child: const Text('View Details'),
                ),
                if (group.settings.requireApprovalToJoin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Approval Required',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton(GroupModel group) {
    if (group.memberCount >= group.maxMembers) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Full',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _showJoinConfirmation(group),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(AppConstants.talowaGreenValue),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
      ),
      child: Text(
        group.settings.requireApprovalToJoin ? 'Request' : 'Join',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  void _showJoinConfirmation(GroupModel group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join ${group.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to join this group?'),
            const SizedBox(height: 8),
            if (group.settings.requireApprovalToJoin)
              const Text(
                'Note: This group requires approval from administrators.',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _joinGroup(group);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.talowaGreenValue),
            ),
            child: Text(group.settings.requireApprovalToJoin ? 'Request' : 'Join'),
          ),
        ],
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

  void _navigateToGroupDetail(GroupModel group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(group: group),
      ),
    ).then((_) => _discoverGroups());
  }
}

