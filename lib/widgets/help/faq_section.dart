// TALOWA FAQ Section Widget
// Displays frequently asked questions in an expandable format

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/help/help_article.dart';

class FAQSection extends StatefulWidget {
  final List<HelpArticle> articles;
  final Function(HelpArticle) onArticleTap;

  const FAQSection({
    super.key,
    required this.articles,
    required this.onArticleTap,
  });

  @override
  State<FAQSection> createState() => _FAQSectionState();
}

class _FAQSectionState extends State<FAQSection> {
  final Set<String> _expandedArticles = {};

  void _toggleExpanded(String articleId) {
    setState(() {
      if (_expandedArticles.contains(articleId)) {
        _expandedArticles.remove(articleId);
      } else {
        _expandedArticles.add(articleId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No FAQs available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quick answers to common questions about TALOWA',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),

          // FAQ items
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.articles.length,
            itemBuilder: (context, index) {
              final article = widget.articles[index];
              final isExpanded = _expandedArticles.contains(article.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    // Question header
                    InkWell(
                      onTap: () => _toggleExpanded(article.id),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                        bottom: Radius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // FAQ icon
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.talowaGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.help_outline,
                                color: AppTheme.talowaGreen,
                                size: 18,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Question text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryText,
                                    ),
                                  ),
                                  if (!isExpanded) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      article.content.length > 80
                                          ? '${article.content.substring(0, 80)}...'
                                          : article.content,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Expand/collapse icon
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Answer content (expandable)
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // Answer content
                            Text(
                              article.content,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.secondaryText,
                                height: 1.5,
                              ),
                            ),

                            // Steps (if available)
                            if (article.steps.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Steps:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...article.steps.asMap().entries.map((entry) {
                                final index = entry.key;
                                final step = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: AppTheme.talowaGreen,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          step,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.secondaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],

                            const SizedBox(height: 16),

                            // Action buttons
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => widget.onArticleTap(article),
                                  icon: const Icon(
                                    Icons.article_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Read Full Article'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.talowaGreen,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  article.readTimeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}