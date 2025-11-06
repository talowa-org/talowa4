// Presence Demo Screen for TALOWA Messaging System
// Requirements: 6.4 - Add status indicators throughout the UI

import 'package:flutter/material.dart';
import '../../models/messaging/presence_model.dart';
import '../../services/messaging/presence_service.dart';
import '../../widgets/messaging/presence_indicator.dart';
import '../../widgets/messaging/user_list_with_presence.dart';

/// Demo screen showcasing presence tracking features
class PresenceDemoScreen extends StatefulWidget {
  const PresenceDemoScreen({Key? key}) : super(key: key);

  @override
  State<PresenceDemoScreen> createState() => _PresenceDemoScreenState();
}

class _PresenceDemoScreenState extends State<PresenceDemoScreen>
    with SingleTickerProviderStateMixin {
  final PresenceService _presenceService = PresenceService();
  late TabController _tabController;
  
  PresenceStatus? _currentStatus;
  String? _currentStatusMessage;
  int _onlineUsersCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializePresenceService();
    _loadOnlineUsersCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializePresenceService() async {
    try {
      await _presenceService.initialize();
      debugPrint('✅ Presence service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing presence service: $e');
    }
  }

  Future<void> _loadOnlineUsersCount() async {
    try {
      final count = await _presenceService.getOnlineUsersCount();
      setState(() {
        _onlineUsersCount = count;
      });
    } catch (e) {
      debugPrint('Error loading online users count: $e');
    }
  }

  void _updateStatus(PresenceStatus? status, String? message) async {
    try {
      await _presenceService.updateCustomStatus(
        status: status,
        statusMessage: message,
      );
      
      setState(() {
        _currentStatus = status;
        _currentStatusMessage = message;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presence & Status'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Status', icon: Icon(Icons.person)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Demo', icon: Icon(Icons.science)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: OnlineUsersCountWidget(
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyStatusTab(),
          _buildUsersTab(),
          _buildDemoTab(),
        ],
      ),
    );
  }

  Widget _buildMyStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentStatus?.displayName ?? 'Available',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  if (_currentStatusMessage != null && _currentStatusMessage!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _currentStatusMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomStatusSelector(
                currentStatus: _currentStatus,
                currentMessage: _currentStatusMessage,
                onStatusChanged: _updateStatus,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Options',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ...PresenceStatus.values.map((status) => ListTile(
                    leading: Text(status.emoji, style: const TextStyle(fontSize: 20)),
                    title: Text(status.displayName),
                    subtitle: Text(_getStatusDescription(status)),
                    onTap: () => _updateStatus(status, null),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return UserListWithPresence(
      onUserTap: (user) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapped on ${user.fullName}')),
        );
      },
      showSearchBar: true,
      showOnlineFilter: true,
    );
  }

  Widget _buildDemoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Presence Indicators Demo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          // Different sized indicators
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Indicator Sizes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const PresenceIndicator(userId: 'demo1', size: 8),
                      const SizedBox(width: 8),
                      const Text('Small (8px)'),
                      const SizedBox(width: 24),
                      const PresenceIndicator(userId: 'demo1', size: 12),
                      const SizedBox(width: 8),
                      const Text('Medium (12px)'),
                      const SizedBox(width: 24),
                      const PresenceIndicator(userId: 'demo1', size: 16),
                      const SizedBox(width: 8),
                      const Text('Large (16px)'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Avatar with presence
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Avatar with Presence',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      UserAvatarWithPresence(
                        userId: 'demo1',
                        userName: 'John Doe',
                        radius: 20,
                      ),
                      SizedBox(width: 16),
                      UserAvatarWithPresence(
                        userId: 'demo2',
                        userName: 'Jane Smith',
                        radius: 25,
                      ),
                      SizedBox(width: 16),
                      UserAvatarWithPresence(
                        userId: 'demo3',
                        userName: 'Bob Wilson',
                        radius: 30,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Typing indicator demo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Typing Indicator',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const TypingIndicatorWidget(
                    conversationId: 'demo_conversation',
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _presenceService.sendTypingIndicator('demo_conversation', true);
                      Future.delayed(const Duration(seconds: 3), () {
                        _presenceService.sendTypingIndicator('demo_conversation', false);
                      });
                    },
                    child: const Text('Simulate Typing'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status display demo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Display Examples',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ...PresenceStatus.values.map((status) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Text(status.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(status.displayName),
                        const SizedBox(width: 16),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Presence Statistics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text('Online Users: $_onlineUsersCount'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadOnlineUsersCount,
                    child: const Text('Refresh Count'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.available:
        return 'Ready to receive messages and calls';
      case PresenceStatus.busy:
        return 'Currently busy, may not respond immediately';
      case PresenceStatus.away:
        return 'Away from device, will respond later';
      case PresenceStatus.doNotDisturb:
        return 'Do not disturb, only urgent messages';
      case PresenceStatus.invisible:
        return 'Appear offline to others';
    }
  }

  Color _getStatusColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.available:
        return Colors.green;
      case PresenceStatus.busy:
        return Colors.red;
      case PresenceStatus.away:
        return Colors.orange;
      case PresenceStatus.doNotDisturb:
        return Colors.red.shade800;
      case PresenceStatus.invisible:
        return Colors.grey;
    }
  }
}