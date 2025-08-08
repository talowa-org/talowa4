// Report Content Dialog Widget for TALOWA
// Implements Task 18: Add security and content safety - Report UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/security/content_moderation_service.dart';
import '../../services/security/user_safety_service.dart';
import '../../providers/auth_provider.dart';

class ReportContentDialog extends StatefulWidget {
  final String contentId;
  final String? contentType;
  final String? authorId;
  final String? contentPreview;

  const ReportContentDialog({
    Key? key,
    required this.contentId,
    this.contentType,
    this.authorId,
    this.contentPreview,
  }) : super(key: key);

  @override
  State<ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<ReportContentDialog> {
  final ContentModerationService _moderationService = ContentModerationService();
  final UserSafetyService _safetyService = UserSafetyService();
  final TextEditingController _descriptionController = TextEditingController();
  
  ContentReportReason? _selectedReason;
  bool _isSubmitting = false;
  bool _alsoBlockUser = false;

  final Map<ContentReportReason, String> _reasonDescriptions = {
    ContentReportReason.spam: 'Unwanted commercial content or repetitive posts',
    ContentReportReason.harassment: 'Bullying, threats, or targeted harassment',
    ContentReportReason.inappropriateContent: 'Content that violates community guidelines',
    ContentReportReason.violence: 'Graphic violence or threats of violence',
    ContentReportReason.threats: 'Direct threats against individuals or groups',
    ContentReportReason.hateSpeech: 'Content that attacks people based on identity',
    ContentReportReason.misinformation: 'False or misleading information',
    ContentReportReason.other: 'Other safety or policy violations',
  };

  @override
  void dispose() {
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
            if (widget.contentPreview != null) ...[
              Text(
                'Content:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.contentPreview!.length > 100
                      ? '${widget.contentPreview!.substring(0, 100)}...'
                      : widget.contentPreview!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Why are you reporting this content?',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._buildReasonOptions(),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                hintText: 'Provide more context about this report...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            if (widget.authorId != null) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Also block this user'),
                subtitle: const Text('Prevent them from contacting you'),
                value: _alsoBlockUser,
                onChanged: (value) {
                  setState(() {
                    _alsoBlockUser = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _selectedReason == null
              ? null
              : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }

  List<Widget> _buildReasonOptions() {
    return _reasonDescriptions.entries.map((entry) {
      return RadioListTile<ContentReportReason>(
        title: Text(_getReasonTitle(entry.key)),
        subtitle: Text(
          entry.value,
          style: const TextStyle(fontSize: 12),
        ),
        value: entry.key,
        groupValue: _selectedReason,
        onChanged: (value) {
          setState(() {
            _selectedReason = value;
          });
        },
        contentPadding: EdgeInsets.zero,
      );
    }).toList();
  }

  String _getReasonTitle(ContentReportReason reason) {
    switch (reason) {
      case ContentReportReason.spam:
        return 'Spam';
      case ContentReportReason.harassment:
        return 'Harassment';
      case ContentReportReason.inappropriateContent:
        return 'Inappropriate Content';
      case ContentReportReason.violence:
        return 'Violence';
      case ContentReportReason.threats:
        return 'Threats';
      case ContentReportReason.hateSpeech:
        return 'Hate Speech';
      case ContentReportReason.misinformation:
        return 'Misinformation';
      case ContentReportReason.other:
        return 'Other';
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = context.read<AuthProvider>().currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Submit content report
      final reportId = await _moderationService.reportContent(
        contentId: widget.contentId,
        reporterId: userId,
        reason: _selectedReason!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      // Block user if requested
      if (_alsoBlockUser && widget.authorId != null) {
        await _safetyService.blockUser(
          blockerId: userId,
          blockedUserId: widget.authorId!,
          reason: 'Reported for ${_getReasonTitle(_selectedReason!)}',
        );
      }

      Navigator.pop(context, true);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Report submitted successfully'),
              Text(
                'Report ID: ${reportId.substring(0, 8)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _showReportDetails(reportId),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showReportDetails(String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Submitted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report ID: $reportId'),
            const SizedBox(height: 12),
            const Text('What happens next:'),
            const SizedBox(height: 8),
            const Text('• Our safety team will review your report'),
            const Text('• We may take action on the content or user'),
            const Text('• You\'ll be notified of any updates'),
            const Text('• Reports are kept confidential'),
            const SizedBox(height: 12),
            const Text(
              'Thank you for helping keep TALOWA safe!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// Helper function to show report dialog
Future<bool?> showReportContentDialog({
  required BuildContext context,
  required String contentId,
  String? contentType,
  String? authorId,
  String? contentPreview,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => ReportContentDialog(
      contentId: contentId,
      contentType: contentType,
      authorId: authorId,
      contentPreview: contentPreview,
    ),
  );
}