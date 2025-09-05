// Feed Debug Screen - Debug and test the feed functionality
// Provides tools to create test posts, check media URLs, and debug feed issues

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/app_theme.dart';
import '../../services/social_feed/test_post_creation_service.dart';
import '../../services/social_feed/feed_service.dart';
import '../../models/social_feed/post_model.dart';

class FeedDebugScreen extends StatefulWidget {
  const FeedDebugScreen({super.key});

  @override
  State<FeedDebugScreen> createState() => _FeedDebugScreenState();
}

class _FeedDebugScreenState extends State<FeedDebugScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  List<PostModel> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading posts...';
    });

    try {
      final posts = await FeedService().getFeedPosts(limit: 10);
      setState(() {
        _posts = posts;
        _statusMessage = 'Loaded ${posts.length} posts';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading posts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createTestPosts() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating test posts...';
    });

    try {
      await TestPostCreationService.createTestPosts();
      setState(() {
        _statusMessage = 'Test posts created successfully!';
        _isLoading = false;
      });
      
      // Reload posts
      await _loadPosts();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating test posts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _clearTestPosts() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Clearing test posts...';
    });

    try {
      await TestPostCreationService.clearTestPosts();
      setState(() {
        _statusMessage = 'Test posts cleared successfully!';
        _isLoading = false;
      });
      
      // Reload posts
      await _loadPosts();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error clearing test posts: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed Debug'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Debug info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Feed Debug Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Debug Mode: ${kDebugMode ? "ON" : "OFF"}'),
                    Text('Posts Loaded: ${_posts.length}'),
                    Text('Status: $_statusMessage'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createTestPosts,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Test Posts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.talowaGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadPosts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload Posts'),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _clearTestPosts,
                      icon: const Icon(Icons.delete),
                      label: const Text('Clear Test Posts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Posts list
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Current Posts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _posts.isEmpty
                              ? const Center(
                                  child: Text('No posts found. Create some test posts!'),
                                )
                              : ListView.builder(
                                  itemCount: _posts.length,
                                  itemBuilder: (context, index) {
                                    final post = _posts[index];
                                    return ListTile(
                                      title: Text(
                                        post.title ?? post.content.substring(0, 50) + '...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Author: ${post.authorName}'),
                                          Text('Category: ${post.category.displayName}'),
                                          Text('Media URLs: ${post.allMediaUrls.length}'),
                                          if (post.allMediaUrls.isNotEmpty)
                                            Text(
                                              'First URL: ${post.allMediaUrls.first.substring(0, 50)}...',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('â¤ï¸ ${post.likesCount}'),
                                          Text('ðŸ’¬ ${post.commentsCount}'),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

