// Simple Feed Screen - Basic version for testing
// Simplified version to test feed functionality without complex dependencies

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/post_model.dart';
import '../../widgets/common/loading_widget.dart';

class SimpleFeedScreen extends StatefulWidget {
  const SimpleFeedScreen({super.key});

  @override
  State<SimpleFeedScreen> createState() => _SimpleFeedScreenState();
}

class _SimpleFeedScreenState extends State<SimpleFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  List<PostModel> _posts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMockPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMockPosts() {
    setState(() {
      _isLoading = true;
    });

    // Create mock posts for testing
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _posts = _createMockPosts();
          _isLoading = false;
        });
      }
    });
  }

  List<PostModel> _createMockPosts() {
    return [
      PostModel(
        id: '1',
        authorId: 'user1',
        authorName: 'राम कुमार',
        authorRole: 'village_coordinator',
        title: 'भूमि सर्वेक्षण की जानकारी',
        content: 'आज हमारे गांव में भूमि सर्वेक्षण का काम शुरू हुआ है। सभी किसान भाई अपने दस्तावेज तैयार रखें। #भूमि_अधिकार #सर्वेक्षण',
        hashtags: ['भूमि_अधिकार', 'सर्वेक्षण'],
        category: PostCategory.announcement,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        likesCount: 15,
        commentsCount: 3,
        sharesCount: 2,
      ),
      PostModel(
        id: '2',
        authorId: 'user2',
        authorName: 'सुनीता देवी',
        authorRole: 'member',
        title: 'सफलता की कहानी',
        content: 'मुझे आज अपना पट्टा मिल गया! TALOWA की मदद से यह संभव हुआ। धन्यवाद! #सफलता #पट्टा_मिला',
        hashtags: ['सफलता', 'पट्टा_मिला'],
        category: PostCategory.successStory,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        likesCount: 42,
        commentsCount: 8,
        sharesCount: 12,
      ),
      PostModel(
        id: '3',
        authorId: 'user3',
        authorName: 'अजय सिंह',
        authorRole: 'mandal_coordinator',
        title: 'कानूनी अपडेट',
        content: 'नया भूमि अधिकार कानून पास हुआ है। सभी सदस्यों को इसकी जानकारी दी जा रही है। #कानूनी_अपडेट #भूमि_कानून',
        hashtags: ['कानूनी_अपडेट', 'भूमि_कानून'],
        category: PostCategory.legalUpdate,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        likesCount: 28,
        commentsCount: 15,
        sharesCount: 6,
      ),
      PostModel(
        id: '4',
        authorId: 'user4',
        authorName: 'प्रिया शर्मा',
        authorRole: 'volunteer',
        title: 'आपातकालीन सूचना',
        content: 'कल सुबह 10 बजे गांव में महत्वपूर्ण बैठक है। सभी सदस्य उपस्थित रहें। #आपातकाल #बैठक',
        hashtags: ['आपातकाल', 'बैठक'],
        category: PostCategory.emergency,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        likesCount: 8,
        commentsCount: 2,
        sharesCount: 4,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.eco, color: Colors.white, size: 32),
          SizedBox(width: 8),
          Text(
            'TALOWA Feed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.talowaGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _showSearchDialog,
          icon: const Icon(Icons.search),
          tooltip: 'Search',
        ),
        IconButton(
          onPressed: _showFilterDialog,
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading feed...');
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadMockPosts();
      },
      color: AppTheme.talowaGreen,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(post.authorRole),
                  child: Text(
                    post.authorName.isNotEmpty ? post.authorName[0] : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (post.authorRole != null) ...[
                            const SizedBox(width: 8),
                            _buildRoleBadge(post.authorRole!),
                          ],
                        ],
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCategoryBadge(post.category),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            if (post.title != null) ...[
              Text(
                post.title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Content
            Text(
              post.content,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),

            // Hashtags
            if (post.hashtags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: post.hashtags.map((hashtag) => InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hashtag: #$hashtag')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.talowaGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.talowaGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '#$hashtag',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.talowaGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // Engagement
            Row(
              children: [
                _buildEngagementButton(
                  icon: Icons.favorite_border,
                  count: post.likesCount,
                  label: 'Like',
                  onTap: () => _handleLike(post),
                ),
                _buildEngagementButton(
                  icon: Icons.comment_outlined,
                  count: post.commentsCount,
                  label: 'Comment',
                  onTap: () => _handleComment(post),
                ),
                _buildEngagementButton(
                  icon: Icons.share_outlined,
                  count: post.sharesCount,
                  label: 'Share',
                  onTap: () => _handleShare(post),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final roleInfo = _getRoleInfo(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: roleInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: roleInfo['color'].withOpacity(0.3),
        ),
      ),
      child: Text(
        roleInfo['label'],
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: roleInfo['color'],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(PostCategory category) {
    final categoryInfo = _getCategoryInfo(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: categoryInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryInfo['color'].withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            categoryInfo['icon'],
            size: 12,
            color: categoryInfo['color'],
          ),
          const SizedBox(width: 4),
          Text(
            categoryInfo['label'],
            style: TextStyle(
              fontSize: 10,
              color: categoryInfo['color'],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementButton({
    required IconData icon,
    required int count,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to TALOWA!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with your community and start sharing your land rights journey.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMockPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Load Posts'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showCreatePostDialog,
      backgroundColor: AppTheme.talowaGreen,
      foregroundColor: Colors.white,
      tooltip: 'Create Post',
      heroTag: "feed_create_post", // Unique hero tag
      child: const Icon(Icons.add),
    );
  }

  // Event handlers
  void _handleLike(PostModel post) {
    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = post.copyWith(
          likesCount: post.likesCount + 1,
        );
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Liked post by ${post.authorName}')),
    );
  }

  void _handleComment(PostModel post) {
    _showCommentsDialog(post);
  }

  void _handleShare(PostModel post) {
    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = post.copyWith(
          sharesCount: post.sharesCount + 1,
        );
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shared post by ${post.authorName}')),
    );
  }

  // Helper methods
  Map<String, dynamic> _getRoleInfo(String role) {
    switch (role.toLowerCase()) {
      case 'village_coordinator':
        return {'label': 'Village Coordinator', 'color': Colors.orange};
      case 'mandal_coordinator':
        return {'label': 'Mandal Coordinator', 'color': Colors.green};
      case 'district_coordinator':
        return {'label': 'District Coordinator', 'color': Colors.blue};
      case 'volunteer':
        return {'label': 'Volunteer', 'color': Colors.teal};
      default:
        return {'label': 'Member', 'color': Colors.grey};
    }
  }

  Color _getRoleColor(String? role) {
    return _getRoleInfo(role ?? 'member')['color'];
  }

  Map<String, dynamic> _getCategoryInfo(PostCategory category) {
    switch (category) {
      case PostCategory.successStory:
        return {'label': 'Success Story', 'icon': Icons.celebration, 'color': Colors.green};
      case PostCategory.legalUpdate:
        return {'label': 'Legal Update', 'icon': Icons.gavel, 'color': Colors.blue};
      case PostCategory.announcement:
        return {'label': 'Announcement', 'icon': Icons.campaign, 'color': Colors.orange};
      case PostCategory.emergency:
        return {'label': 'Emergency', 'icon': Icons.warning, 'color': Colors.red};
      case PostCategory.generalDiscussion:
        return {'label': 'Discussion', 'icon': Icons.forum, 'color': Colors.purple};
      case PostCategory.landRights:
        return {'label': 'Land Rights', 'icon': Icons.landscape, 'color': Colors.brown};
      case PostCategory.communityNews:
        return {'label': 'Community News', 'icon': Icons.newspaper, 'color': Colors.teal};
      default:
        return {'label': 'General', 'icon': Icons.article, 'color': Colors.grey};
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // Dialog implementations
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Posts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search for posts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (query) {
                Navigator.pop(context);
                _performSearch(query);
              },
            ),
            const SizedBox(height: 16),
            const Text('Popular searches:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['भूमि_अधिकार', 'सफलता', 'कानूनी_अपडेट', 'आपातकाल']
                  .map((tag) => ActionChip(
                        label: Text('#$tag'),
                        onPressed: () {
                          Navigator.pop(context);
                          _performSearch(tag);
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Posts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Category:'),
            const SizedBox(height: 8),
            ...PostCategory.values.map((category) {
              final info = _getCategoryInfo(category);
              return CheckboxListTile(
                title: Text(info['label']),
                subtitle: Text('Show ${info['label'].toLowerCase()} posts'),
                value: true, // For demo, all are selected
                onChanged: (value) {
                  // Filter implementation would go here
                },
              );
            }),
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
                const SnackBar(content: Text('Filters applied!')),
              );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    PostCategory selectedCategory = PostCategory.generalDiscussion;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Post Title (Optional)',
                    hintText: 'Enter a catchy title...',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Post Content',
                    hintText: 'What would you like to share?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: 16),
                const Text('Category:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<PostCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: PostCategory.values.map((category) {
                    final info = _getCategoryInfo(category);
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(info['icon'], size: 16, color: info['color']),
                          const SizedBox(width: 8),
                          Text(info['label']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (contentController.text.trim().isNotEmpty) {
                  _createNewPost(
                    title: titleController.text.trim().isEmpty 
                        ? null 
                        : titleController.text.trim(),
                    content: contentController.text.trim(),
                    category: selectedCategory,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter post content')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentsDialog(PostModel post) {
    final commentController = TextEditingController();
    final List<Map<String, dynamic>> comments = [
      {
        'author': 'राज कुमार',
        'content': 'बहुत अच्छी जानकारी है!',
        'time': DateTime.now().subtract(const Duration(minutes: 30)),
      },
      {
        'author': 'सुमित्रा देवी',
        'content': 'धन्यवाद इस जानकारी के लिए।',
        'time': DateTime.now().subtract(const Duration(hours: 1)),
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Comments (${post.commentsCount})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Comments list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.talowaGreen,
                        child: Text(
                          comment['author'][0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(comment['author']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(comment['content']),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(comment['time']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Comment liked!')),
                          );
                        },
                        icon: const Icon(Icons.favorite_border, size: 16),
                      ),
                    );
                  },
                ),
              ),
              
              // Comment input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.talowaGreen,
                      child: Icon(Icons.person, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText: 'Write a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, 
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (commentController.text.trim().isNotEmpty) {
                          setState(() {
                            final index = _posts.indexWhere((p) => p.id == post.id);
                            if (index != -1) {
                              _posts[index] = post.copyWith(
                                commentsCount: post.commentsCount + 1,
                              );
                            }
                          });
                          commentController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Comment added!')),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.send,
                        color: AppTheme.talowaGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performSearch(String query) {
    final filteredPosts = _posts.where((post) =>
        post.content.toLowerCase().contains(query.toLowerCase()) ||
        post.title?.toLowerCase().contains(query.toLowerCase()) == true ||
        post.hashtags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()))
    ).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found ${filteredPosts.length} posts for "$query"'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            setState(() {
              _posts = filteredPosts;
            });
          },
        ),
      ),
    );
  }

  void _createNewPost({
    String? title,
    required String content,
    required PostCategory category,
  }) {
    final newPost = PostModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorId: 'current_user',
      authorName: 'आप',
      authorRole: 'member',
      title: title,
      content: content,
      hashtags: _extractHashtags(content),
      category: category,
      createdAt: DateTime.now(),
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
    );

    setState(() {
      _posts.insert(0, newPost);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  List<String> _extractHashtags(String content) {
    final RegExp hashtagRegex = RegExp(r'#[\w\u0900-\u097F\u0C00-\u0C7F_]+');
    return hashtagRegex
        .allMatches(content)
        .map((match) => match.group(0)!.substring(1))
        .toList();
  }
}