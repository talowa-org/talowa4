// Report Card Widget for TALOWA Content Moderation
// Displays individual content reports in the moderation dashboard

import 'package:flutter/material.dart';
import '../../services/social_feed/content_moderation_service.dart';
import '../../core/theme/app_theme.dart';

class ReportCardWidget extends StatelessWidget {
  final ContentReport report;
  final bool isSelected;
  final bool isBulkMode;
  final VoidCallback onTap;
  final Function(String resolution, String notes, Map<String, dynamic> actions) onResolve;

  const ReportCardWidget({
    super.key,
    required this.report,
    required this.isSelected,
    required this.isBulkMode,
    required this.onTap,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppTheme.talowaGreen, width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isBulkMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => onTap,
                          activeColor: AppTheme.talowaGreen,
                        ),
                      ),
                    
                    // Report Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTypeColor().withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getTypeColor().withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        report.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getTypeColor(),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Severity Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getSeverityColor().withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getSeverityColor().withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getSeverityIcon(),
                            size: 12,
                            color: _getSeverityColor(),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getSeverityText(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getSeverityColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Time ago
                    Text(
                      _getTimeAgo(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Report reason
                Text(
                  _formatReason(report.reason),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                if (report.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    report.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Content preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        report.type == 'post' ? Icons.article : Icons.comment,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap to view ${report.type} content',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ],
                  ),
                ),
                
                if (!isBulkMode) ...[
                  const SizedBox(height: 12),
                  
                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onResolve(
                            'dismissed',
                            'No violation found',
                            {},
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Dismiss'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showQuickActionsMenu(context),
                          icon: const Icon(Icons.gavel, size: 16),
                          label: const Text('Action'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getSeverityColor(),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (report.type) {
      case 'post':
        return Colors.blue;
      case 'comment':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getSeverityColor() {
    switch (report.reason.toLowerCase()) {
      case 'harassment':
      case 'hate_speech':
      case 'violence':
      case 'threats':
        return Colors.red;
      case 'spam':
      case 'misinformation':
      case 'fake_news':
        return Colors.orange;
      case 'inappropriate_content':
      case 'adult_content':
        return Colors.amber;
      case 'copyright':
      case 'privacy':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getSeverityIcon() {
    switch (report.reason.toLowerCase()) {
      case 'harassment':
      case 'hate_speech':
        return Icons.warning;
      case 'violence':
      case 'threats':
        return Icons.dangerous;
      case 'spam':
        return Icons.block;
      case 'misinformation':
      case 'fake_news':
        return Icons.fact_check;
      case 'inappropriate_content':
      case 'adult_content':
        return Icons.visibility_off;
      case 'copyright':
        return Icons.copyright;
      case 'privacy':
        return Icons.privacy_tip;
      default:
        return Icons.report;
    }
  }

  String _getSeverityText() {
    switch (report.reason.toLowerCase()) {
      case 'harassment':
      case 'hate_speech':
      case 'violence':
      case 'threats':
        return 'HIGH';
      case 'spam':
      case 'misinformation':
      case 'fake_news':
        return 'MEDIUM';
      case 'inappropriate_content':
      case 'adult_content':
      case 'copyright':
      case 'privacy':
        return 'LOW';
      default:
        return 'REVIEW';
    }
  }

  String _formatReason(String reason) {
    return reason
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(report.createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}';
    }
  }

  void _showQuickActionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.orange),
              title: const Text('Hide Content'),
              subtitle: const Text('Hide from public view'),
              onTap: () {
                Navigator.pop(context);
                onResolve('content_hidden', 'Content hidden due to policy violation', {
                  'hide': true,
                });
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Content'),
              subtitle: const Text('Permanently remove content'),
              onTap: () {
                Navigator.pop(context);
                onResolve('content_deleted', 'Content deleted due to policy violation', {
                  'delete': true,
                });
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.amber),
              title: const Text('Add Warning'),
              subtitle: const Text('Add content warning label'),
              onTap: () {
                Navigator.pop(context);
                onResolve('warning_added', 'Content warning added', {
                  'addWarning': true,
                  'warningText': 'This content may be inappropriate',
                });
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.person_off, color: Colors.red),
              title: const Text('Restrict User'),
              subtitle: const Text('Temporarily restrict user posting'),
              onTap: () {
                Navigator.pop(context);
                onResolve('user_restricted', 'User restricted due to policy violation', {
                  'restrictUser': true,
                  'restrictionDays': 7,
                  'restrictionReason': 'Policy violation',
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


