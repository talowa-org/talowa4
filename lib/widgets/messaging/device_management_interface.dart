// Device Management Interface for TALOWA
// Implements Task 9: Cross-device compatibility and data synchronization - Device Management UI
// Reference: in-app-communication/requirements.md - Requirements 8.1, 8.6

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/messaging/device_session_manager.dart';
import '../../services/messaging/cross_device_sync_service.dart';

class DeviceManagementInterface extends StatefulWidget {
  const DeviceManagementInterface({Key? key}) : super(key: key);

  @override
  State<DeviceManagementInterface> createState() => _DeviceManagementInterfaceState();
}

class _DeviceManagementInterfaceState extends State<DeviceManagementInterface> {
  final DeviceSessionManager _sessionManager = DeviceSessionManager();
  final CrossDeviceSyncService _syncService = CrossDeviceSyncService();
  
  List<DeviceSession> _sessions = [];
  SessionStatistics? _statistics;
  CrossDeviceSyncStatistics? _syncStatistics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
    _setupListeners();
  }

  Future<void> _loadDeviceData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final sessions = await _sessionManager.getUserSessions();
      final statistics = await _sessionManager.getSessionStatistics();
      final syncStatistics = await _syncService.getSyncStatistics();

      setState(() {
        _sessions = sessions;
        _statistics = statistics;
        _syncStatistics = syncStatistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setupListeners() {
    // Listen to session events
    _sessionManager.sessionEventsStream.listen((event) {
      switch (event.type) {
        case SessionEventType.sessionCreated:
        case SessionEventType.sessionTerminated:
        case SessionEventType.newSessionDetected:
          _loadDeviceData();
          break;
        default:
          break;
      }
    });

    // Listen to device sessions stream
    _sessionManager.deviceSessionsStream.listen((sessions) {
      setState(() {
        _sessions = sessions;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeviceData,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'terminate_all',
                child: Text('Sign out all other devices'),
              ),
              const PopupMenuItem(
                value: 'secure_logout',
                child: Text('Secure logout'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading device data',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDeviceData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDeviceData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatisticsCard(),
            const SizedBox(height: 16),
            _buildSyncStatusCard(),
            const SizedBox(height: 16),
            _buildDevicesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Active Devices',
                    _statistics!.activeSessions.toString(),
                    Icons.devices,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Sessions',
                    _statistics!.totalSessions.toString(),
                    Icons.history,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Recent Activity',
                    _statistics!.recentSessions.toString(),
                    Icons.access_time,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Current Device',
                    _statistics!.currentSession?.deviceName ?? 'Unknown',
                    Icons.smartphone,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    if (_syncStatistics == null) return const SizedBox.shrink();

    final isHealthy = _syncStatistics!.isHealthy;
    final statusColor = isHealthy ? Colors.green : Colors.orange;
    final statusIcon = isHealthy ? Icons.check_circle : Icons.warning;
    final statusText = isHealthy ? 'All synced' : 'Sync issues detected';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Sync Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Synced Conversations',
                    '${_syncStatistics!.syncedConversations}/${_syncStatistics!.totalConversations}',
                    Icons.sync,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Conflicts',
                    _syncStatistics!.unresolvedConflicts.toString(),
                    Icons.error_outline,
                    _syncStatistics!.hasUnresolvedConflicts ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            if (_syncStatistics!.lastSyncTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last sync: ${_formatDateTime(_syncStatistics!.lastSyncTime!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDevicesList() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Active Devices',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  '${_sessions.length} devices',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No active devices found'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sessions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = _sessions[index];
                return _buildDeviceItem(session);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(DeviceSession session) {
    final isCurrentDevice = session.id == _sessionManager.currentSession?.id;
    final deviceIcon = _getDeviceIcon(session.deviceType);
    final statusColor = session.isCurrentDevice ? Colors.green : Colors.grey;

    return ListTile(
      leading: Stack(
        children: [
          Icon(deviceIcon, size: 32),
          if (isCurrentDevice)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        session.displayName,
        style: TextStyle(
          fontWeight: isCurrentDevice ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last active: ${_formatDateTime(session.lastActiveAt)}'),
          if (session.location != null)
            Text('Location: ${session.location}'),
          if (isCurrentDevice)
            Text(
              'This device',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      trailing: isCurrentDevice
          ? null
          : PopupMenuButton<String>(
              onSelected: (action) => _handleDeviceAction(action, session),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'terminate',
                  child: Text('Sign out'),
                ),
                const PopupMenuItem(
                  value: 'details',
                  child: Text('View details'),
                ),
              ],
            ),
    );
  }

  IconData _getDeviceIcon(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.mobile:
        return Icons.smartphone;
      case DeviceType.tablet:
        return Icons.tablet;
      case DeviceType.desktop:
        return Icons.computer;
      case DeviceType.web:
        return Icons.web;
      default:
        return Icons.device_unknown;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'terminate_all':
        await _showTerminateAllDialog();
        break;
      case 'secure_logout':
        await _showSecureLogoutDialog();
        break;
    }
  }

  Future<void> _handleDeviceAction(String action, DeviceSession session) async {
    switch (action) {
      case 'terminate':
        await _showTerminateDeviceDialog(session);
        break;
      case 'details':
        await _showDeviceDetailsDialog(session);
        break;
    }
  }

  Future<void> _showTerminateAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out all other devices'),
        content: const Text(
          'This will sign you out from all other devices. You will need to sign in again on those devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out all'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _sessionManager.terminateAllOtherSessions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully signed out from all other devices'),
            ),
          );
        }
        await _loadDeviceData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showSecureLogoutDialog() async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => _SecureLogoutDialog(),
    );

    if (result != null) {
      try {
        await _sessionManager.performSecureLogout(
          terminateAllSessions: result['terminateAll'] ?? false,
          clearLocalData: result['clearData'] ?? true,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Secure logout completed'),
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during logout: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showTerminateDeviceDialog(DeviceSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out device'),
        content: Text(
          'Sign out from "${session.displayName}"? The user will need to sign in again on that device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _sessionManager.terminateSession(session.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed out from ${session.displayName}'),
            ),
          );
        }
        await _loadDeviceData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeviceDetailsDialog(DeviceSession session) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(session.displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Device Type', session.deviceType.name),
              _buildDetailRow('Platform', session.platform),
              _buildDetailRow('App Version', session.appVersion),
              _buildDetailRow('Created', _formatDateTime(session.createdAt)),
              _buildDetailRow('Last Active', _formatDateTime(session.lastActiveAt)),
              if (session.ipAddress != null)
                _buildDetailRow('IP Address', session.ipAddress!),
              if (session.location != null)
                _buildDetailRow('Location', session.location!),
              if (session.metadata.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Additional Info',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...session.metadata.entries.map(
                  (entry) => _buildDetailRow(entry.key, entry.value.toString()),
                ),
              ],
            ],
          ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _SecureLogoutDialog extends StatefulWidget {
  @override
  State<_SecureLogoutDialog> createState() => _SecureLogoutDialogState();
}

class _SecureLogoutDialogState extends State<_SecureLogoutDialog> {
  bool _terminateAll = false;
  bool _clearData = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Secure Logout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose your logout options:',
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Sign out from all devices'),
            subtitle: const Text('Terminate all active sessions'),
            value: _terminateAll,
            onChanged: (value) {
              setState(() {
                _terminateAll = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Clear local data'),
            subtitle: const Text('Remove all cached messages and settings'),
            value: _clearData,
            onChanged: (value) {
              setState(() {
                _clearData = value ?? true;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop({
            'terminateAll': _terminateAll,
            'clearData': _clearData,
          }),
          child: const Text('Logout'),
        ),
      ],
    );
  }
}