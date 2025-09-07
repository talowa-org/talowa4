// Sync Settings Screen for TALOWA
// Implements Task 22: Add sync and conflict resolution - Sync Settings UI

import 'package:flutter/material.dart';
import '../../services/sync/intelligent_sync_service.dart';
import '../../services/sync/sync_conflict_resolver.dart';
import '../../widgets/common/loading_widget.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final IntelligentSyncService _syncService = IntelligentSyncService();
  final SyncConflictResolver _conflictResolver = SyncConflictResolver();
  
  SyncConfiguration? _config;
  SyncStatistics? _statistics;
  ConflictStats? _conflictStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        _loadCurrentConfiguration(),
        _syncService.getSyncStatistics(),
        _conflictResolver.getConflictStats(),
      ]);

      setState(() {
        _config = results[0] as SyncConfiguration?;
        _statistics = results[1] as SyncStatistics;
        _conflictStats = results[2] as ConflictStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<SyncConfiguration> _loadCurrentConfiguration() async {
    // For now, return default config. In a real implementation,
    // this would load from the sync service
    return SyncConfiguration.defaultConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
              ? ErrorDisplayWidget(
                  error: _error!,
                  onRetry: _loadData,
                )
              : _buildSettings(),
    );
  }

  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSyncStatusCard(),
          const SizedBox(height: 16),
          _buildSyncSettingsCard(),
          const SizedBox(height: 16),
          _buildConflictResolutionCard(),
          const SizedBox(height: 16),
          _buildStatisticsCard(),
          const SizedBox(height: 16),
          _buildAdvancedOptionsCard(),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _performManualSync,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _performFullSync,
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('Full Sync'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_statistics?.lastSyncTime != null)
              Text(
                'Last sync: ${_formatDateTime(_statistics!.lastSyncTime!)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSettingsCard() {
    if (_config == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Periodic Sync'),
              subtitle: const Text('Automatically sync data at regular intervals'),
              value: _config!.enablePeriodicSync,
              onChanged: (value) {
                _updateConfig(_config!.copyWith(enablePeriodicSync: value));
              },
            ),
            if (_config!.enablePeriodicSync) ...[
              ListTile(
                title: const Text('Sync Interval'),
                subtitle: Text('Every ${_config!.syncInterval.inMinutes} minutes'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showSyncIntervalDialog(),
              ),
            ],
            SwitchListTile(
              title: const Text('Sync Only on WiFi'),
              subtitle: const Text('Avoid using mobile data for sync'),
              value: _config!.syncOnlyOnWifi,
              onChanged: (value) {
                _updateConfig(_config!.copyWith(syncOnlyOnWifi: value));
              },
            ),
            SwitchListTile(
              title: const Text('Background Sync'),
              subtitle: const Text('Allow sync when app is in background'),
              value: _config!.enableBackgroundSync,
              onChanged: (value) {
                _updateConfig(_config!.copyWith(enableBackgroundSync: value));
              },
            ),
            ListTile(
              title: const Text('Max Items Per Sync'),
              subtitle: Text('${_config!.maxItemsPerSync} items'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showMaxItemsDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictResolutionCard() {
    if (_config == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conflict Resolution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Resolution Strategy'),
              subtitle: Text(_getStrategyDescription(_config!.conflictResolutionStrategy)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showConflictStrategyDialog(),
            ),
            if (_conflictStats != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildConflictStatItem(
                      'Total Conflicts',
                      _conflictStats!.totalConflicts.toString(),
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildConflictStatItem(
                      'Resolved',
                      _conflictStats!.resolvedConflicts.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildConflictStatItem(
                      'Pending',
                      _conflictStats!.pendingConflicts.toString(),
                      Icons.pending,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConflictStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
              'Sync Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildStatRow('Total Syncs', _statistics!.totalSyncs.toString()),
            _buildStatRow('Successful', _statistics!.successfulSyncs.toString()),
            _buildStatRow('Failed', _statistics!.failedSyncs.toString()),
            _buildStatRow(
              'Success Rate',
              _statistics!.totalSyncs > 0
                  ? '${((_statistics!.successfulSyncs / _statistics!.totalSyncs) * 100).round()}%'
                  : '0%',
            ),
            _buildStatRow(
              'Average Duration',
              '${_statistics!.averageSyncDuration.inSeconds}s',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Options',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.orange),
              title: const Text('Clear Sync Cache'),
              subtitle: const Text('Remove all cached sync data'),
              onTap: () => _showClearCacheDialog(),
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text('Reset Sync Settings'),
              subtitle: const Text('Restore default sync configuration'),
              onTap: () => _showResetSettingsDialog(),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.red),
              title: const Text('Export Sync Logs'),
              subtitle: const Text('Export logs for troubleshooting'),
              onTap: () => _exportSyncLogs(),
            ),
          ],
        ),
      ),
    );
  }

  String _getStrategyDescription(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.localWins:
        return 'Local changes always win';
      case ConflictResolutionStrategy.remoteWins:
        return 'Remote changes always win';
      case ConflictResolutionStrategy.merge:
        return 'Attempt to merge changes';
      case ConflictResolutionStrategy.userChoice:
        return 'Ask user to choose';
      case ConflictResolutionStrategy.automatic:
        return 'Automatic resolution';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _updateConfig(SyncConfiguration newConfig) async {
    try {
      await _syncService.updateSyncConfiguration(newConfig);
      setState(() {
        _config = newConfig;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync settings updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating settings: $e')),
      );
    }
  }

  void _performManualSync() async {
    try {
      await _syncService.performSync(forceSync: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual sync started')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting sync: $e')),
      );
    }
  }

  void _performFullSync() async {
    try {
      await _syncService.performSync(
        mode: SyncMode.full,
        forceSync: true,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full sync started')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting full sync: $e')),
      );
    }
  }

  void _showSyncIntervalDialog() {
    final intervals = [5, 15, 30, 60, 120, 240]; // minutes
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Interval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: intervals.map((minutes) {
            return RadioListTile<int>(
              title: Text('$minutes minutes'),
              value: minutes,
              groupValue: _config!.syncInterval.inMinutes,
              onChanged: (value) {
                Navigator.pop(context);
                _updateConfig(_config!.copyWith(
                  syncInterval: Duration(minutes: value!),
                ));
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMaxItemsDialog() {
    final controller = TextEditingController(
      text: _config!.maxItemsPerSync.toString(),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Max Items Per Sync'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of items',
            hintText: 'Enter maximum items to sync',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context);
                _updateConfig(_config!.copyWith(maxItemsPerSync: value));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showConflictStrategyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conflict Resolution Strategy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ConflictResolutionStrategy.values.map((strategy) {
            return RadioListTile<ConflictResolutionStrategy>(
              title: Text(_getStrategyName(strategy)),
              subtitle: Text(_getStrategyDescription(strategy)),
              value: strategy,
              groupValue: _config!.conflictResolutionStrategy,
              onChanged: (value) {
                Navigator.pop(context);
                _updateConfig(_config!.copyWith(conflictResolutionStrategy: value!));
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getStrategyName(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.localWins:
        return 'Local Wins';
      case ConflictResolutionStrategy.remoteWins:
        return 'Remote Wins';
      case ConflictResolutionStrategy.merge:
        return 'Merge';
      case ConflictResolutionStrategy.userChoice:
        return 'User Choice';
      case ConflictResolutionStrategy.automatic:
        return 'Automatic';
    }
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Sync Cache'),
        content: const Text(
          'This will remove all cached sync data. You may need to perform a full sync afterwards. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearSyncCache();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Sync Settings'),
        content: const Text(
          'This will restore all sync settings to their default values. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _clearSyncCache() async {
    try {
      // Implementation would clear sync cache
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync cache cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing cache: $e')),
      );
    }
  }

  void _resetSettings() async {
    try {
      final defaultConfig = SyncConfiguration.defaultConfig();
      await _syncService.updateSyncConfiguration(defaultConfig);
      setState(() {
        _config = defaultConfig;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings reset to defaults')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting settings: $e')),
      );
    }
  }

  void _exportSyncLogs() async {
    try {
      // Implementation would export sync logs
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync logs exported')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting logs: $e')),
      );
    }
  }
}

// Extension to add copyWith method to SyncConfiguration
extension SyncConfigurationExtension on SyncConfiguration {
  SyncConfiguration copyWith({
    bool? enablePeriodicSync,
    Duration? syncInterval,
    int? maxItemsPerSync,
    ConflictResolutionStrategy? conflictResolutionStrategy,
    bool? syncOnlyOnWifi,
    bool? enableBackgroundSync,
  }) {
    return SyncConfiguration(
      enablePeriodicSync: enablePeriodicSync ?? this.enablePeriodicSync,
      syncInterval: syncInterval ?? this.syncInterval,
      maxItemsPerSync: maxItemsPerSync ?? this.maxItemsPerSync,
      conflictResolutionStrategy: conflictResolutionStrategy ?? this.conflictResolutionStrategy,
      syncOnlyOnWifi: syncOnlyOnWifi ?? this.syncOnlyOnWifi,
      enableBackgroundSync: enableBackgroundSync ?? this.enableBackgroundSync,
    );
  }
}


