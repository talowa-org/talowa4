// Anonymous Reporting Screen for TALOWA
// Allows users to submit anonymous reports about land rights violations
// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/messaging/anonymous_messaging_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../core/theme/app_theme.dart';

class AnonymousReportingScreen extends StatefulWidget {
  final String? coordinatorId;
  final String? prefilledContent;
  final ReportType? initialReportType;

  const AnonymousReportingScreen({
    super.key,
    this.coordinatorId,
    this.prefilledContent,
    this.initialReportType,
  });

  @override
  State<AnonymousReportingScreen> createState() => _AnonymousReportingScreenState();
}

class _AnonymousReportingScreenState extends State<AnonymousReportingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _anonymousService = AnonymousMessagingService();
  final _locationService = LocationService();
  
  bool _isLoading = false;
  bool _includeLocation = false;
  ReportType _selectedReportType = ReportType.landGrabbing;
  String? _selectedCoordinatorId;
  List<Map<String, dynamic>> _availableCoordinators = [];
  Map<String, dynamic>? _currentLocation;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    if (widget.prefilledContent != null) {
      _contentController.text = widget.prefilledContent!;
    }
    
    if (widget.initialReportType != null) {
      _selectedReportType = widget.initialReportType!;
    }
    
    if (widget.coordinatorId != null) {
      _selectedCoordinatorId = widget.coordinatorId;
    }
    
    await _loadAvailableCoordinators();
    await _getCurrentLocation();
  }

  Future<void> _loadAvailableCoordinators() async {
    try {
      setState(() => _isLoading = true);
      
      // Get coordinators from user's geographic area
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        // In a real implementation, this would fetch coordinators based on user's location
        _availableCoordinators = [
          {
            'id': 'coord_1',
            'name': 'Village Coordinator',
            'role': 'Village Coordinator',
            'area': 'Local Village',
          },
          {
            'id': 'coord_2', 
            'name': 'Mandal Coordinator',
            'role': 'Mandal Coordinator',
            'area': 'Mandal Level',
          },
          {
            'id': 'coord_3',
            'name': 'District Coordinator', 
            'role': 'District Coordinator',
            'area': 'District Level',
          },
        ];
        
        if (_selectedCoordinatorId == null && _availableCoordinators.isNotEmpty) {
          _selectedCoordinatorId = _availableCoordinators.first['id'];
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load coordinators: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (_includeLocation) {
        final location = await _locationService.getCurrentLocation();
        setState(() {
          _currentLocation = {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'accuracy': location.accuracy,
            'timestamp': DateTime.now().toIso8601String(),
          };
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      // Continue without location
    }
  }

  Future<void> _submitAnonymousReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCoordinatorId == null) {
      _showErrorSnackBar('Please select a coordinator to send the report to');
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Get current location if requested
      Map<String, dynamic>? locationData;
      if (_includeLocation) {
        await _getCurrentLocation();
        locationData = _currentLocation;
      }

      // Submit anonymous report
      final caseId = await _anonymousService.sendAnonymousReport(
        content: _contentController.text.trim(),
        coordinatorId: _selectedCoordinatorId!,
        reportType: _selectedReportType,
        location: locationData,
        mediaUrls: [], // TODO: Add media upload support
      );

      // Show success message with case ID
      _showSuccessDialog(caseId);
      
    } catch (e) {
      _showErrorSnackBar('Failed to submit report: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String caseId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Report Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your anonymous report has been submitted successfully.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
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
                  const Text(
                    'Case ID:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          caseId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: caseId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Case ID copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please save this Case ID to track your report. You can use it to check for responses from coordinators.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anonymous Report'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Privacy Notice
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
                          Icon(Icons.security, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Privacy Protection',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your identity will be completely protected. The coordinator will not know who sent this report. Only a unique case ID will be generated for tracking.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Report Type Selection
                const Text(
                  'Report Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ReportType>(
                  value: _selectedReportType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ReportType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedReportType = value);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Coordinator Selection
                const Text(
                  'Send Report To',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCoordinatorId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _availableCoordinators.map((coordinator) {
                    return DropdownMenuItem(
                      value: coordinator['id'],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coordinator['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${coordinator['role']} - ${coordinator['area']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCoordinatorId = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a coordinator';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Report Content
                const Text(
                  'Report Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _contentController,
                  hintText: 'Describe the issue in detail...',
                  maxLines: 8,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please provide details about the issue';
                    }
                    if (value.trim().length < 20) {
                      return 'Please provide more details (at least 20 characters)';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Location Option
                CheckboxListTile(
                  title: const Text('Include approximate location'),
                  subtitle: const Text(
                    'Location will be generalized to village level for privacy',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _includeLocation,
                  onChanged: (value) {
                    setState(() => _includeLocation = value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                
                const SizedBox(height: 24),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Submit Anonymous Report',
                    onPressed: _submitAnonymousReport,
                    backgroundColor: AppTheme.primaryColor,
                    textColor: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Help Text
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
                        'Important Notes:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'â€¢ Your identity will remain completely anonymous\n'
                        'â€¢ Save the case ID to track responses\n'
                        'â€¢ Coordinators can respond without knowing who you are\n'
                        'â€¢ Location data is generalized for privacy protection\n'
                        'â€¢ False reports may result in account restrictions',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Extension to add display names for ReportType
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
