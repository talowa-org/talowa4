// Moderation Analytics and Reporting Dashboard Widget
// Implements comprehensive moderation analytics and reporting dashboard

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ai/moderation_models.dart';
import '../../services/ai/ai_moderation_service.dart';

class ModerationDashboard extends StatefulWidget {
  const ModerationDashboard({super.key});

  @override
  State<ModerationDashboard> createState() => _ModerationDashboardState();
}

class _ModerationDashboardState extends State<ModerationDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AIModerationService _moderationService = AIModerationService();
  
  ModerationAnalytics? _analytics;
  bool _isLoading = true;
  String? _error;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _moderationService.initialize();
      final analytics = await _moderationService.getModerationAnalytics(
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Overview'),
            Tab(icon: Icon(Icons.flag), text: 'Flags'),
            Tab(icon: Icon(Icons.trending_up), text: 'Trends'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _analytics != null
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildFlagsTab(),
                        _buildTrendsTab(),
                        _buildSettingsTab(),
                      ],
                    )
                  : const Center(child: Text('No data available')),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading analytics',
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
            onPressed: _loadAnalytics,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeCard(),
          const SizedBox(height: 16),
          _buildMetricsGrid(),
          const SizedBox(height: 16),
          _buildActionBreakdownCard(),
          const SizedBox(height: 16),
          _buildPerformanceCard(),
        ],
      ),
    );
  }

  Widget _buildDateRangeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.indigo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysis Period',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _selectDateRange,
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMetricCard(
          'Total Moderated',
          _analytics!.totalContentModerated.toString(),
          Icons.security,
          Colors.blue,
        ),
        _buildMetricCard(
          'Escalated',
          _analytics!.totalEscalated.toString(),
          Icons.flag,
          Colors.orange,
        ),
        _buildMetricCard(
          'Accuracy Rate',
          '${(_analytics!.accuracyRate * 100).toStringAsFixed(1)}%',
          Icons.check_circle,
          Colors.green,
        ),
        _buildMetricCard(
          'Avg Processing',
          '${_analytics!.averageProcessingTime.toStringAsFixed(0)}ms',
          Icons.speed,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBreakdownCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moderation Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._analytics!.actionBreakdown.entries.map((entry) {
              final percentage = _analytics!.totalContentModerated > 0
                  ? (entry.value / _analytics!.totalContentModerated * 100)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatActionName(entry.key),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getActionColor(entry.key),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildPerformanceRow(
              'Accuracy Rate',
              '${(_analytics!.accuracyRate * 100).toStringAsFixed(2)}%',
              _analytics!.accuracyRate,
              Colors.green,
            ),
            _buildPerformanceRow(
              'Escalation Rate',
              '${(_analytics!.escalationRate * 100).toStringAsFixed(2)}%',
              _analytics!.escalationRate,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Target accuracy: 95% | Current: ${(_analytics!.accuracyRate * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
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

  Widget _buildPerformanceRow(String label, String value, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content Flags Breakdown',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _analytics!.flagBreakdown.entries.map((entry) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getFlagColor(entry.key),
                      child: Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(_formatFlagName(entry.key)),
                    subtitle: Text('${entry.value} occurrences'),
                    trailing: Icon(
                      _getFlagIcon(entry.key),
                      color: _getFlagColor(entry.key),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Trends Analysis',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Moderation Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Moderation Level'),
                  subtitle: const Text('Standard'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Implement moderation level settings
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Alert Notifications'),
                  subtitle: const Text('Enabled'),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      // TODO: Implement notification settings
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export Analytics'),
                  subtitle: const Text('Download CSV report'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Implement export functionality
                    _showExportDialog();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Analytics'),
        content: const Text('Export moderation analytics data as CSV file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement actual export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export functionality coming soon'),
                ),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatActionName(String action) {
    switch (action) {
      case 'approve':
        return 'Approved';
      case 'flagForReview':
        return 'Flagged for Review';
      case 'reject':
        return 'Rejected';
      case 'shadowBan':
        return 'Shadow Banned';
      case 'temporaryRestriction':
        return 'Temporary Restriction';
      case 'permanentBan':
        return 'Permanent Ban';
      default:
        return action;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'approve':
        return Colors.green;
      case 'flagForReview':
        return Colors.orange;
      case 'reject':
        return Colors.red;
      case 'shadowBan':
        return Colors.purple;
      case 'temporaryRestriction':
        return Colors.deepOrange;
      case 'permanentBan':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  String _formatFlagName(String flag) {
    switch (flag) {
      case 'toxicity':
        return 'Toxic Content';
      case 'hate_speech':
        return 'Hate Speech';
      case 'harassment':
        return 'Harassment';
      case 'spam':
        return 'Spam';
      case 'violence':
        return 'Violence/Threats';
      case 'misinformation':
        return 'Misinformation';
      case 'cultural_sensitivity':
        return 'Cultural Sensitivity';
      case 'inappropriate_media':
        return 'Inappropriate Media';
      default:
        return flag.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color _getFlagColor(String flag) {
    switch (flag) {
      case 'toxicity':
        return Colors.red;
      case 'hate_speech':
        return Colors.deepPurple;
      case 'harassment':
        return Colors.orange;
      case 'spam':
        return Colors.yellow[700]!;
      case 'violence':
        return Colors.red[900]!;
      case 'misinformation':
        return Colors.blue;
      case 'cultural_sensitivity':
        return Colors.teal;
      case 'inappropriate_media':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getFlagIcon(String flag) {
    switch (flag) {
      case 'toxicity':
        return Icons.warning;
      case 'hate_speech':
        return Icons.block;
      case 'harassment':
        return Icons.person_off;
      case 'spam':
        return Icons.report;
      case 'violence':
        return Icons.dangerous;
      case 'misinformation':
        return Icons.fact_check;
      case 'cultural_sensitivity':
        return Icons.public;
      case 'inappropriate_media':
        return Icons.image_not_supported;
      default:
        return Icons.flag;
    }
  }
}