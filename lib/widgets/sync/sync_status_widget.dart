// Sync Status Widget for TALOWA
// Implements Task 22: Add sync and conflict resolution - Sync Status UI

import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/sync/intelligent_sync_service.dart';

class SyncStatusWidget extends StatefulWidget {
  final bool showDetails;
  final VoidCallback? onTap;

  const SyncStatusWidget({
    super.key,
    this.showDetails = false,
    this.onTap,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget>
    with SingleTickerProviderStateMixin {
  final IntelligentSyncService _syncService = IntelligentSyncService();
  
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  
  StreamSubscription<SyncStatus>? _statusSubscription;
  StreamSubscription<SyncProgress>? _progressSubscription;
  
  SyncStatus _currentStatus = SyncStatus.idle;
  SyncProgress? _currentProgress;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    _initializeStreams();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _statusSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _initializeStreams() {
    _statusSubscription = _syncService.syncStatusStream.listen((status) {
      setState(() {
        _currentStatus = status;
      });
      
      if (status == SyncStatus.syncing) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    });

    _progressSubscription = _syncService.syncProgressStream.listen((progress) {
      setState(() {
        _currentProgress = progress;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showDetails) {
      return _buildDetailedStatus();
    } else {
      return _buildCompactStatus();
    }
  }

  Widget _buildCompactStatus() {
    return GestureDetector(
      onTap: widget.onTap ?? _showSyncDetails,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIcon(),
            const SizedBox(width: 4),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 12,
                color: _getStatusColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(),
                    ),
                  ),
                ),
                if (_currentStatus == SyncStatus.syncing)
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.red),
                    onPressed: _cancelSync,
                    tooltip: 'Cancel Sync',
                  ),
              ],
            ),
            if (_currentProgress != null) ...[
              const SizedBox(height: 12),
              _buildProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                _currentProgress!.message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (_currentStatus != SyncStatus.syncing) ...[
              const SizedBox(height: 12),
              _buildSyncActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData iconData;
    
    switch (_currentStatus) {
      case SyncStatus.idle:
        iconData = Icons.sync;
        break;
      case SyncStatus.syncing:
        iconData = Icons.sync;
        break;
      case SyncStatus.completed:
        iconData = Icons.check_circle;
        break;
      case SyncStatus.failed:
        iconData = Icons.error;
        break;
      case SyncStatus.cancelled:
        iconData = Icons.cancel;
        break;
    }

    Widget icon = Icon(
      iconData,
      size: 16,
      color: _getStatusColor(),
    );

    if (_currentStatus == SyncStatus.syncing) {
      return RotationTransition(
        turns: _rotationAnimation,
        child: icon,
      );
    }

    return icon;
  }

  Widget _buildProgressIndicator() {
    if (_currentProgress == null) return const SizedBox.shrink();

    return Column(
      children: [
        LinearProgressIndicator(
          value: _currentProgress!.progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getPhaseText(_currentProgress!.phase),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${(_currentProgress!.progress * 100).round()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncActions() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _manualSync,
          icon: const Icon(Icons.sync, size: 16),
          label: const Text('Sync Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _showSyncSettings,
          icon: const Icon(Icons.settings, size: 16),
          label: const Text('Settings'),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.cancelled:
        return Colors.orange;
    }
  }

  String _getStatusText() {
    switch (_currentStatus) {
      case SyncStatus.idle:
        return 'Ready to sync';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.completed:
        return 'Sync completed';
      case SyncStatus.failed:
        return 'Sync failed';
      case SyncStatus.cancelled:
        return 'Sync cancelled';
    }
  }

  String _getPhaseText(SyncPhase phase) {
    switch (phase) {
      case SyncPhase.analyzing:
        return 'Analyzing';
      case SyncPhase.uploading:
        return 'Uploading';
      case SyncPhase.downloading:
        return 'Downloading';
      case SyncPhase.resolving:
        return 'Resolving conflicts';
      case SyncPhase.finalizing:
        return 'Finalizing';
      case SyncPhase.completed:
        return 'Completed';
    }
  }

  void _showSyncDetails() {
    showDialog(
      context: context,
      builder: (context) => const SyncDetailsDialog(),
    );
  }

  void _manualSync() async {
    try {
      await _syncService.performSync(forceSync: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    }
  }

  void _cancelSync() async {
    await _syncService.cancelSync();
  }

  void _showSyncSettings() {
    Navigator.pushNamed(context, '/sync-settings');
  }
}

class SyncDetailsDialog extends StatefulWidget {
  const SyncDetailsDialog({super.key});

  @override
  State<SyncDetailsDialog> createState() => _SyncDetailsDialogState();
}

class _SyncDetailsDialogState extends State<SyncDetailsDialog> {
  final IntelligentSyncService _syncService = IntelligentSyncService();
  
  SyncStatistics? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _syncService.getSyncStatistics();
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Details'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildStatistics(),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _performFullSync,
          child: const Text('Full Sync'),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    if (_statistics == null) {
      return const Text('Unable to load sync statistics');
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatItem('Total Syncs', _statistics!.totalSyncs.toString()),
          _buildStatItem('Successful', _statistics!.successfulSyncs.toString()),
          _buildStatItem('Failed', _statistics!.failedSyncs.toString()),
          _buildStatItem('Total Conflicts', _statistics!.totalConflicts.toString()),
          _buildStatItem('Resolved Conflicts', _statistics!.resolvedConflicts.toString()),
          if (_statistics!.lastSyncTime != null)
            _buildStatItem('Last Sync', _formatDateTime(_statistics!.lastSyncTime!)),
          _buildStatItem(
            'Average Duration',
            '${_statistics!.averageSyncDuration.inSeconds}s',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
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

  void _performFullSync() async {
    Navigator.pop(context);
    
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
        SnackBar(content: Text('Failed to start sync: $e')),
      );
    }
  }
}

// Floating sync status indicator
class FloatingSyncStatus extends StatelessWidget {
  const FloatingSyncStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 16,
      child: const SyncStatusWidget(),
    );
  }
}

// Sync status app bar widget
class SyncStatusAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const SyncStatusAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        const SyncStatusWidget(),
        const SizedBox(width: 8),
        ...?actions,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}