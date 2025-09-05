// Feature Section Card Widget
// Reference: complete-app-structure.md - More Tab

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/more/more_screen.dart';

class FeatureSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<FeatureItem> items;

  const FeatureSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: AppTheme.spacingSmall),
                Text(
                  title,
                  style: AppTheme.heading3Style,
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMedium),
            
            // Feature Items
            ...items.map((item) => _buildFeatureItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(FeatureItem item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.icon,
        color: iconColor,
        size: 24,
      ),
      title: Text(
        item.title,
        style: AppTheme.bodyLargeStyle,
      ),
      subtitle: Text(
        item.subtitle,
        style: AppTheme.bodyStyle.copyWith(
          color: AppTheme.secondaryText,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: AppTheme.secondaryText,
        size: 16,
      ),
      onTap: item.onTap,
    );
  }
}
