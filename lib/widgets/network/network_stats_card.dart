// Network Stats Card Widget
// Reference: complete-app-structure.md - Network Features

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NetworkStatsCard extends StatelessWidget {
  final int totalTeamSize;
  final int directReferrals;
  final int monthlyGrowth;
  final String currentRole;

  const NetworkStatsCard({
    super.key,
    required this.totalTeamSize,
    required this.directReferrals,
    this.monthlyGrowth = 0,
    this.currentRole = 'Member',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Network Overview',
              style: AppTheme.heading3Style,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Team Size',
                    totalTeamSize.toString(),
                    'members',
                    Icons.people,
                    AppTheme.talowaGreen,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Direct Referrals',
                    directReferrals.toString(),
                    'people',
                    Icons.person_add,
                    AppTheme.legalBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'This Month',
                    '+$monthlyGrowth',
                    'new members',
                    Icons.trending_up,
                    AppTheme.successGreen,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Current Rank',
                    currentRole.split(' ').first,
                    'Coordinator',
                    Icons.star,
                    AppTheme.warningOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      margin: const EdgeInsets.all(AppTheme.spacingSmall),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.captionStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            value,
            style: AppTheme.heading2Style.copyWith(color: color),
          ),
          Text(
            subtitle,
            style: AppTheme.captionStyle,
          ),
        ],
      ),
    );
  }
}