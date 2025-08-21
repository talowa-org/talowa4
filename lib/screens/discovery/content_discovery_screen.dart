// Content Discovery Screen - Main discovery interface
// Part of Task 8: Create content discovery features

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../services/social_feed/index.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/discovery/trending_hashtags_widget.dart';
import '../../widgets/discovery/category_filter_widget.dart';
import '../../widgets/discovery/geographic_discovery_widget.dart';
import '../../widgets/discovery/recommended_content_widget.dart';
import '../../widgets/feed/post_widget.dart';

class ContentDiscoveryScreen extends StatefulWidget {
  const ContentDiscoveryScreen({super.key});

  @override
  State<ContentDiscoveryScreen> createState() => _ContentDiscoveryScreenState();
}

class _ContentDiscoveryScreenState extends State<ContentDiscoveryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Discovery data
  List<String> _trendingHashtags = [];
  List<PostCategory> _availableCategories = [];
  List<PostModel> _recommendedPosts = [];
  List<PostModel> _geographicPosts = [];
  
  // State management
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  
  // Filters
  PostCategory? _selectedCategory;
  String? _selectedHashtag;
  GeographicScope _geographicScope = GeographicScope.village;

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 4, vsync: this);
    _loadDiscoveryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up), text: 'Trending'),
            Tab(icon: Icon(Icons.category), text: 'Categories'),
            Tab(icon: Icon(Icons.location_on), text: 'Nearby'),
            Tab(icon: Icon(Icons.recommend), text: 'For You'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: _openFilters,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Discovering content...')
          : _hasError
              ? CustomErrorWidget(
                  message: _errorMessage ?? 'Failed to load discovery content',
                  onRetry: _loadDiscoveryData,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTrendingTab(),
                    _buildCategoriesTab(),
                    _buildGeographicTab(),
                    _buildRecommendedTab(),
                  ],
                ),
    );
  }

  Widget _buildTrendingTab() {
    return RefreshIndicator(
      onRefresh: _loadDiscoveryData,
      color: AppTheme.talowaGreen,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        children: [
          // Trending hashtags section
          _buildSectionHeader(
            'Trending Hashtags',
            Icons.trending_up,
            onViewAll: _viewAllHashtags,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          TrendingHashtagsWidget(
            hashtags: _trendingHashtags,
            onHashtagTap: _selectHashtag,
          ),
          
          const SizedBox(height: AppTheme.spacingLarge),
          
          // Trending posts section
          _buildSectionHeader(
            'Trending Posts',
            Icons.whatshot,
            onViewAll: _viewAllTrending,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          _buildTrendingPosts(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return RefreshIndicator(
      onRefresh: _loadDiscoveryData,
      color: AppTheme.talowaGreen,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        children: [
          // Category filter
          CategoryFilterWidget(
            categories: _availableCategories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _selectCategory,
          ),
          
          const SizedBox(height: AppTheme.spacingLarge),
          
          // Category posts
          if (_selectedCategory != null) ...[
            _buildSectionHeader(
              '${_selectedCategory!.displayName} Posts',
              _selectedCategory!.icon,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            _buildCategoryPosts(),
          ] else
            _buildAllCategoriesOverview(),
        ],
      ),
    );
  }

  Widget _buildGeographicTab() {
    return RefreshIndicator(
      onRefresh: _loadDiscoveryData,
      color: AppTheme.talowaGreen,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        children: [
          // Geographic scope selector
          GeographicDiscoveryWidget(
            selectedScope: _geographicScope,
            onScopeChanged: _changeGeographicScope,
          ),
          
          const SizedBox(height: AppTheme.spacingLarge),
          
          // Geographic posts
          _buildSectionHeader(
            'Posts from ${_geographicScope.displayName}',
            Icons.location_on,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          _buildGeographicPosts(),
        ],
      ),
    );
  }

  Widget _buildRecommendedTab() {
    return RefreshIndicator(
      onRefresh: _loadDiscoveryData,
      color: AppTheme.talowaGreen,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        children: [
          // Recommended content widget
          RecommendedContentWidget(
            posts: _recommendedPosts,
            onPostTap: _openPost,
            onRefresh: _loadRecommendedContent,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    VoidCallback? onViewAll,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.talowaGreen, size: 20),
        const SizedBox(width: AppTheme.spacingSmall),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text('View All'),
          ),
      ],
    );
  }

  Widget _buildTrendingPosts() {
    // TODO: Implement trending posts display
    return const SizedBox(
      height: 200,
      child: Center(
        child: Text('Trending posts will be displayed here'),
      ),
    );
  }

  Widget _buildCategoryPosts() {
    // TODO: Implement category-specific posts
    return const SizedBox(
      height: 200,
      child: Center(
        child: Text('Category posts will be displayed here'),
      ),
    );
  }

  Widget _buildAllCategoriesOverview() {
    return Column(
      children: [
        const Text(
          'Select a category above to discover relevant content',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingLarge),
        // Category overview cards
        ...PostCategory.values.map((category) => Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
          child: ListTile(
            leading: Icon(category.icon, color: AppTheme.talowaGreen),
            title: Text(category.displayName),
            subtitle: Text(category.description),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _selectCategory(category),
          ),
        )),
      ],
    );
  }

  Widget _buildGeographicPosts() {
    if (_geographicPosts.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('No posts found in your area'),
        ),
      );
    }

    return Column(
      children: _geographicPosts.map((post) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
        child: PostWidget(
          post: post,
          onLike: () => _likePost(post),
          onComment: () => _openComments(post),
          onShare: () => _sharePost(post),
          onUserTap: () => _openUserProfile(post.authorId),
        ),
      )).toList(),
    );
  }

  // Data loading methods
  Future<void> _loadDiscoveryData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Load all discovery data in parallel
      final results = await Future.wait([
        _loadTrendingHashtags(),
        _loadAvailableCategories(),
        _loadRecommendedContent(),
        _loadGeographicContent(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadTrendingHashtags() async {
    try {
      _trendingHashtags = await FeedService.getTrendingHashtags(limit: 10);
    } catch (e) {
      debugPrint('Error loading trending hashtags: $e');
    }
  }

  Future<void> _loadAvailableCategories() async {
    _availableCategories = PostCategory.values;
  }

  Future<void> _loadRecommendedContent() async {
    try {
      _recommendedPosts = await FeedService.getRecommendedPosts(
        userId: 'current_user_id', // TODO: Get actual user ID
        limit: 20,
      );
    } catch (e) {
      debugPrint('Error loading recommended content: $e');
    }
  }

  Future<void> _loadGeographicContent() async {
    try {
      _geographicPosts = await FeedService.getGeographicPosts(
        scope: _geographicScope,
        userLocation: 'current_user_location', // TODO: Get actual location
        limit: 20,
      );
    } catch (e) {
      debugPrint('Error loading geographic content: $e');
    }
  }

  // Event handlers
  void _selectHashtag(String hashtag) {
    setState(() {
      _selectedHashtag = hashtag;
    });
    // TODO: Navigate to hashtag posts screen
    debugPrint('Selected hashtag: $hashtag');
  }

  void _selectCategory(PostCategory category) {
    setState(() {
      _selectedCategory = category;
    });
    // Load category-specific content
    _loadCategoryContent(category);
  }

  void _changeGeographicScope(GeographicScope scope) {
    setState(() {
      _geographicScope = scope;
    });
    _loadGeographicContent();
  }

  Future<void> _loadCategoryContent(PostCategory category) async {
    // TODO: Implement category-specific content loading
    debugPrint('Loading content for category: ${category.displayName}');
  }

  void _openSearch() {
    // TODO: Navigate to search screen
    debugPrint('Opening search');
  }

  void _openFilters() {
    // TODO: Open filters bottom sheet
    debugPrint('Opening filters');
  }

  void _viewAllHashtags() {
    // TODO: Navigate to all hashtags screen
    debugPrint('View all hashtags');
  }

  void _viewAllTrending() {
    // TODO: Navigate to all trending posts
    debugPrint('View all trending posts');
  }

  void _openPost(PostModel post) {
    // TODO: Navigate to post detail screen
    debugPrint('Opening post: ${post.id}');
  }

  void _likePost(PostModel post) {
    // TODO: Implement like functionality
    debugPrint('Liking post: ${post.id}');
  }

  void _openComments(PostModel post) {
    // TODO: Navigate to comments screen
    debugPrint('Opening comments for post: ${post.id}');
  }

  void _sharePost(PostModel post) {
    // TODO: Navigate to share screen
    debugPrint('Sharing post: ${post.id}');
  }

  void _openUserProfile(String userId) {
    // TODO: Navigate to user profile
    debugPrint('Opening profile for user: $userId');
  }
}

enum GeographicScope {
  village('Village'),
  mandal('Mandal'),
  district('District'),
  state('State');

  const GeographicScope(this.displayName);
  final String displayName;
}