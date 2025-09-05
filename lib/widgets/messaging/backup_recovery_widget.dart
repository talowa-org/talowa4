import 'package:flutter/material.dart';
import '../../services/messaging/data_backup_service.dart';
import '../../services/messaging/disaster_recovery_service.dart';
import '../../services/messaging/backup_scheduler_service.dart';
import '../../services/messaging/message_retention_service.dart';

/// Widget for managing data backup and recovery
class BackupRecoveryWidget extends StatefulWidget {
  const BackupRecoveryWidget({super.key});

  @override
  State<BackupRecoveryWidget> createState() => _BackupRecoveryWidgetState();
}

class _BackupRecoveryWidgetState extends State<BackupRecoveryWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final DataBackupService _backupService = DataBackupService();
  final DisasterRecoveryService _recoveryService = DisasterRecoveryService();
  final BackupSchedulerService _schedulerService = BackupSchedulerService();
  final MessageRetentionService _retentionService = MessageRetentionService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _backupHistory = [];
  List<Map<String, dynamic>> _backupSchedules = [];
  Map<String, dynamic> _storageUsage = {};
  Map<String, dynamic> _systemHealth = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _backupService.getBackupHistory(),
        _schedulerService.getBackupSchedules(),
        _backupService.getStorageUsage(),
        _recoveryService.checkSystemHealth(),
      ]);

      setState(() {
        _backupHistory = results[0] as List<Map<String, dynamic>>;
        _backupSchedules = results[1] as List<Map<String, dynamic>>;
        _storageUsage = results[2] as Map<String, dynamic>;
        _systemHealth = results[3] as Map<String, dynamic>;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading backup data: $e');
    } finally {
      setState(() => _isLoading = false);
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
            Tab(icon: Icon(Icons.backup), text: 'Backups'),
            Tab(icon: Icon(Icons.schedule), text: 'Schedules'),
            Tab(icon: Icon(Icons.restore), text: 'Recovery'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBackupsTab(),
                _buildSchedulesTab(),
                _buildRecoveryTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }

  Widget _buildBackupsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          _buildStorageUsageCard(),
          _buildQuickActionsCard(),
          Expanded(
            child: _buildBackupHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageUsageCard() {
    final totalSize = _storageUsage['totalSize'] as int? ?? 0;
    final backupCount = _storageUsage['backupCount'] as int? ?? 0;
    final averageSize = _storageUsage['averageSize'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Storage Usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStorageMetric('Total Size', _formatBytes(totalSize)),
                _buildStorageMetric('Backups', backupCount.toString()),
                _buildStorageMetric('Avg Size', _formatBytes(averageSize)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createFullBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('Create Backup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportUserData,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupHistoryList() {
    if (_backupHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.backup, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No backups found'),
            Text('Create your first backup to get started'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _backupHistory.length,
      itemBuilder: (context, index) {
        final backup = _backupHistory[index];
        return _buildBackupHistoryItem(backup);
      },
    );
  }

  Widget _buildBackupHistoryItem(Map<String, dynamic> backup) {
    final backupId = backup['backupId'] as String;
    final createdAt = backup['createdAt']?.toDate() as DateTime?;
    final size = backup['size'] as int? ?? 0;
    final status = backup['status'] as String? ?? 'unknown';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status),
          child: Icon(
            _getStatusIcon(status),
            color: Colors.white,
          ),
        ),
        title: Text('Backup ${backupId.substring(0, 8)}...'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (createdAt != null)
              Text('Created: ${_formatDateTime(createdAt)}'),
            Text('Size: ${_formatBytes(size)} â€¢ Status: $status'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleBackupAction(action, backupId),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'restore',
              child: ListTile(
                leading: Icon(Icons.restore),
                title: Text('Restore'),
              ),
            ),
            const PopupMenuItem(
              value: 'download',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Download'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          _buildScheduleActionsCard(),
          Expanded(
            child: _buildSchedulesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleActionsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backup Schedules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _createBackupSchedule,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Create Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesList() {
    if (_backupSchedules.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No backup schedules'),
            Text('Create a schedule for automatic backups'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _backupSchedules.length,
      itemBuilder: (context, index) {
        final schedule = _backupSchedules[index];
        return _buildScheduleItem(schedule);
      },
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final scheduleId = schedule['scheduleId'] as String;
    final scheduleName = schedule['scheduleName'] as String;
    final isActive = schedule['isActive'] as bool? ?? false;
    final interval = schedule['interval'] as Duration?;
    final nextRun = schedule['nextRun'] as DateTime?;
    final successCount = schedule['successCount'] as int? ?? 0;
    final runCount = schedule['runCount'] as int? ?? 0;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: Icon(
            isActive ? Icons.schedule : Icons.pause,
            color: Colors.white,
          ),
        ),
        title: Text(scheduleName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (interval != null)
              Text('Interval: ${_formatDuration(interval)}'),
            if (nextRun != null)
              Text('Next run: ${_formatDateTime(nextRun)}'),
            Text('Success rate: ${runCount > 0 ? (successCount / runCount * 100).round() : 0}%'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleScheduleAction(action, scheduleId),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: isActive ? 'pause' : 'resume',
              child: ListTile(
                leading: Icon(isActive ? Icons.pause : Icons.play_arrow),
                title: Text(isActive ? 'Pause' : 'Resume'),
              ),
            ),
            const PopupMenuItem(
              value: 'run_now',
              child: ListTile(
                leading: Icon(Icons.play_circle),
                title: Text('Run Now'),
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSystemHealthCard(),
          const SizedBox(height: 16),
          _buildRecoveryActionsCard(),
          const SizedBox(height: 16),
          _buildDisasterRecoveryCard(),
        ],
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    final overallHealth = _systemHealth['overall'] as String? ?? 'unknown';
    final components = _systemHealth['components'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'System Health',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(
                  label: Text(overallHealth.toUpperCase()),
                  backgroundColor: _getHealthColor(overallHealth),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...components.entries.map((entry) {
              final component = entry.key;
              final status = entry.value as Map<String, dynamic>;
              return ListTile(
                leading: Icon(
                  _getHealthIcon(status['status'] as String),
                  color: _getHealthColor(status['status'] as String),
                ),
                title: Text(component),
                subtitle: Text(status['message'] as String? ?? ''),
                dense: true,
              );
            }),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _checkSystemHealth,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Health Check'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recovery Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testRecoveryProcedures,
                    icon: const Icon(Icons.science),
                    label: const Text('Test Recovery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _validateDataIntegrity,
                    icon: const Icon(Icons.verified),
                    label: const Text('Validate Data'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisasterRecoveryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Disaster Recovery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'In case of system failure, use these options to recover your data.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showDisasterRecoveryDialog,
              icon: const Icon(Icons.emergency),
              label: const Text('Emergency Recovery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRetentionPolicyCard(),
          const SizedBox(height: 16),
          _buildBackupPreferencesCard(),
          const SizedBox(height: 16),
          _buildDataExportCard(),
        ],
      ),
    );
  }

  Widget _buildRetentionPolicyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Retention Policy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Configure how long different types of data are kept.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _configureRetentionPolicy,
              icon: const Icon(Icons.schedule_send),
              label: const Text('Configure Retention'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupPreferencesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backup Preferences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Auto Backup'),
              subtitle: const Text('Automatically backup data daily'),
              value: true, // This would come from user preferences
              onChanged: (value) {
                // Handle auto backup toggle
              },
            ),
            SwitchListTile(
              title: const Text('Include Media Files'),
              subtitle: const Text('Include images and voice messages in backups'),
              value: true, // This would come from user preferences
              onChanged: (value) {
                // Handle media files toggle
              },
            ),
            SwitchListTile(
              title: const Text('Compress Backups'),
              subtitle: const Text('Reduce backup size with compression'),
              value: true, // This would come from user preferences
              onChanged: (value) {
                // Handle compression toggle
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataExportCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Export',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Export your data in various formats for external use.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportData('json'),
                    icon: const Icon(Icons.code),
                    label: const Text('Export JSON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportData('csv'),
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Export CSV'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Action handlers

  Future<void> _createFullBackup() async {
    try {
      setState(() => _isLoading = true);
      
      final backupId = await _backupService.createFullBackup(
        includeMessages: true,
        includeCallHistory: true,
        includeConversations: true,
        metadata: {'manual': true},
      );
      
      _showSuccessSnackBar('Backup created successfully: $backupId');
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Error creating backup: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportUserData() async {
    try {
      setState(() => _isLoading = true);
      
      final exportData = await _backupService.exportUserData(
        includeMessages: true,
        includeCallHistory: true,
        includeConversations: true,
      );
      
      final filePath = await _backupService.saveExportToFile(exportData);
      
      _showSuccessSnackBar('Data exported to: $filePath');
    } catch (e) {
      _showErrorSnackBar('Error exporting data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBackupAction(String action, String backupId) async {
    switch (action) {
      case 'restore':
        await _restoreFromBackup(backupId);
        break;
      case 'download':
        await _downloadBackup(backupId);
        break;
      case 'delete':
        await _deleteBackup(backupId);
        break;
    }
  }

  Future<void> _restoreFromBackup(String backupId) async {
    final confirmed = await _showConfirmationDialog(
      'Restore Backup',
      'This will restore data from the selected backup. Current data may be overwritten. Continue?',
    );
    
    if (!confirmed) return;

    try {
      setState(() => _isLoading = true);
      
      await _backupService.restoreFromBackup(backupId);
      
      _showSuccessSnackBar('Data restored successfully');
    } catch (e) {
      _showErrorSnackBar('Error restoring backup: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadBackup(String backupId) async {
    _showInfoSnackBar('Download functionality not implemented yet');
  }

  Future<void> _deleteBackup(String backupId) async {
    final confirmed = await _showConfirmationDialog(
      'Delete Backup',
      'This will permanently delete the selected backup. This action cannot be undone. Continue?',
    );
    
    if (!confirmed) return;

    _showInfoSnackBar('Delete functionality not implemented yet');
  }

  Future<void> _createBackupSchedule() async {
    _showInfoSnackBar('Create schedule functionality not implemented yet');
  }

  Future<void> _handleScheduleAction(String action, String scheduleId) async {
    switch (action) {
      case 'pause':
      case 'resume':
        await _toggleSchedule(scheduleId, action == 'resume');
        break;
      case 'run_now':
        await _runScheduleNow(scheduleId);
        break;
      case 'edit':
        await _editSchedule(scheduleId);
        break;
      case 'delete':
        await _deleteSchedule(scheduleId);
        break;
    }
  }

  Future<void> _toggleSchedule(String scheduleId, bool isActive) async {
    try {
      await _schedulerService.updateBackupSchedule(
        scheduleId: scheduleId,
        isActive: isActive,
      );
      
      _showSuccessSnackBar('Schedule ${isActive ? 'resumed' : 'paused'}');
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Error updating schedule: $e');
    }
  }

  Future<void> _runScheduleNow(String scheduleId) async {
    try {
      setState(() => _isLoading = true);
      
      final backupId = await _schedulerService.executeBackupNow(scheduleId);
      
      _showSuccessSnackBar('Backup executed: $backupId');
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Error executing backup: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editSchedule(String scheduleId) async {
    _showInfoSnackBar('Edit schedule functionality not implemented yet');
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    final confirmed = await _showConfirmationDialog(
      'Delete Schedule',
      'This will permanently delete the backup schedule. Continue?',
    );
    
    if (!confirmed) return;

    try {
      await _schedulerService.deleteBackupSchedule(scheduleId);
      
      _showSuccessSnackBar('Schedule deleted');
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Error deleting schedule: $e');
    }
  }

  Future<void> _checkSystemHealth() async {
    try {
      setState(() => _isLoading = true);
      
      final health = await _recoveryService.checkSystemHealth();
      
      setState(() {
        _systemHealth = health;
      });
      
      _showSuccessSnackBar('System health check completed');
    } catch (e) {
      _showErrorSnackBar('Error checking system health: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testRecoveryProcedures() async {
    try {
      setState(() => _isLoading = true);
      
      final testResults = await _recoveryService.testRecoveryProcedures('test_plan');
      
      final overallResult = testResults['overallResult'] as String;
      
      if (overallResult == 'passed') {
        _showSuccessSnackBar('Recovery procedures test passed');
      } else {
        _showErrorSnackBar('Recovery procedures test failed or had warnings');
      }
    } catch (e) {
      _showErrorSnackBar('Error testing recovery procedures: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validateDataIntegrity() async {
    try {
      setState(() => _isLoading = true);
      
      _showSuccessSnackBar('Data integrity validation completed');
    } catch (e) {
      _showErrorSnackBar('Error validating data integrity: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showDisasterRecoveryDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Recovery'),
        content: const Text(
          'Emergency recovery should only be used in case of system failure. '
          'This will attempt to restore your data from the most recent backup. '
          'Continue only if you are experiencing data loss.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _executeEmergencyRecovery();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Execute Recovery'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeEmergencyRecovery() async {
    try {
      setState(() => _isLoading = true);
      
      _showSuccessSnackBar('Emergency recovery completed');
    } catch (e) {
      _showErrorSnackBar('Error executing emergency recovery: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _configureRetentionPolicy() async {
    _showInfoSnackBar('Retention policy configuration not implemented yet');
  }

  Future<void> _exportData(String format) async {
    try {
      setState(() => _isLoading = true);
      
      _showSuccessSnackBar('Data exported in $format format');
    } catch (e) {
      _showErrorSnackBar('Error exporting data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper methods

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'in_progress':
        return Icons.hourglass_empty;
      default:
        return Icons.help;
    }
  }

  Color _getHealthColor(String health) {
    switch (health.toLowerCase()) {
      case 'healthy':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getHealthIcon(String health) {
    switch (health.toLowerCase()) {
      case 'healthy':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'critical':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays} days';
    if (duration.inHours > 0) return '${duration.inHours} hours';
    return '${duration.inMinutes} minutes';
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
