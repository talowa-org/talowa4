// Referral Tree Widget
// Reference: privacy-contact-visibility-system.md - Network Tree

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/network/network_screen.dart';

class ReferralTreeWidget extends StatelessWidget {
  final NetworkData networkData;
  final Function(String) onNodeTap;

  const ReferralTreeWidget({
    super.key,
    required this.networkData,
    required this.onNodeTap,
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
              'Network Tree',
              style: AppTheme.heading3Style,
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            
            // Root Node (User)
            _buildRootNode(),
            
            const SizedBox(height: AppTheme.spacingLarge),
            
            // Direct Referrals (Visible with contacts)
            if (networkData.directReferralsList.isNotEmpty)
              _buildDirectReferralsLevel(),
            
            const SizedBox(height: AppTheme.spacingLarge),
            
            // Indirect Referrals (Anonymous counts only)
            _buildIndirectReferralsLevel(),
          ],
        ),
      ),
    );
  }

  Widget _buildRootNode() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.talowaGreen,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.talowaGreen, width: 3),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            'You',
            style: AppTheme.bodyLargeStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            networkData.currentRole,
            style: AppTheme.captionStyle,
          ),
          Text(
            '${networkData.totalTeamSize} Total',
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.talowaGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectReferralsLevel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Direct Referrals (Full Contact Visible)',
          style: AppTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.talowaGreen,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: networkData.directReferralsList.take(3).map((referral) =>
            _buildDirectReferralNode(referral)
          ).toList(),
        ),
        if (networkData.directReferralsList.length > 3) ...[
          const SizedBox(height: AppTheme.spacingSmall),
          Center(
            child: TextButton(
              onPressed: () => onNodeTap('view_all_direct'),
              child: Text(
                'View All ${networkData.directReferrals} Direct Referrals',
                style: const TextStyle(color: AppTheme.talowaGreen),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDirectReferralNode(TeamMember referral) {
    return GestureDetector(
      onTap: () => onNodeTap(referral.name),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.legalBlue,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.legalBlue, width: 2),
            ),
            child: Center(
              child: Text(
                referral.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            referral.name.split(' ').first,
            style: AppTheme.captionStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '📞 98765***',
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.talowaGreen,
            ),
          ),
          Text(
            '${referral.referrals} refs',
            style: AppTheme.captionStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildIndirectReferralsLevel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Indirect Referrals (Contact Info Hidden)',
          style: AppTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.secondaryText,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAnonymousNode('8 members', 'Level 2'),
            _buildAnonymousNode('5 members', 'Level 2'),
            _buildAnonymousNode('3 members', 'Level 2'),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          decoration: BoxDecoration(
            color: AppTheme.secondaryText.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: AppTheme.secondaryText.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppTheme.secondaryText,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: Text(
                  'Contact details hidden for privacy protection. You can only see contact info of people you directly referred.',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnonymousNode(String count, String level) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.secondaryText.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.secondaryText.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.people,
            color: AppTheme.secondaryText,
            size: 24,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Text(
          count,
          style: AppTheme.captionStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Contact Info',
          style: AppTheme.captionStyle.copyWith(
            color: AppTheme.secondaryText,
          ),
        ),
        Text(
          'Hidden',
          style: AppTheme.captionStyle.copyWith(
            color: AppTheme.secondaryText,
          ),
        ),
      ],
    );
  }
}


