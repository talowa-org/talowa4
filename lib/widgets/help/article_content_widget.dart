// TALOWA Article Content Widget
// Displays formatted article content

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ArticleContentWidget extends StatelessWidget {
  final String content;

  const ArticleContentWidget({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        content,
        style: const TextStyle(
          fontSize: 15,
          color: AppTheme.primaryText,
          height: 1.6,
        ),
      ),
    );
  }
}
