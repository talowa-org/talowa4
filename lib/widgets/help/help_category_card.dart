// TALOWA Help Category Card Widget
// Displays help categories with article counts and navigation

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/help/help_category.dart';

class HelpCategoryCard extends StatelessWidget {
  final HelpCategory category;
  final VoidCallback onTap;

  const HelpCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.accentColor?.withOpacity(0.1) ?? 
                         AppTheme.talowaGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.iconData,
                  color: category.accentColor ?? AppTheme.talowaGreen,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Category info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${category.articleCount} articles',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (category.faqArticles.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.help_outline,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${category.faqArticles.length} FAQs',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        if (category.totalReadTime > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            category.totalReadTimeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}