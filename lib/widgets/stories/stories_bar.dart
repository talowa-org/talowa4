// Stories Bar Widget - Horizontal scrollable stories
// Instagram-style stories at the top of feed

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/social_feed/story_model.dart';
import '../../services/social_feed/stories_service.dart';
import '../../screens/story/story_creation_screen.dart';
import '../../screens/story/story_viewer_screen.dart';
import 'story_ring.dart';

class StoriesBar extends StatefulWidget {
  final Function(UserStoriesGroup)? onStoryTap;

  const StoriesBar({
    super.key,
    this.onStoryTap,
  });

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  final StoriesService _storiesService = StoriesService();
  List<UserStoriesGroup> _storyGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    setState(() => _isLoading = true);
    
    try {
      final groups = await _storiesService.getActiveStories();
      setState(() {
        _storyGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading stories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    // Always show stories bar with "Add Story" button
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _storyGroups.length + 1, // +1 for "Add Story" button
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStoryButton();
          }
          return _buildStoryItem(_storyGroups[index - 1]);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 60,
                  height: 10,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddStoryButton() {
    return GestureDetector(
      onTap: () async {
        // Navigate to story creation screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StoryCreationScreen(),
          ),
        );
        
        // Reload stories if a story was created
        if (result == true) {
          _loadStories();
        }
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your Story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(UserStoriesGroup group) {
    return GestureDetector(
      onTap: () async {
        // Navigate to story viewer
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewerScreen(storyGroup: group),
          ),
        );
        // Reload stories after viewing
        _loadStories();
        widget.onStoryTap?.call(group);
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            StoryRing(
              hasUnviewedStories: group.hasUnviewedStories,
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: group.userProfileImage != null
                    ? CachedNetworkImageProvider(group.userProfileImage!)
                    : null,
                child: group.userProfileImage == null
                    ? Text(
                        group.userName.isNotEmpty
                            ? group.userName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              group.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
