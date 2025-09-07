// Anonymous Reports Management Screen for TALOWA
// Allows coordinators to view and respond to anonymous reports
// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5

import 'package:flutter/material.dart';
import '../../services/messaging/anonymous_messaging_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../core/theme/app_theme.dart';

class AnonymousReportsManagementScreen extends StatefulWidget {
  const AnonymousReportsManagementScreen({super.key});

  @override
  State<AnonymousReportsManagementScreen> createState() => _AnonymousReportsManagementScreenState();
}

class _AnonymousReportsManagementScreenState extends State<AnonymousReportsManagementScreen> {
  final _anonymousService = AnonymousMessagingService();
  
  bool _isLoading = false;
  List<AnonymousReport> _reports = [];
  AnonymousReportStats? _stats;
  ReportStatus? _filterStatus;
  ReportType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadStatistics();
  }

  Future<void> _loadReports() async {
    try {
      setState(() => _isLoading = true);
      
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get reports stream and convert to list for initial load
      final reportsStream = _anonymousService.getAnonymousReports(currentUser.uid);
      final reports = await reportsStream.first;
      
      setState(() {
        _reports = reports;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load reports: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      final stats = await _anonymousService.getReportStatistics(currentUser.uid);
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      debugPrint('Failed to load statistics: $e');
    }
  }

  List<AnonymousReport> get _filteredReports {
    var filtered = _reports;
    
    if (_filterStatus != null) {
      filtered = filtered.where((report) => report.status == _filterStatus).toList();
    }
    
    if (_filterType != null) {
      filtered = filtered.where((report) => report.reportType == _filterType).toList();
    }
    
    return filtered;
  }

  Future<void> _respondToReport(AnonymousReport report) async {
    final responseController = TextEditingController();
    bool isPublicResponse = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Respond to Case ${report.caseId}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original report summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Type: ${report.reportType.displayName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Submitted: ${_formatDate(report.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Response input
                const Text(
                  'Your Response:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: responseController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter your response...',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Public response option
                CheckboxListTile(
                  title: const Text('Public Response'),
                  subtitle: const Text(
                    'Make this response visible to other coordinators (still anonymous)',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: isPublicResponse,
                  onChanged: (value) {
                    setDialogState(() {
                      isPublicResponse = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (responseController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a response')),
                  );
                  return;
                }
                
                try {
                  await _anonymousService.respondToAnonymousReport(
                    caseId: report.caseId,
                    response: responseController.text.trim(),
                    isPublicResponse: isPublicResponse,
                  );
                  
                  Navigator.of(context).pop(true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send response: $e')),
                  );
                }
              },
              child: const Text('Send Response'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _showSuccessSnackBar('Response sent successfully');
      _loadReports(); // Refresh the list
    }
  }

  Future<void> _updateReportStatus(AnonymousReport report, ReportStatus newStatus) async {
    try {
      await _anonymousService.updateReportStatus(
        caseId: report.caseId,
        status: newStatus,
      );
      
      _showSuccessSnackBar('Report status updated');
      _loadReports(); // Refresh the list
      _loadStatistics(); // Refresh stats
    } catch (e) {
      _showErrorSnackBar('Failed to update status: $e');
    }
  }

  void _showReportDetails(AnonymousReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getReportTypeIcon(report.reportType),
              color: _getReportTypeColor(report.reportType),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Case ${report.caseId}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Report metadata
                _buildDetailRow('Type', report.reportType.displayName),
                _buildDetailRow('Status', report.status.displayName),
                _buildDetailRow('Submitted', _formatDate(report.createdAt)),
                _buildDetailRow('Last Updated', _formatDate(report.lastUpdatedAt)),
                _buildDetailRow('Responses', '${report.responseCount}'),
                
                if (report.generalizedLocation != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Location (Generalized):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${report.generalizedLocation!['villageName'] ?? 'Unknown Village'}, '
                    '${report.generalizedLocation!['mandalName'] ?? 'Unknown Mandal'}',
                  ),
                ],
                
                const SizedBox(height: 16),
                const Text(
                  'Report Content:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(report.content),
                ),
                
                if (report.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Attachments:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...report.mediaUrls.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.attachment, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            url.split('/').last,
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (report.status == ReportStatus.pending)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _respondToReport(report);
              },
              child: const Text('Respond'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  IconData _getReportTypeIcon(ReportType type) {
    switch (type) {
      case ReportType.landGrabbing:
        return Icons.landscape;
      case ReportType.corruption:
        return Icons.gavel;
      case ReportType.harassment:
        return Icons.warning;
      case ReportType.illegalConstruction:
        return Icons.construction;
      case ReportType.documentForgery:
        return Icons.description;
      case ReportType.other:
        return Icons.help_outline;
    }
  }

  Color _getReportTypeColor(ReportType type) {
    switch (type) {
      case ReportType.landGrabbing:
        return Colors.red;
      case ReportType.corruption:
        return Colors.orange;
      case ReportType.harassment:
        return Colors.purple;
      case ReportType.illegalConstruction:
        return Colors.brown;
      case ReportType.documentForgery:
        return Colors.blue;
      case ReportType.other:
        return Colors.grey;
    }
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.inProgress:
        return Colors.blue;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.closed:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anonymous Reports'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadReports();
              _loadStatistics();
            },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            // Statistics Card
            if (_stats != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total',
                            '${_stats!.totalReports}',
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Pending',
                            '${_stats!.pendingReports}',
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Resolved',
                            '${_stats!.resolvedReports}',
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            // Filters
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ReportStatus>(
                      initialValue: _filterStatus,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Status',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<ReportStatus>(
                          value: null,
                          child: Text('All Statuses'),
                        ),
                        ...ReportStatus.values.map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.displayName),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _filterStatus = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<ReportType>(
                      initialValue: _filterType,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Type',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<ReportType>(
                          value: null,
                          child: Text('All Types'),
                        ),
                        ...ReportType.values.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _filterType = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Reports List
            Expanded(
              child: _filteredReports.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No anonymous reports found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredReports.length,
                      itemBuilder: (context, index) {
                        final report = _filteredReports[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getReportTypeColor(report.reportType),
                              child: Icon(
                                _getReportTypeIcon(report.reportType),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Case ${report.caseId}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.reportType.displayName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  report.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(report.status),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        report.status.displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(report.createdAt),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'view':
                                    _showReportDetails(report);
                                    break;
                                  case 'respond':
                                    _respondToReport(report);
                                    break;
                                  case 'in_progress':
                                    _updateReportStatus(report, ReportStatus.inProgress);
                                    break;
                                  case 'resolved':
                                    _updateReportStatus(report, ReportStatus.resolved);
                                    break;
                                  case 'closed':
                                    _updateReportStatus(report, ReportStatus.closed);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility),
                                      SizedBox(width: 8),
                                      Text('View Details'),
                                    ],
                                  ),
                                ),
                                if (report.status == ReportStatus.pending)
                                  const PopupMenuItem(
                                    value: 'respond',
                                    child: Row(
                                      children: [
                                        Icon(Icons.reply),
                                        SizedBox(width: 8),
                                        Text('Respond'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'in_progress',
                                  child: Row(
                                    children: [
                                      Icon(Icons.work),
                                      SizedBox(width: 8),
                                      Text('Mark In Progress'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'resolved',
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle),
                                      SizedBox(width: 8),
                                      Text('Mark Resolved'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'closed',
                                  child: Row(
                                    children: [
                                      Icon(Icons.close),
                                      SizedBox(width: 8),
                                      Text('Close Report'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showReportDetails(report),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Extensions for display names
extension ReportStatusDisplay on ReportStatus {
  String get displayName {
    switch (this) {
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.closed:
        return 'Closed';
    }
  }
}

extension ReportTypeDisplay on ReportType {
  String get displayName {
    switch (this) {
      case ReportType.landGrabbing:
        return 'Land Grabbing';
      case ReportType.corruption:
        return 'Corruption';
      case ReportType.harassment:
        return 'Harassment';
      case ReportType.illegalConstruction:
        return 'Illegal Construction';
      case ReportType.documentForgery:
        return 'Document Forgery';
      case ReportType.other:
        return 'Other';
    }
  }
}


