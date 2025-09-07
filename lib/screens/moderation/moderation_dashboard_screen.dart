// Moderation Dashboard Screen for TALOWA Social Feed
// Implements Task 12: Create content moderation tools - Dashboard UI

import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/social_feed/content_moderation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/moderation/report_card_widget.dart';
import '../../widgets/moderation/moderation_stats_widget.dart';
import '../../widgets/moderation/bulk_actions_widget.dart';

class ModerationDashboardScreen extends StatefulWidget {
  const ModerationDashboardScreen({super.key});

  @override
  State<ModerationDashboardScreen> createState() => _ModerationDashboardScreenState();
}

class _ModerationDashboardScreenState extends State<ModerationDashboardScreen>
    with TickerProviderStateMixin {
  final ContentModerationService _moderationService = ContentModerationService();
  late TabController _tabController;
  
  StreamSubscription<List<ContentReport>>? _reportsSubscription;
  List<ContentReport> _pendingReports = [];
  List<ContentReport> _selectedReports = [];
  ModerationStats? _stats;
  bool _isLoading = true;
  bool _isBulkMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  void _loadData() {
    _loadPendingReports();
    _loadModerationStats();
  }

  void _loadPendingReports() {
    _reportsSubscription = _moderationService.getPendingReports()
        .listen((reports) {
      if (mounted) {
        setState(() {
          _pendingReports = reports;
          _isLoading = false;
        });
      }
    });
  }

  void _loadModerationStats() async {
    try {
      final stats = await _moderationService.getModerationStats();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      debugPrint('Error loading moderation stats: $e');
    }
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Moderation'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        actions: [
          if (_isBulkMode) ...[
            IconButton(
              onPressed: _selectedReports.isNotEmpty ? _showBulkActionsDialog : null,
              icon: const Icon(Icons.more_vert),
              tooltip: 'Bulk Actions',
            ),
            IconButton(
              onPressed: _exitBulkMode,
              icon: const Icon(Icons.close),
              tooltip: 'Exit Bulk Mode',
            ),
          ] else ...[
            IconButton(
              onPressed: _pendingReports.isNotEmpty ? _enterBulkMode : null,
              icon: const Icon(Icons.checklist),
              tooltip: 'Bulk Actions',
            ),
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Reports',
              icon: Badge(
                label: Text(_pendingReports.length.toString()),
                child: const Icon(Icons.report),
              ),
            ),
            const Tab(text: 'Posts', icon: Icon(Icons.article)),
            const Tab(text: 'Comments', icon: Icon(Icons.comment)),
            const Tab(text: 'Stats', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReportsTab(),
                _buildPostsTab(),
                _buildCommentsTab(),
                _buildStatsTab(),
              ],
            ),
    );
  }

  Widget _buildReportsTab() {
    if (_pendingReports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No pending reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'All reports have been reviewed',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_isBulkMode)
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.talowaGreen.withValues(alpha: 0.2),
            child: Row(
              children: [
                Text(
                  '${_selectedReports.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _selectAllReports,
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: _clearSelection,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _pendingReports.length,
            itemBuilder: (context, index) {
              final report = _pendingReports[index];
              final isSelected = _selectedReports.contains(report);
              
              return ReportCardWidget(
                report: report,
                isSelected: isSelected,
                isBulkMode: _isBulkMode,
                onTap: _isBulkMode
                    ? () => _toggleReportSelection(report)
                    : () => _showReportDetails(report),
                onResolve: (resolution, notes, actions) => 
                    _resolveReport(report, resolution, notes, actions),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    return const Center(
      child: Text('Posts moderation coming soon'),
    );
  }

  Widget _buildCommentsTab() {
    return const Center(
      child: Text('Comments moderation coming soon'),
    );
  }

  Widget _buildStatsTab() {
    if (_stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ModerationStatsWidget(stats: _stats!),
    );
  }

  void _enterBulkMode() {
    setState(() {
      _isBulkMode = true;
      _selectedReports.clear();
    });
  }

  void _exitBulkMode() {
    setState(() {
      _isBulkMode = false;
      _selectedReports.clear();
    });
  }

  void _toggleReportSelection(ContentReport report) {
    setState(() {
      if (_selectedReports.contains(report)) {
        _selectedReports.remove(report);
      } else {
        _selectedReports.add(report);
      }
    });
  }

  void _selectAllReports() {
    setState(() {
      _selectedReports = List.from(_pendingReports);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedReports.clear();
    });
  }

  void _showBulkActionsDialog() {
    showDialog(
      context: context,
      builder: (context) => BulkActionsWidget(
        selectedReports: _selectedReports,
        onActionCompleted: () {
          _exitBulkMode();
          _loadData();
        },
      ),
    );
  }

  void _showReportDetails(ContentReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReportDetailsSheet(report),
    );
  }

  Widget _buildReportDetailsSheet(ContentReport report) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.report,
                      color: _getReportSeverityColor(report.reason),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Report Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReportInfoSection(report),
                      const SizedBox(height: 24),
                      _buildReportedContentSection(report),
                      const SizedBox(height: 24),
                      _buildModerationActionsSection(report),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportInfoSection(ContentReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Type', report.type.toUpperCase()),
            _buildInfoRow('Reason', report.reason),
            if (report.description != null)
              _buildInfoRow('Description', report.description!),
            _buildInfoRow('Reported', _formatDateTime(report.createdAt)),
            _buildInfoRow('Reporter ID', report.reporterId),
          ],
        ),
      ),
    );
  }

  Widget _buildReportedContentSection(ContentReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reported Content',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // TODO: Load and display actual content
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Content preview will be loaded here...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationActionsSection(ContentReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moderation Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _resolveReport(
                      report,
                      'dismissed',
                      'No violation found',
                      {},
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Dismiss'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showModerationOptionsDialog(report),
                    icon: const Icon(Icons.gavel),
                    label: const Text('Take Action'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showModerationOptionsDialog(ContentReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Moderation Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.orange),
              title: const Text('Hide Content'),
              onTap: () {
                Navigator.pop(context);
                _resolveReport(report, 'content_hidden', 'Content hidden from public view', {
                  'hide': true,
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Content'),
              onTap: () {
                Navigator.pop(context);
                _resolveReport(report, 'content_deleted', 'Content deleted due to policy violation', {
                  'delete': true,
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.amber),
              title: const Text('Add Warning'),
              onTap: () {
                Navigator.pop(context);
                _resolveReport(report, 'warning_added', 'Content warning added', {
                  'addWarning': true,
                  'warningText': 'This content may be inappropriate',
                });
              },
            ),
          ],
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

  Future<void> _resolveReport(
    ContentReport report,
    String resolution,
    String notes,
    Map<String, dynamic> actions,
  ) async {
    try {
      await _moderationService.reviewReport(
        reportId: report.id,
        moderatorId: 'current_user_id', // TODO: Get from auth service
        resolution: resolution,
        resolutionNotes: notes,
        actions: actions,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report resolved: $resolution'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resolving report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getReportSeverityColor(String reason) {
    switch (reason.toLowerCase()) {
      case 'harassment':
      case 'hate_speech':
      case 'violence':
        return Colors.red;
      case 'spam':
      case 'misinformation':
        return Colors.orange;
      case 'inappropriate_content':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}


