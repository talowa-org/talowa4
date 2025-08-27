// Goal Progress Card Widget
// Reference: complete-app-structure.md - Network Features

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GoalProgressCard extends StatelessWidget {
  final String currentRole;
  final String nextRole;
  final double progress;
  final int membersNeeded;
  final String estimatedTime;

  const GoalProgressCard({
    super.key,
    required this.currentRole,
    required this.nextRole,
    required this.progress,
    required this.membersNeeded,
    required this.estimatedTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, color: AppTheme.warningOrange),
                SizedBox(width: AppTheme.spacingSmall),
                Text(
                  'Current Goals',
                  style: AppTheme.heading3Style,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              'Next Rank: $nextRole',
              style: AppTheme.bodyLargeStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.talowaGreen,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.talowaGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: _buildProgressItem(
                    'Members Needed',
                    membersNeeded.toString(),
                    Icons.person_add,
                  ),
                ),
                Expanded(
                  child: _buildProgressItem(
                    'Estimated Time',
                    estimatedTime,
                    Icons.schedule,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.secondaryText, size: 16),
        const SizedBox(width: AppTheme.spacingSmall),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTheme.captionStyle,
            ),
            Text(
              value,
              style: AppTheme.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}