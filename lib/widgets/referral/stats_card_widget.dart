// Referral Stats Card Widget for Talowa
// Displays referral statistics in a clean card format

import 'package:flutter/material.dart';
import '../../models/role_model.dart';
import '../../core/theme/app_theme.dart';

class StatsCardWidget extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color? color;
  final String? subtitle;

  const StatsCardWidget({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.secondaryText,
                  ),
                ),
                Icon(
                  icon,
                  size: 20,
                  color: color ?? AppTheme.talowaGreen,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReferralStatsRow extends StatelessWidget {
  final int directReferrals;
  final int teamReferrals;
  final int currentRoleLevel;

  const ReferralStatsRow({
    super.key,
    required this.directReferrals,
    required this.teamReferrals,
    required this.currentRoleLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatsCardWidget(
            title: 'Direct Referrals',
            value: directReferrals,
            icon: Icons.person_add,
            color: Colors.blue,
            subtitle: 'People you invited',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatsCardWidget(
            title: 'Team Size',
            value: teamReferrals,
            icon: Icons.groups,
            color: Colors.green,
            subtitle: 'Total downline',
          ),
        ),
      ],
    );
  }
}

class RoleProgressCard extends StatelessWidget {
  final int currentRoleLevel;
  final int directReferrals;
  final int teamReferrals;

  const RoleProgressCard({
    super.key,
    required this.currentRoleLevel,
    required this.directReferrals,
    required this.teamReferrals,
  });

  @override
  Widget build(BuildContext context) {
    final currentRole = TalowaRoles.getRoleByLevel(currentRoleLevel);
    final nextRole = TalowaRoles.getNextRole(currentRoleLevel);

    if (currentRole == null) {
      return const SizedBox.shrink();
    }

    // Don't show progress for admin
    if (currentRoleLevel == 0) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                currentRole.icon,
                size: 24,
                color: currentRole.color,
              ),
              const SizedBox(width: 12),
              Text(
                currentRole.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (nextRole == null) {
      // Already at max level
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    currentRole.icon,
                    size: 24,
                    color: currentRole.color,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    currentRole.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'MAX LEVEL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'You have reached the highest level!',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate progress based on both direct and team requirements
    double directProgress = nextRole.directReferralsNeeded > 0 
        ? (directReferrals / nextRole.directReferralsNeeded).clamp(0.0, 1.0)
        : 1.0;
    
    double teamProgress = nextRole.teamReferralsNeeded > 0 
        ? (teamReferrals / nextRole.teamReferralsNeeded).clamp(0.0, 1.0)
        : 1.0;

    // Overall progress is the minimum of both requirements
    double progress = (directProgress * teamProgress).clamp(0.0, 1.0);
    
    // Generate progress text based on what's needed
    String progressText = '';
    final directNeeded = (nextRole.directReferralsNeeded - directReferrals).clamp(0, double.infinity).toInt();
    final teamNeeded = (nextRole.teamReferralsNeeded - teamReferrals).clamp(0, double.infinity).toInt();

    if (directNeeded > 0 && teamNeeded > 0) {
      progressText = 'Need $directNeeded direct & $teamNeeded team members';
    } else if (directNeeded > 0) {
      progressText = 'Need $directNeeded more direct referrals';
    } else if (teamNeeded > 0) {
      progressText = 'Need $teamNeeded more team members';
    } else {
      progressText = 'Ready for promotion to ${nextRole.name}!';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  currentRole.icon,
                  size: 20,
                  color: currentRole.color,
                ),
                const SizedBox(width: 8),
                Text(
                  currentRole.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.secondaryText,
                  ),
                ),
                const Spacer(),
                Icon(
                  nextRole.icon,
                  size: 20,
                  color: nextRole.color,
                ),
                const SizedBox(width: 8),
                Text(
                  nextRole.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(nextRole.color),
            ),
            const SizedBox(height: 8),
            Text(
              progressText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}