// Profile Summary Card Widget
// Reference: complete-app-structure.md - Profile Section

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/more/more_screen.dart';

class ProfileSummaryCard extends StatelessWidget {
  final UserProfile userProfile;
  final VoidCallback onTap;

  const ProfileSummaryCard({
    super.key,
    required this.userProfile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Row(
            children: [
              // Profile Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.talowaGreen,
                child: Text(
                  userProfile.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingMedium),
              
              // Profile Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProfile.name,
                      style: AppTheme.heading3Style,
                    ),
                    Text(
                      userProfile.role,
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.talowaGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'ID: ${userProfile.memberId}',
                      style: AppTheme.captionStyle,
                    ),
                    Text(
                      userProfile.phoneNumber,
                      style: AppTheme.captionStyle,
                    ),
                  ],
                ),
              ),
              
              // Arrow Icon
              const Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.secondaryText,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}