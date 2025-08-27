// Stories Row Widget for Feed
// Reference: social-feed-implementation-plan.md - Stories Feature

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StoriesRow extends StatelessWidget {
  final List<FeedStory> stories;
  final Function(FeedStory) onStoryTap;
  final VoidCallback onCreateStory;

  const StoriesRow({
    super.key,
    required this.stories,
    required this.onStoryTap,
    required this.onCreateStory,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      itemCount: stories.length + 1, // +1 for create story button
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildCreateStoryButton();
        }
        
        final story = stories[index - 1];
        return _buildStoryItem(story);
      },
    );
  }

  Widget _buildCreateStoryButton() {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: AppTheme.spacingSmall),
      child: Column(
        children: [
          GestureDetector(
            onTap: onCreateStory,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.talowaGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          const Text(
            'Your Story',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryItem(FeedStory story) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: AppTheme.spacingSmall),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => onStoryTap(story),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.talowaGreen, width: 2),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.talowaGreen,
                child: Text(
                  story.authorName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            story.authorName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}