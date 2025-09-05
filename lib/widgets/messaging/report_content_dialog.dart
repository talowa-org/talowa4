// Report Content Dialog Widget for TALOWA Messaging System
import 'package:flutter/material.dart';
import '../../models/messaging/content_report_model.dart';
import '../../services/messaging/content_moderation_service.dart';

class ReportContentDialog extends StatefulWidget {
  final String messageId;
  final String conversationId;
  final String reportedUserId;
  final String reportedUserName;
  final String reporterId;
  final String reporterName;

  const ReportContentDialog({
    super.key,
    required this.messageId,
    required this.conversationId,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.reporterId,
    required this.reporterName,
  });

  @override
  State<ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<ReportContentDialog> {
  ReportType _selectedType = ReportType.inappropriate;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Content'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporting message from ${widget.reportedUserName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            
            // Report type selection
            const Text(
              'What type of issue is this?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...ReportType.values.map((type) => RadioListTile<ReportType>(
              title: Text(type.displayName),
              value: type,
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),
            
            const SizedBox(height: 16),
            
            // Reason field
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Brief reason *',
                hintText: 'Briefly describe the issue',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            
            const SizedBox(height: 16),
            
            // Description field
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                hintText: 'Provide more context if needed',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            
            const SizedBox(height: 8),
            Text(
              'Your report will be reviewed by our moderation team. False reports may result in restrictions on your account.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
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
          onPressed: _isSubmitting ? null : _submitReport,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }

  Future<void> _submitReport() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for the report'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ContentModerationService.reportContent(
        reporterId: widget.reporterId,
        reporterName: widget.reporterName,
        messageId: widget.messageId,
        conversationId: widget.conversationId,
        reportedUserId: widget.reportedUserId,
        reportedUserName: widget.reportedUserName,
        reportType: _selectedType,
        reason: _reasonController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully. Thank you for helping keep our community safe.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

/// Helper function to show report dialog
Future<void> showReportContentDialog({
  required BuildContext context,
  required String messageId,
  required String conversationId,
  required String reportedUserId,
  required String reportedUserName,
  required String reporterId,
  required String reporterName,
}) {
  return showDialog(
    context: context,
    builder: (context) => ReportContentDialog(
      messageId: messageId,
      conversationId: conversationId,
      reportedUserId: reportedUserId,
      reportedUserName: reportedUserName,
      reporterId: reporterId,
      reporterName: reporterName,
    ),
  );
}
