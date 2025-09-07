// Content Reports Screen for TALOWA Admin Dashboard
import 'package:flutter/material.dart';
import '../../models/messaging/content_report_model.dart';
import '../../models/messaging/moderation_action_model.dart';
import '../../services/messaging/content_moderation_service.dart';

class ContentReportsScreen extends StatefulWidget {
  const ContentReportsScreen({super.key});

  @override
  State<ContentReportsScreen> createState() => _ContentReportsScreenState();
}

class _ContentReportsScreenState extends State<ContentReportsScreen> {
  ReportStatus? _selectedStatus;
  ReportType? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Reports'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleFilterAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filter_status',
                child: Text('Filter by Status'),
              ),
              const PopupMenuItem(
                value: 'filter_type',
                child: Text('Filter by Type'),
              ),
              const PopupMenuItem(
                value: 'clear_filters',
                child: Text('Clear Filters'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          if (_selectedStatus != null || _selectedType != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_selectedStatus != null)
                    FilterChip(
                      label: Text('Status: ${_selectedStatus!.displayName}'),
                      onSelected: (bool value) {},
                      onDeleted: () => setState(() => _selectedStatus = null),
                    ),
                  if (_selectedType != null)
                    FilterChip(
                      label: Text('Type: ${_selectedType!.displayName}'),
                      onSelected: (bool value) {},
                      onDeleted: () => setState(() => _selectedType = null),
                    ),
                ],
              ),
            ),
          
          // Reports list
          Expanded(
            child: StreamBuilder<List<ContentReportModel>>(
              stream: ContentModerationService.getReports(
                status: _selectedStatus,
                type: _selectedType,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error loading reports: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final reports = snapshot.data ?? [];

                if (reports.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No reports found'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _buildReportCard(report);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(ContentReportModel report) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(report.status).withValues(alpha: 0.2),
          child: Icon(
            _getReportTypeIcon(report.reportType),
            color: _getStatusColor(report.status),
          ),
        ),
        title: Text(
          '${report.reportType.displayName} - ${report.reportedUserName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.reason),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusChip(report.status),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(report.reportedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report details
                _buildDetailRow('Reporter', report.reporterName),
                _buildDetailRow('Reported User', report.reportedUserName),
                _buildDetailRow('Message ID', report.messageId),
                _buildDetailRow('Conversation ID', report.conversationId),
                if (report.description != null)
                  _buildDetailRow('Description', report.description!),
                
                if (report.reviewedBy != null) ...[
                  const Divider(),
                  _buildDetailRow('Reviewed By', report.reviewedBy!),
                  _buildDetailRow('Reviewed At', _formatDateTime(report.reviewedAt!)),
                  if (report.reviewNotes != null)
                    _buildDetailRow('Review Notes', report.reviewNotes!),
                ],
                
                const SizedBox(height: 16),
                
                // Action buttons
                if (report.status == ReportStatus.pending)
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _reviewReport(report, ReportStatus.reviewing),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Review'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showReviewDialog(report),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Resolve'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _reviewReport(report, ReportStatus.dismissed),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                
                if (report.status == ReportStatus.reviewing)
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _showReviewDialog(report),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Resolve'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _reviewReport(report, ReportStatus.dismissed),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
              ],
            ),
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
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    return Chip(
      label: Text(
        status.displayName,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
      side: BorderSide(color: _getStatusColor(status)),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.reviewing:
        return Colors.blue;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.dismissed:
        return Colors.grey;
    }
  }

  IconData _getReportTypeIcon(ReportType type) {
    switch (type) {
      case ReportType.inappropriate:
        return Icons.warning;
      case ReportType.spam:
        return Icons.block;
      case ReportType.harassment:
        return Icons.person_off;
      case ReportType.violence:
        return Icons.dangerous;
      case ReportType.misinformation:
        return Icons.fact_check;
      case ReportType.other:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _handleFilterAction(String action) {
    switch (action) {
      case 'filter_status':
        _showStatusFilterDialog();
        break;
      case 'filter_type':
        _showTypeFilterDialog();
        break;
      case 'clear_filters':
        setState(() {
          _selectedStatus = null;
          _selectedType = null;
        });
        break;
    }
  }

  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ReportStatus.values.map((status) => RadioListTile<ReportStatus>(
            title: Text(status.displayName),
            value: status,
            groupValue: _selectedStatus,
            onChanged: (value) {
              setState(() => _selectedStatus = value);
              Navigator.of(context).pop();
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showTypeFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ReportType.values.map((type) => RadioListTile<ReportType>(
            title: Text(type.displayName),
            value: type,
            groupValue: _selectedType,
            onChanged: (value) {
              setState(() => _selectedType = value);
              Navigator.of(context).pop();
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewReport(ContentReportModel report, ReportStatus newStatus) async {
    try {
      await ContentModerationService.reviewReport(
        reportId: report.id,
        reviewerId: 'admin_user', // TODO: Get actual admin user ID
        reviewerName: 'Admin', // TODO: Get actual admin name
        newStatus: newStatus,
        reviewNotes: newStatus == ReportStatus.dismissed ? 'Dismissed by admin' : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report ${newStatus.displayName.toLowerCase()}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReviewDialog(ContentReportModel report) {
    showDialog(
      context: context,
      builder: (context) => _ReviewReportDialog(report: report),
    );
  }
}

class _ReviewReportDialog extends StatefulWidget {
  final ContentReportModel report;

  const _ReviewReportDialog({required this.report});

  @override
  State<_ReviewReportDialog> createState() => _ReviewReportDialogState();
}

class _ReviewReportDialogState extends State<_ReviewReportDialog> {
  ModerationActionType? _selectedAction;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  Duration? _duration;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report: ${widget.report.reason}'),
            const SizedBox(height: 16),
            
            const Text('Action to take:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...ModerationActionType.values.map((action) => RadioListTile<ModerationActionType>(
              title: Text(action.displayName),
              subtitle: Text(action.description),
              value: action,
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
              dense: true,
            )),
            
            if (_selectedAction == ModerationActionType.temporaryRestriction) ...[
              const SizedBox(height: 16),
              const Text('Duration:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<Duration>(
                value: _duration,
                hint: const Text('Select duration'),
                items: const [
                  DropdownMenuItem(value: Duration(hours: 1), child: Text('1 hour')),
                  DropdownMenuItem(value: Duration(hours: 24), child: Text('24 hours')),
                  DropdownMenuItem(value: Duration(days: 3), child: Text('3 days')),
                  DropdownMenuItem(value: Duration(days: 7), child: Text('7 days')),
                ],
                onChanged: (value) => setState(() => _duration = value),
              ),
            ],
            
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Action reason',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Review notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submitReview() async {
    if (_selectedAction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an action')),
      );
      return;
    }

    if (_selectedAction == ModerationActionType.temporaryRestriction && _duration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select duration for temporary restriction')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ContentModerationService.reviewReport(
        reportId: widget.report.id,
        reviewerId: 'admin_user', // TODO: Get actual admin user ID
        reviewerName: 'Admin', // TODO: Get actual admin name
        newStatus: ReportStatus.resolved,
        reviewNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        actionType: _selectedAction,
        actionReason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : 'Content violation',
        actionDuration: _duration,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report resolved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}


