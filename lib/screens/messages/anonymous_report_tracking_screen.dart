// Anonymous Report Tracking Screen for TALOWA
// Allows users to track their anonymous reports using case IDs
// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/messaging/anonymous_messaging_service.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../core/theme/app_theme.dart';

class AnonymousReportTrackingScreen extends StatefulWidget {
  const AnonymousReportTrackingScreen({super.key});

  @override
  State<AnonymousReportTrackingScreen> createState() => _AnonymousReportTrackingScreenState();
}

class _AnonymousReportTrackingScreenState extends State<AnonymousReportTrackingScreen> {
  final _caseIdController = TextEditingController();
  final _anonymousService = AnonymousMessagingService();
  
  bool _isLoading = false;
  List<AnonymousResponse> _responses = [];
  String? _currentCaseId;

  @override
  void dispose() {
    _caseIdController.dispose();
    super.dispose();
  }

  Future<void> _trackReport() async {
    final caseId = _caseIdController.text.trim();
    if (caseId.isEmpty) {
      _showErrorSnackBar('Please enter a case ID');
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      final responses = await _anonymousService.getAnonymousResponses(caseId);
      
      setState(() {
        _responses = responses;
        _currentCaseId = caseId;
      });
      
      if (responses.isEmpty) {
        _showInfoSnackBar('No responses found for this case ID yet');
      }
    } catch (e) {
      if (e.toString().contains('Unauthorized access')) {
        _showErrorSnackBar('Invalid case ID or you are not authorized to view this report');
      } else if (e.toString().contains('not found')) {
        _showErrorSnackBar('Case ID not found. Please check and try again.');
      } else {
        _showErrorSnackBar('Failed to track report: $e');
      }
      
      setState(() {
        _responses = [];
        _currentCaseId = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearTracking() {
    setState(() {
      _responses = [];
      _currentCaseId = null;
      _caseIdController.clear();
    });
  }

  void _showResponseDetails(AnonymousResponse response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.reply, color: Colors.blue),
            SizedBox(width: 8),
            Text('Coordinator Response'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Response metadata
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Received: ${_formatDate(response.createdAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (response.isPublicResponse) ...[
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.public, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            'Public Response',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Response content
              const Text(
                'Response:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  response.response,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Anonymous Report'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentCaseId != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearTracking,
              tooltip: 'Clear tracking',
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'How to Track Your Report',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enter the case ID you received when submitting your anonymous report. '
                      'You can check for responses from coordinators and track the status of your report.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Case ID Input
              const Text(
                'Case ID',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _caseIdController,
                      hintText: 'Enter your case ID (e.g., ANON-123456-789012)',
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _trackReport(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData('text/plain');
                      if (clipboardData?.text != null) {
                        _caseIdController.text = clipboardData!.text!;
                      }
                    },
                    icon: const Icon(Icons.paste),
                    tooltip: 'Paste from clipboard',
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Track Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Track Report',
                  onPressed: _trackReport,
                  backgroundColor: AppTheme.primaryColor,
                  textColor: Colors.white,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Results Section
              if (_currentCaseId != null) ...[
                Container(
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
                      Row(
                        children: [
                          const Icon(Icons.track_changes, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            'Tracking Results',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Case: $_currentCaseId',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      if (_responses.isEmpty) ...[
                        const Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No responses yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Coordinators will respond to your report soon',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Responses (${_responses.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Responses List
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _responses.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final response = _responses[index];
                            return Card(
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: response.isPublicResponse 
                                      ? Colors.blue 
                                      : Colors.green,
                                  child: Icon(
                                    response.isPublicResponse 
                                        ? Icons.public 
                                        : Icons.reply,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  response.isPublicResponse 
                                      ? 'Public Response' 
                                      : 'Private Response',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      response.response,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Received: ${_formatDate(response.createdAt)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => _showResponseDetails(response),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Help Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What happens next?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Coordinators will review your report\n'
                        '• You will receive responses here when available\n'
                        '• Your identity remains completely anonymous\n'
                        '• Check back regularly for updates\n'
                        '• Save your case ID for future reference',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


