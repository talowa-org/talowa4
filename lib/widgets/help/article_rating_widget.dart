// TALOWA Article Rating Widget
// Allows users to rate help articles

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/help/help_article.dart';

class ArticleRatingWidget extends StatefulWidget {
  final HelpArticle article;
  final Function(int) onRated;

  const ArticleRatingWidget({
    super.key,
    required this.article,
    required this.onRated,
  });

  @override
  State<ArticleRatingWidget> createState() => _ArticleRatingWidgetState();
}

class _ArticleRatingWidgetState extends State<ArticleRatingWidget> {
  int _selectedRating = 0;
  bool _hasRated = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: _hasRated ? null : () => _ratArticle(starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starIndex <= _selectedRating
                        ? Icons.star
                        : Icons.star_border,
                    color: starIndex <= _selectedRating
                        ? Colors.amber
                        : Colors.grey[400],
                    size: 32,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),

          // Rating text
          if (_hasRated)
            Text(
              'Thank you for rating this article!',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.talowaGreen,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              'Tap the stars to rate this article',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),

          // Quick feedback buttons (if not rated yet)
          if (!_hasRated) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickFeedbackButton(
                  icon: Icons.thumb_up,
                  label: 'Helpful',
                  color: Colors.green,
                  onTap: () => _ratArticle(5),
                ),
                _QuickFeedbackButton(
                  icon: Icons.thumb_down,
                  label: 'Not Helpful',
                  color: Colors.red,
                  onTap: () => _ratArticle(2),
                ),
              ],
            ),
          ],

          // Additional feedback (if rated)
          if (_hasRated) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _showFeedbackDialog,
                  icon: const Icon(Icons.comment, size: 16),
                  label: const Text('Add Comment'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.talowaGreen,
                  ),
                ),
                TextButton.icon(
                  onPressed: _shareArticle,
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.talowaGreen,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _ratArticle(int rating) {
    setState(() {
      _selectedRating = rating;
      _hasRated = true;
    });
    widget.onRated(rating);
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Additional Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Help us improve this article:'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Your feedback...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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

  void _shareArticle() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Article sharing feature coming soon'),
      ),
    );
  }
}

class _QuickFeedbackButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickFeedbackButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}