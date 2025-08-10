// Moderation Statistics Widget for TALOWA Content Moderation
// Displays moderation statistics and analytics

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/social_feed/content_moderation_service.dart';
import '../../core/theme/app_theme.dart';

class ModerationStatsWidget extends StatelessWidget {
  final ModerationStats stats;

  const ModerationStatsWidget({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overview Cards
        _buildOverviewCards(context),
        
        const SizedBox(height: 24),
        
        // Reports Chart
        _buildReportsChart(context),
        
        const SizedBox(height: 24),
        
        // Actions Breakdown
        _buildActionsBreakdown(context),
        
        const SizedBox(height: 24),
        
        // Performance Metrics
        _buildPerformanceMetrics(context),
      ],
    );
  }

  Widget _buildOverviewCards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Total Reports',
                stats.totalReports.toString(),
                Icons.report,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'Pending',
                stats.pendingReports.toString(),
                Icons.pending,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Resolved',
                stats.resolvedReports.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'Actions Taken',
                stats.totalActions.toString(),
                Icons.gavel,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsChart(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: stats.pendingReports.toDouble(),
                      title: 'Pending\n${stats.pendingReports}',
                      color: Colors.orange,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: stats.resolvedReports.toDouble(),
                      title: 'Resolved\n${stats.resolvedReports}',
                      color: Colors.green,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsBreakdown(BuildContext context) {
    if (stats.actionsByType.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...stats.actionsByType.entries.map((entry) {
              final percentage = (entry.value / stats.totalActions * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatActionName(entry.key),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${entry.value} ($percentage%)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value / stats.totalActions,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getActionColor(entry.key),
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

  Widget _buildPerformanceMetrics(BuildContext context) {
    final resolutionRate = stats.totalReports > 0
        ? (stats.resolvedReports / stats.totalReports * 100).round()
        : 0;
    
    final avgResponseTime = '2.3 hours'; // This would be calculated from actual data
    final moderatorEfficiency = '85%'; // This would be calculated from actual data

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildMetricRow(
              context,
              'Resolution Rate',
              '$resolutionRate%',
              Icons.trending_up,
              resolutionRate >= 80 ? Colors.green : Colors.orange,
            ),
            
            const SizedBox(height: 12),
            
            _buildMetricRow(
              context,
              'Avg Response Time',
              avgResponseTime,
              Icons.schedule,
              Colors.blue,
            ),
            
            const SizedBox(height: 12),
            
            _buildMetricRow(
              context,
              'Moderator Efficiency',
              moderatorEfficiency,
              Icons.speed,
              Colors.purple,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Period: ${_formatDateRange(stats.period)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatActionName(String action) {
    return action
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'content_hidden':
      case 'hide':
        return Colors.orange;
      case 'content_deleted':
      case 'delete':
        return Colors.red;
      case 'warning_added':
      case 'warn':
        return Colors.amber;
      case 'user_restricted':
      case 'restrict':
        return Colors.purple;
      case 'user_banned':
      case 'ban':
        return Colors.red[800]!;
      case 'report_dismissed':
      case 'dismiss':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDateRange(DateRange range) {
    final startDate = '${range.start.day}/${range.start.month}/${range.start.year}';
    final endDate = '${range.end.day}/${range.end.month}/${range.end.year}';
    return '$startDate - $endDate';
  }
}