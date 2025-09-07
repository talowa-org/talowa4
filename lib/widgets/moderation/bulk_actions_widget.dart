// Bulk Actions Widget for TALOWA Content Moderation
// Handles bulk moderation actions on multiple reports

import 'package:flutter/material.dart';
import '../../services/social_feed/content_moderation_service.dart';
import '../../core/theme/app_theme.dart';

class BulkActionsWidget extends StatefulWidget {
  final List<ContentReport> selectedReports;
  final VoidCallback onActionCompleted;

  const BulkActionsWidget({
    super.key,
    required this.selectedReports,
    required this.onActionCompleted,
  });

  @override
  State<BulkActionsWidget> createState() => _BulkActionsWidgetState();
}

class _BulkActionsWidgetState extends State<BulkActionsWidget> {
  final ContentModerationService _moderationService = ContentModerationService();
  final TextEditingController _reasonController = TextEditingController();
  
  String _selectedAction = '';
  bool _isProcessing = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.checklist, color: AppTheme.talowaGreen),
          const SizedBox(width: 8),
          Text('Bulk Actions (${widget.selectedReports.length})'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select an action to apply to all ${widget.selectedReports.length} selected reports:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            const SizedBox(height: 16),
            
            // Action Selection
            _buildActionTile(
              'dismiss_all',
              'Dismiss All Reports',
              'Mark all reports as dismissed (no violation found)',
              Icons.check_circle,
              Colors.green,
            ),
            
            _buildActionTile(
              'hide_content',
              'Hide All Content',
              'Hide all reported content from public view',
              Icons.visibility_off,
              Colors.orange,
            ),
            
            _buildActionTile(
              'delete_content',
              'Delete All Content',
              'Permanently delete all reported content',
              Icons.delete,
              Colors.red,
            ),
            
            _buildActionTile(
              'add_warnings',
              'Add Content Warnings',
              'Add warning labels to all reported content',
              Icons.warning,
              Colors.amber,
            ),
            
            if (_selectedAction.isNotEmpty) ...[
              const SizedBox(height: 16),
              
              // Reason Input
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Enter reason for this action...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),
              
              // Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getActionPreview(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedAction.isEmpty || _isProcessing
              ? null
              : _processBulkAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getActionColor(),
            foregroundColor: Colors.white,
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(_getActionButtonText()),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    String actionId,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedAction == actionId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _isProcessing
            ? null
            : () {
                setState(() {
                  _selectedAction = isSelected ? '' : actionId;
                });
              },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? color.withValues(alpha: 0.2) : null,
          ),
          child: Row(
            children: [
              Radio<String>(
                value: actionId,
                groupValue: _selectedAction,
                onChanged: _isProcessing
                    ? null
                    : (value) {
                        setState(() {
                          _selectedAction = value ?? '';
                        });
                      },
                activeColor: color,
              ),
              const SizedBox(width: 8),
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getActionPreview() {
    switch (_selectedAction) {
      case 'dismiss_all':
        return 'All ${widget.selectedReports.length} reports will be marked as dismissed with no action taken.';
      case 'hide_content':
        return 'All ${widget.selectedReports.length} pieces of reported content will be hidden from public view.';
      case 'delete_content':
        return 'All ${widget.selectedReports.length} pieces of reported content will be permanently deleted.';
      case 'add_warnings':
        return 'Warning labels will be added to all ${widget.selectedReports.length} pieces of reported content.';
      default:
        return '';
    }
  }

  Color _getActionColor() {
    switch (_selectedAction) {
      case 'dismiss_all':
        return Colors.green;
      case 'hide_content':
        return Colors.orange;
      case 'delete_content':
        return Colors.red;
      case 'add_warnings':
        return Colors.amber;
      default:
        return AppTheme.talowaGreen;
    }
  }

  String _getActionButtonText() {
    switch (_selectedAction) {
      case 'dismiss_all':
        return 'Dismiss All';
      case 'hide_content':
        return 'Hide All';
      case 'delete_content':
        return 'Delete All';
      case 'add_warnings':
        return 'Add Warnings';
      default:
        return 'Apply Action';
    }
  }

  Future<void> _processBulkAction() async {
    if (_selectedAction.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final reason = _reasonController.text.trim();
      
      // Group reports by type for efficient processing
      final postReports = widget.selectedReports
          .where((r) => r.type == 'post' && r.postId != null)
          .toList();
      final commentReports = widget.selectedReports
          .where((r) => r.type == 'comment' && r.commentId != null)
          .toList();

      // Process posts
      if (postReports.isNotEmpty) {
        await _processBulkActionForType(
          postReports.map((r) => r.postId!).toList(),
          'post',
          reason,
        );
      }

      // Process comments
      if (commentReports.isNotEmpty) {
        await _processBulkActionForType(
          commentReports.map((r) => r.commentId!).toList(),
          'comment',
          reason,
        );
      }

      // Resolve all reports
      for (final report in widget.selectedReports) {
        await _moderationService.reviewReport(
          reportId: report.id,
          moderatorId: 'current_user_id', // TODO: Get from auth service
          resolution: _getResolutionText(),
          resolutionNotes: reason.isEmpty ? _getDefaultResolutionNotes() : reason,
          actions: _getActionData(),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bulk action completed: ${widget.selectedReports.length} reports processed',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onActionCompleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing bulk action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processBulkActionForType(
    List<String> targetIds,
    String targetType,
    String reason,
  ) async {
    String action;
    Map<String, dynamic> additionalData = {};

    switch (_selectedAction) {
      case 'dismiss_all':
        return; // No content action needed for dismissal
      case 'hide_content':
        action = 'hide';
        break;
      case 'delete_content':
        action = 'delete';
        break;
      case 'add_warnings':
        action = 'add_warning';
        additionalData['warningText'] = 'This content has been flagged by moderators';
        break;
      default:
        return;
    }

    await _moderationService.bulkModerationAction(
      targetIds: targetIds,
      targetType: targetType,
      action: action,
      moderatorId: 'current_user_id', // TODO: Get from auth service
      reason: reason.isEmpty ? _getDefaultResolutionNotes() : reason,
      additionalData: additionalData,
    );
  }

  String _getResolutionText() {
    switch (_selectedAction) {
      case 'dismiss_all':
        return 'bulk_dismissed';
      case 'hide_content':
        return 'bulk_content_hidden';
      case 'delete_content':
        return 'bulk_content_deleted';
      case 'add_warnings':
        return 'bulk_warnings_added';
      default:
        return 'bulk_action_applied';
    }
  }

  String _getDefaultResolutionNotes() {
    switch (_selectedAction) {
      case 'dismiss_all':
        return 'Reports dismissed in bulk - no policy violations found';
      case 'hide_content':
        return 'Content hidden in bulk due to policy violations';
      case 'delete_content':
        return 'Content deleted in bulk due to serious policy violations';
      case 'add_warnings':
        return 'Content warnings added in bulk for potentially inappropriate content';
      default:
        return 'Bulk moderation action applied';
    }
  }

  Map<String, dynamic> _getActionData() {
    switch (_selectedAction) {
      case 'hide_content':
        return {'hide': true};
      case 'delete_content':
        return {'delete': true};
      case 'add_warnings':
        return {
          'addWarning': true,
          'warningText': 'This content has been flagged by moderators',
        };
      default:
        return {};
    }
  }
}


