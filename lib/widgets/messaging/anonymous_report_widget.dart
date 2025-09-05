// Anonymous Report Widget for TALOWA
// Reusable widget for anonymous reporting functionality
// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5

import 'package:flutter/material.dart';
import '../../services/messaging/anonymous_messaging_service.dart';
import '../../screens/messages/anonymous_reporting_screen.dart';
import '../../screens/messages/anonymous_report_tracking_screen.dart';
import '../../core/theme/app_theme.dart';

class AnonymousReportWidget extends StatelessWidget {
  final String? coordinatorId;
  final ReportType? initialReportType;
  final String? prefilledContent;
  final bool showTrackingOption;
  final VoidCallback? onReportSubmitted;

  const AnonymousReportWidget({
    super.key,
    this.coordinatorId,
    this.initialReportType,
    this.prefilledContent,
    this.showTrackingOption = true,
    this.onReportSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.security,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anonymous Reporting',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Report issues safely and anonymously',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your identity will be completely protected. Only a unique case ID will be generated for tracking.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AnonymousReportingScreen(
                          coordinatorId: coordinatorId,
                          initialReportType: initialReportType,
                          prefilledContent: prefilledContent,
                        ),
                      ),
                    ).then((_) {
                      // Call callback if report was submitted
                      onReportSubmitted?.call();
                    });
                  },
                  icon: const Icon(Icons.report, size: 18),
                  label: const Text('Submit Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              if (showTrackingOption) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AnonymousReportTrackingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.track_changes, size: 18),
                    label: const Text('Track Report'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Quick Report Types
          const Text(
            'Quick Report Types:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildQuickReportChip(
                context,
                'Land Grabbing',
                ReportType.landGrabbing,
                Colors.red,
              ),
              _buildQuickReportChip(
                context,
                'Corruption',
                ReportType.corruption,
                Colors.orange,
              ),
              _buildQuickReportChip(
                context,
                'Harassment',
                ReportType.harassment,
                Colors.purple,
              ),
              _buildQuickReportChip(
                context,
                'Other',
                ReportType.other,
                Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReportChip(
    BuildContext context,
    String label,
    ReportType reportType,
    Color color,
  ) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AnonymousReportingScreen(
              coordinatorId: coordinatorId,
              initialReportType: reportType,
              prefilledContent: prefilledContent,
            ),
          ),
        ).then((_) {
          onReportSubmitted?.call();
        });
      },
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      labelStyle: TextStyle(color: color),
    );
  }
}

// Compact version for smaller spaces
class CompactAnonymousReportWidget extends StatelessWidget {
  final String? coordinatorId;
  final ReportType? initialReportType;
  final VoidCallback? onReportSubmitted;

  const CompactAnonymousReportWidget({
    super.key,
    this.coordinatorId,
    this.initialReportType,
    this.onReportSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(
            Icons.security,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: const Text(
          'Anonymous Report',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Report issues safely and anonymously',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AnonymousReportingScreen(
                coordinatorId: coordinatorId,
                initialReportType: initialReportType,
              ),
            ),
          ).then((_) {
            onReportSubmitted?.call();
          });
        },
      ),
    );
  }
}

// Emergency anonymous report button
class EmergencyAnonymousReportButton extends StatelessWidget {
  final String? coordinatorId;
  final VoidCallback? onReportSubmitted;

  const EmergencyAnonymousReportButton({
    super.key,
    this.coordinatorId,
    this.onReportSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[400]!, Colors.red[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emergency,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 8),
          const Text(
            'EMERGENCY REPORT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Report urgent land rights violations anonymously',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AnonymousReportingScreen(
                    coordinatorId: coordinatorId,
                    initialReportType: ReportType.landGrabbing,
                    prefilledContent: 'EMERGENCY: ',
                  ),
                ),
              ).then((_) {
                onReportSubmitted?.call();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            ),
            child: const Text(
              'REPORT NOW',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

