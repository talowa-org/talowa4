import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/messaging/backup_recovery_integration_service.dart';
import '../../services/messaging/data_backup_service.dart';
import '../../services/messaging/backup_scheduler_service.dart';
import '../../services/messaging/message_retention_service.dart';

/// Comprehensive dashboard for backup and recovery management
class BackupRecoveryDashboard extends StatefulWidget {
  const BackupRecoveryDashboard({super.key});

  @override
  State<BackupRecoveryDashboard> createState() => _BackupRecoveryDashboardState();
}

class _BackupRecoveryDashboardState extends State<BackupRecoveryDashboard>
    with TickerProviderStateMixin {
  final BackupRecoveryIntegrationService _integrationService = BackupRecoveryIntegrationService();
  final DataBackupService _backupService = DataBackupService();
  final BackupSchedulerService _schedulerService = BackupSchedulerService();
  final MessageRetentionService _retentionService = MessageRetentionService();

  late TabController _tabController;
  Map<String, dynamic>? _backupStatus;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBackupStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBackupStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final status = await _integrationService.getBackupStatus();
      
      setState(() {
        _backupStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Recovery'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.backup), text: 'Overview'),
            Tab(icon: Icon(Icons.schedule), text: 'Schedules'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackupStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildSchedulesTab(),
                    _buildSettingsTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading backup status', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBackupStatus,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_backupStatus == null) return const SizedBox();

    final systemHealth = _backupStatus!['systemHealth'] as Map<String, dynamic>? ?? {};
    final storageUsage = _backupStatus!['storageUsage'] as Map<String, dynamic>? ?? {};
    final recommendations = List<String>.from(_backupStatus!['recommendations'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Health Card
          _buildSystemHealthCard(systemHealth),
          const SizedBox(height: 16),

          // Storage Usage Card
          _buildStorageUsageCard(storageUsage),
          const SizedBox(height: 16),

          // Quick Actions Card
          _buildQuickActionsCard(),
          const SizedBox(height: 16),

          // Recommendations Card
          if (recommendations.isNotEmpty) _buildRecommendationsCard(recommendations),
        ],
      ),
    );
  }

  Widget _buildSystemHealthCard(Map<String, dynamic> systemHealth) {
    final overall = systemHealth['overall'] as String? ?? 'unknown';
    final components = systemHealth['components'] as Map<String, dynamic>? ?? {};

    Color healthColor;
    IconData healthIcon;
    switch (overall) {
      case 'healthy':
        healthColor = Colors.green;
        healthIcon = Icons.check_circle;
        break;
      case 'warning':
        healthColor = Colors.orange;
        healthIcon = Icons.warning;
        break;
      case 'critical':
        healthColor = Colors.red;
        healthIcon = Icons.error;
        break;
      default:
        healthColor = Colors.grey;
        healthIcon = Icons.help;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(healthIcon, color: healthColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'System Health',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Chip(
                  label: Text(overall.toUpperCase()),
                  backgroundColor: healthColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: healthColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...components.entries.map((entry) {
              final component = entry.key;
              final status = entry.value as Map<String, dynamic>;
              final componentStatus = status['status'] as String? ?? 'unknown';
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      componentStatus == 'healthy' ? Icons.check : Icons.warning,
                      color: componentStatus == 'healthy' ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(component.replaceAll('_', ' ').toUpperCase()),
                    const Spacer(),
                    Text(
                      componentStatus,
                      style: TextStyle(
                        color: componentStatus == 'healthy' ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageUsageCard(Map<String, dynamic> storageUsage) {
    final totalSize = storageUsage['totalSize'] as int? ?? 0;
    final backupCount = storageUsage['backupCount'] as int? ?? 0;
    final averageSize = storageUsage['averageSize'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Storage Usage',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStorageMetric(
                    'Total Size',
                    _formatBytes(totalSize),
                    Icons.folder_open,
                  ),
                ),
                Expanded(
                  child: _buildStorageMetric(
                    'Backups',
                    backupCount.toString(),
                    Icons.backup,
                  ),
                ),
                Expanded(
                  child: _buildStorageMetric(
                    'Avg Size',
                    _formatBytes(averageSize),
                    Icons.analytics,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createBackupNow,
                    icon: const Icon(Icons.backup),
                    label: const Text('Backup Now'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportData,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _performMaintenance,
                    icon: const Icon(Icons.build),
                    label: const Text('Maintenance'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testRecovery,
                    icon: const Icon(Icons.healing),
                    label: const Text('Test Recovery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(List<String> recommendations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Recommendations',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recommendations.map((recommendation) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(recommendation)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesTab() {
    final schedules = List<Map<String, dynamic>>.from(_backupStatus?['schedules'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Backup Schedules',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _createNewSchedule,
                icon: const Icon(Icons.add),
                label: const Text('New Schedule'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (schedules.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(Icons.schedule, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No backup schedules configured'),
                  Text('Create a schedule to automate your backups'),
                ],
              ),
            )
          else
            ...schedules.map((schedule) => _buildScheduleCard(schedule)).toList(),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final scheduleName = schedule['scheduleName'] as String? ?? 'Unnamed Schedule';
    final isActive = schedule['isActive'] as bool? ?? false;
    final interval = schedule['interval'] as Duration?;
    final nextRun = schedule['nextRun'] as DateTime?;
    final successCount = schedule['successCount'] as int? ?? 0;
    final runCount = schedule['runCount'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.schedule : Icons.schedule_outlined,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scheduleName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: (value) => _toggleSchedule(schedule['scheduleId'], value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (interval != null)
              Text('Interval: ${_formatDuration(interval)}'),
            if (nextRun != null)
              Text('Next run: ${_formatDateTime(nextRun)}'),
            Text('Success rate: ${runCount > 0 ? (successCount / runCount * 100).round() : 0}%'),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _runScheduleNow(schedule['scheduleId']),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Now'),
                ),
                TextButton.icon(
                  onPressed: () => _editSchedule(schedule),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteSchedule(schedule['scheduleId']),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    final retentionPolicy = _backupStatus?['retentionPolicy'] as Map<String, dynamic>? ?? {};
    final retentionPeriods = Map<String, int>.from(retentionPolicy['retentionPeriods'] ?? {});

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Retention Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Retention Periods',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ...retentionPeriods.entries.map((entry) {
                    return _buildRetentionSetting(entry.key, entry.value);
                  }).toList(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveRetentionSettings,
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionSetting(String dataType, int days) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(dataType.replaceAll('_', ' ').toUpperCase()),
          ),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: days.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                suffix: Text('days'),
                isDense: true,
              ),
              onChanged: (value) {
                // Update retention period
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final backupHistory = List<Map<String, dynamic>>.from(_backupStatus?['backupHistory'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (backupHistory.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No backup history available'),
                  Text('Create your first backup to see history'),
                ],
              ),
            )
          else
            ...backupHistory.map((backup) => _buildHistoryCard(backup)).toList(),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> backup) {
    final backupId = backup['backupId'] as String? ?? '';
    final createdAt = backup['createdAt'] as DateTime?;
    final size = backup['size'] as int? ?? 0;
    final status = backup['status'] as String? ?? 'unknown';

    return Card(
      child: ListTile(
        leading: Icon(
          status == 'completed' ? Icons.check_circle : Icons.error,
          color: status == 'completed' ? Colors.green : Colors.red,
        ),
        title: Text('Backup ${backupId.substring(0, 8)}...'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (createdAt != null) Text('Created: ${_formatDateTime(createdAt)}'),
            Text('Size: ${_formatBytes(size)}'),
            Text('Status: $status'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'restore',
              child: Text('Restore'),
            ),
            const PopupMenuItem(
              value: 'download',
              child: Text('Download'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) => _handleBackupAction(backupId, value as String),
        ),
      ),
    );
  }

  // Action methods

  Future<void> _createBackupNow() async {
    try {
      _showLoadingDialog('Creating backup...');
      
      final backupId = await _backupService.createFullBackup();
      
      Navigator.of(context).pop(); // Close loading dialog
      
      _showSuccessDialog('Backup created successfully!\nBackup ID: $backupId');
      _loadBackupStatus(); // Refresh status
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorDialog('Failed to create backup: $e');
    }
  }

  Future<void> _exportData() async {
    try {
      _showLoadingDialog('Exporting data...');
      
      final result = await _integrationService.performDataExport();
      
      Navigator.of(context).pop(); // Close loading dialog
      
      if (result['status'] == 'completed') {
        final files = List<Map<String, dynamic>>.from(result['files'] ?? []);
        _showExportSuccessDialog(files);
      } else {
        _showErrorDialog('Export failed: ${result['error']}');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorDialog('Failed to export data: $e');
    }
  }

  Future<void> _performMaintenance() async {
    try {
      _showLoadingDialog('Performing maintenance...');
      
      final result = await _integrationService.performSystemMaintenance();
      
      Navigator.of(context).pop(); // Close loading dialog
      
      _showMaintenanceResultDialog(result);
      _loadBackupStatus(); // Refresh status
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorDialog('Maintenance failed: $e');
    }
  }

  Future<void> _testRecovery() async {
    // Implementation for testing recovery procedures
    _showInfoDialog('Recovery test feature coming soon');
  }

  Future<void> _createNewSchedule() async {
    // Implementation for creating new backup schedule
    _showInfoDialog('Create schedule feature coming soon');
  }

  Future<void> _toggleSchedule(String scheduleId, bool isActive) async {
    try {
      await _schedulerService.updateBackupSchedule(
        scheduleId: scheduleId,
        isActive: isActive,
      );
      _loadBackupStatus(); // Refresh status
    } catch (e) {
      _showErrorDialog('Failed to update schedule: $e');
    }
  }

  Future<void> _runScheduleNow(String scheduleId) async {
    try {
      _showLoadingDialog('Running backup...');
      
      final backupId = await _schedulerService.executeBackupNow(scheduleId);
      
      Navigator.of(context).pop(); // Close loading dialog
      
      _showSuccessDialog('Backup completed!\nBackup ID: $backupId');
      _loadBackupStatus(); // Refresh status
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorDialog('Failed to run backup: $e');
    }
  }

  Future<void> _editSchedule(Map<String, dynamic> schedule) async {
    // Implementation for editing schedule
    _showInfoDialog('Edit schedule feature coming soon');
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    final confirmed = await _showConfirmDialog(
      'Delete Schedule',
      'Are you sure you want to delete this backup schedule?',
    );
    
    if (confirmed) {
      try {
        await _schedulerService.deleteBackupSchedule(scheduleId);
        _loadBackupStatus(); // Refresh status
        _showSuccessDialog('Schedule deleted successfully');
      } catch (e) {
        _showErrorDialog('Failed to delete schedule: $e');
      }
    }
  }

  Future<void> _saveRetentionSettings() async {
    // Implementation for saving retention settings
    _showInfoDialog('Save retention settings feature coming soon');
  }

  Future<void> _handleBackupAction(String backupId, String action) async {
    switch (action) {
      case 'restore':
        final confirmed = await _showConfirmDialog(
          'Restore Backup',
          'Are you sure you want to restore from this backup? This will overwrite your current data.',
        );
        if (confirmed) {
          try {
            _showLoadingDialog('Restoring backup...');
            await _backupService.restoreFromBackup(backupId);
            Navigator.of(context).pop(); // Close loading dialog
            _showSuccessDialog('Backup restored successfully');
          } catch (e) {
            Navigator.of(context).pop(); // Close loading dialog
            _showErrorDialog('Failed to restore backup: $e');
          }
        }
        break;
      case 'download':
        _showInfoDialog('Download backup feature coming soon');
        break;
      case 'delete':
        _showInfoDialog('Delete backup feature coming soon');
        break;
    }
  }

  // Dialog methods

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Information'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showExportSuccessDialog(List<Map<String, dynamic>> files) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your data has been exported successfully:'),
            const SizedBox(height: 8),
            ...files.map((file) {
              return Text('• ${file['type']}: ${_formatBytes(file['size'])}');
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceResultDialog(Map<String, dynamic> result) {
    final tasks = Map<String, dynamic>.from(result['tasks'] ?? {});
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maintenance Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Maintenance tasks completed:'),
            const SizedBox(height: 8),
            ...tasks.entries.map((entry) {
              final task = entry.key.replaceAll('_', ' ').toUpperCase();
              final taskResult = entry.value as Map<String, dynamic>;
              final status = taskResult['status'] as String;
              
              return Row(
                children: [
                  Icon(
                    status == 'completed' ? Icons.check : Icons.warning,
                    color: status == 'completed' ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task)),
                ],
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Utility methods

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays} days';
    if (duration.inHours > 0) return '${duration.inHours} hours';
    return '${duration.inMinutes} minutes';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}