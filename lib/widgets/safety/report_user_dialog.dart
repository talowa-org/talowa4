// Report User Dialog Widget for TALOWA
// Implements Task 18: Add security and content safety - User Report UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/security/user_safety_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../common/user_avatar.dart';

class ReportUserDialog extends StatefulWidget {
  final String reportedUserId;
  final String? reportedUserName;
  final String? reportedUserAvatar;
  final List<String>? recentMessages;

  const ReportUserDialog({
    Key? key,
    required this.reportedUserId,
    this.reportedUserName,
    this.reportedUserAvatar,
    this.recentMessages,
  }) : super(key: key);

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  final UserSafetyService _safetyService = UserSafetyService();
  final TextEditingController _descriptionController = TextEditingController();
  
  UserReportReason? _selectedReason;
  bool _isSubmitting = false;
  bool _alsoBlockUser = true;
  HarassmentAnalysis? _harassmentAnalysis;

  final Map<UserReportReason, String> _reasonDescriptions = {
    UserReportReason.harassment: 'Bullying, intimidation, or targeted harassment',
    UserReportReason.spam: 'Sending unwanted messages or promotional content',
    UserReportReason.inappropriateContent: 'Sharing inappropriate or offensive content',
    UserReportReason.impersonation: 'Pretending to be someone else',
    UserReportReason.threats: 'Making threats of violence or harm',
    UserReportReason.hateSpeech: 'Using language that attacks people based on identity',
    UserReportReason.other: 'Other safety or policy violations',
  };

  @override
  void initState() {
    super.initState();
    _analyzeHarassmentPattern();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _analyzeHarassmentPattern() async {
    if (widget.recentMessages != null && widget.recentMessages!.isNotEmpty) {
      try {
        final userId = context.read<AuthProvider>().currentUser?.uid;
        if (userId == null) return;

        final analysis = await _safetyService.analyzeHarassmentPattern(
          userId: widget.reportedUserId,
          targetUserId: userId,
          recentMessages: widget.recentMessages!,
        );

        setState(() {
          _harassmentAnalysis = analysis;
          
          // Auto-select harassment if high risk
          if (analysis.riskLevel == RiskLevel.high || 
              analysis.riskLevel == RiskLevel.critical) {
            _selectedReason = UserReportReason.harassment;
          }
        });
      } catch (e) {
        debugPrint('Error analyzing harassment pattern: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfo(),
            const SizedBox(height: 16),
            if (_harassmentAnalysis != null) ...[
              _buildHarassmentWarning(),
              const SizedBox(height: 16),
            ],
            Text(
              'Why are you reporting this user?',
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
                hintText: 'Describe what happened...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Block this user'),
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

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          UserAvatar(
            imageUrl: widget.reportedUserAvatar,
            name: widget.reportedUserName ?? 'Unknown User',
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reportedUserName ?? 'Unknown User',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Reporting this user',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarassmentWarning() {
    if (_harassmentAnalysis == null) return const SizedBox.shrink();

    Color warningColor;
    IconData warningIcon;
    String warningText;

    switch (_harassmentAnalysis!.riskLevel) {
      case RiskLevel.critical:
        warningColor = Colors.red;
        warningIcon = Icons.dangerous;
        warningText = 'Critical harassment pattern detected';
        break;
      case RiskLevel.high:
        warningColor = Colors.orange;
        warningIcon = Icons.warning;
        warningText = 'High risk harassment pattern detected';
        break;
      case RiskLevel.medium:
        warningColor = Colors.yellow[700]!;
        warningIcon = Icons.info;
        warningText = 'Potential harassment pattern detected';
        break;
      case RiskLevel.low:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(warningIcon, color: warningColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warningText,
                  style: TextStyle(
                    color: warningColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (_harassmentAnalysis!.detectedPatterns.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Detected patterns:',
              style: TextStyle(
                color: warningColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            ..._harassmentAnalysis!.detectedPatterns.map((pattern) {
              return Text(
                '• ${_getPatternDescription(pattern)}',
                style: TextStyle(
                  color: warningColor,
                  fontSize: 12,
                ),
              );
            }),
          ],
          if (_harassmentAnalysis!.recommendations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Recommendations:',
              style: TextStyle(
                color: warningColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            ..._harassmentAnalysis!.recommendations.map((rec) {
              return Text(
                '• $rec',
                style: TextStyle(
                  color: warningColor,
                  fontSize: 12,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _getPatternDescription(HarassmentPattern pattern) {
    switch (pattern) {
      case HarassmentPattern.excessiveMessaging:
        return 'Sending too many messages';
      case HarassmentPattern.threats:
        return 'Threatening language detected';
      case HarassmentPattern.personalAttacks:
        return 'Personal attacks and insults';
      case HarassmentPattern.stalking:
        return 'Stalking behavior';
      case HarassmentPattern.impersonation:
        return 'Impersonation attempts';
    }
  }

  List<Widget> _buildReasonOptions() {
    return _reasonDescriptions.entries.map((entry) {
      return RadioListTile<UserReportReason>(
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

  String _getReasonTitle(UserReportReason reason) {
    switch (reason) {
      case UserReportReason.harassment:
        return 'Harassment';
      case UserReportReason.spam:
        return 'Spam';
      case UserReportReason.inappropriateContent:
        return 'Inappropriate Content';
      case UserReportReason.impersonation:
        return 'Impersonation';
      case UserReportReason.threats:
        return 'Threats';
      case UserReportReason.hateSpeech:
        return 'Hate Speech';
      case UserReportReason.other:
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

      // Submit user report
      final reportId = await _safetyService.reportUser(
        reporterId: userId,
        reportedUserId: widget.reportedUserId,
        reason: _selectedReason!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      // Block user if requested
      if (_alsoBlockUser) {
        await _safetyService.blockUser(
          blockerId: userId,
          blockedUserId: widget.reportedUserId,
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
              const Text('User reported successfully'),
              if (_alsoBlockUser)
                const Text('User has been blocked'),
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
            const Text('• Our safety team will investigate'),
            const Text('• We may take action on the user\'s account'),
            const Text('• You\'ll be notified of any updates'),
            const Text('• Your report is kept confidential'),
            if (_alsoBlockUser) ...[
              const SizedBox(height: 8),
              const Text('• The user has been blocked from contacting you'),
            ],
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

// Helper function to show report user dialog
Future<bool?> showReportUserDialog({
  required BuildContext context,
  required String reportedUserId,
  String? reportedUserName,
  String? reportedUserAvatar,
  List<String>? recentMessages,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => ReportUserDialog(
      reportedUserId: reportedUserId,
      reportedUserName: reportedUserName,
      reportedUserAvatar: reportedUserAvatar,
      recentMessages: recentMessages,
    ),
  );
}