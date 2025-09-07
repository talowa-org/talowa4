// TALOWA Help Article Screen
// Displays detailed help articles with screenshots and step-by-step guides
// Reference: in-app-communication/requirements.md - Requirements 2.2, 3.1, 9.1

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/help/help_article.dart';
import '../../widgets/help/article_content_widget.dart';
import '../../widgets/help/article_steps_widget.dart';
import '../../widgets/help/article_screenshots_widget.dart';
import '../../widgets/help/article_rating_widget.dart';

class HelpArticleScreen extends StatefulWidget {
  final HelpArticle article;

  const HelpArticleScreen({
    super.key,
    required this.article,
  });

  @override
  State<HelpArticleScreen> createState() => _HelpArticleScreenState();
}

class _HelpArticleScreenState extends State<HelpArticleScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showFloatingButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showButton = _scrollController.offset > 200;
    if (showButton != _showFloatingButton) {
      setState(() {
        _showFloatingButton = showButton;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _shareArticle() {
    // In a real app, this would use the share plugin
    Clipboard.setData(ClipboardData(
      text: 'Check out this TALOWA help article: ${widget.article.title}\n\n${widget.article.content}',
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Article content copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _reportIssue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What\'s wrong with this article?'),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Information is outdated'),
              value: false,
              onChanged: (value) {},
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Steps don\'t work'),
              value: false,
              onChanged: (value) {},
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Screenshots are missing'),
              value: false,
              onChanged: (value) {},
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Other issue'),
              value: false,
              onChanged: (value) {},
              dense: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: AppTheme.talowaGreen,
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.article.title,
          style: const TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareArticle,
            tooltip: 'Share Article',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'report':
                  _reportIssue();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag),
                    SizedBox(width: 8),
                    Text('Report Issue'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.talowaGreen.withValues(alpha: 0.2),
                    AppTheme.talowaGreen.withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Article metadata
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.talowaGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.article.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.talowaGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.article.readTimeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (widget.article.isFAQ) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FAQ',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Article title
                  Text(
                    widget.article.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Article tags
                  if (widget.article.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.article.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            // Article content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main content
                  ArticleContentWidget(content: widget.article.content),

                  const SizedBox(height: 24),

                  // Screenshots section
                  if (widget.article.screenshots.isNotEmpty) ...[
                    const Text(
                      'Screenshots',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ArticleScreenshotsWidget(
                      screenshots: widget.article.screenshots,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Steps section
                  if (widget.article.steps.isNotEmpty) ...[
                    const Text(
                      'Step-by-Step Guide',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ArticleStepsWidget(steps: widget.article.steps),
                    const SizedBox(height: 24),
                  ],

                  // Video section (if available)
                  if (widget.article.videoUrl != null) ...[
                    const Text(
                      'Video Guide',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Video guide available',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              // In a real app, this would open the video player
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Video player would open here'),
                                ),
                              );
                            },
                            child: const Text('Watch Video'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Rating section
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Was this article helpful?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ArticleRatingWidget(
                    article: widget.article,
                    onRated: (rating) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Thank you for rating this article $rating stars!'),
                          backgroundColor: AppTheme.talowaGreen,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Feedback section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Need more help?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'If this article didn\'t answer your question, you can:',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  // Navigate to contact support
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Contact support feature coming soon'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.support_agent, size: 16),
                                label: const Text('Contact Support'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.talowaGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  // Navigate back to help center
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.search, size: 16),
                                label: const Text('Search More'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.talowaGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bottom spacing
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showFloatingButton
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
              mini: true,
              child: const Icon(Icons.keyboard_arrow_up),
            )
          : null,
    );
  }
}


