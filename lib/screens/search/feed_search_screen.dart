// Feed Search Screen - Search functionality for social feed
// Part of Task 5: Create FeedScreen main interface

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../services/social_feed/index.dart';
import '../../widgets/feed/post_widget.dart';
import '../../widgets/common/loading_widget.dart';

class FeedSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const FeedSearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<FeedSearchScreen> createState() => _FeedSearchScreenState();
}

class _FeedSearchScreenState extends State<FeedSearchScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Search state
  bool _isSearching = false;
  String _currentQuery = '';
  List<PostModel> _searchResults = [];
  List<String> _hashtagResults = [];
  List<String> _recentSearches = [];
  List<String> _trendingHashtags = [];

  // Filters
  PostCategory? _selectedCategory;
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize with provided query
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
    
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildSearchBar(),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Hashtags'),
            Tab(text: 'People'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showSearchFilters,
            icon: Stack(
              children: [
                const Icon(Icons.tune),
                if (_hasActiveFilters())
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Search Filters',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsTab(),
          _buildHashtagsTab(),
          _buildPeopleTab(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search posts, hashtags, people...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.clear, color: Colors.white),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onSubmitted: _performSearch,
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_currentQuery.isEmpty) {
      return _buildSearchSuggestions();
    }

    if (_isSearching) {
      return const LoadingWidget(message: 'Searching posts...');
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults('posts');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
          child: PostWidget(
            post: post,
            onLike: () => _likePost(post),
            onComment: () => _openComments(post),
            onShare: () => _sharePost(post),
            onUserTap: () => _openUserProfile(post.authorId),
            onPostTap: () => _openPostDetail(post),
            highlightQuery: _currentQuery,
          ),
        );
      },
    );
  }

  Widget _buildHashtagsTab() {
    if (_currentQuery.isEmpty) {
      return _buildTrendingHashtags();
    }

    if (_isSearching) {
      return const LoadingWidget(message: 'Searching hashtags...');
    }

    if (_hashtagResults.isEmpty) {
      return _buildNoResults('hashtags');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      itemCount: _hashtagResults.length,
      itemBuilder: (context, index) {
        final hashtag = _hashtagResults[index];
        return _buildHashtagTile(hashtag);
      },
    );
  }

  Widget _buildPeopleTab() {
    // TODO: Implement people search
    return const Center(
      child: Text('People search coming soon...'),
    );
  }

  Widget _buildSearchSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      children: [
        // Recent searches
        if (_recentSearches.isNotEmpty) ...[
          _buildSectionHeader('Recent Searches', Icons.history),
          const SizedBox(height: AppTheme.spacingMedium),
          ..._recentSearches.map((search) => ListTile(
            leading: const Icon(Icons.history),
            title: Text(search),
            trailing: IconButton(
              onPressed: () => _removeRecentSearch(search),
              icon: const Icon(Icons.close, size: 16),
            ),
            onTap: () => _performSearch(search),
          )),
          const SizedBox(height: AppTheme.spacingLarge),
        ],

        // Trending hashtags
        _buildSectionHeader('Trending Hashtags', Icons.trending_up),
        const SizedBox(height: AppTheme.spacingMedium),
        Wrap(
          spacing: AppTheme.spacingSmall,
          runSpacing: AppTheme.spacingSmall,
          children: _trendingHashtags.map((hashtag) => 
            _buildHashtagChip(hashtag)
          ).toList(),
        ),

        const SizedBox(height: AppTheme.spacingLarge),

        // Search tips
        _buildSectionHeader('Search Tips', Icons.lightbulb),
        const SizedBox(height: AppTheme.spacingMedium),
        _buildSearchTips(),
      ],
    );
  }

  Widget _buildTrendingHashtags() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      children: [
        _buildSectionHeader('Trending Hashtags', Icons.trending_up),
        const SizedBox(height: AppTheme.spacingMedium),
        ..._trendingHashtags.map((hashtag) => _buildHashtagTile(hashtag)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.talowaGreen, size: 20),
        const SizedBox(width: AppTheme.spacingSmall),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHashtagChip(String hashtag) {
    return GestureDetector(
      onTap: () => _performHashtagSearch(hashtag),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: AppTheme.talowaGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.talowaGreen.withOpacity(0.3),
          ),
        ),
        child: Text(
          '#$hashtag',
          style: TextStyle(
            color: AppTheme.talowaGreen,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHashtagTile(String hashtag) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.talowaGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.tag,
          color: AppTheme.talowaGreen,
          size: 20,
        ),
      ),
      title: Text('#$hashtag'),
      subtitle: Text('${_getMockPostCount(hashtag)} posts'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _performHashtagSearch(hashtag),
    );
  }

  Widget _buildSearchTips() {
    final tips = [
      'Use # to search for hashtags (e.g., #LandRights)',
      'Search by category using keywords like "legal" or "success"',
      'Use quotes for exact phrases (e.g., "patta application")',
      'Filter by location or category using the filter button',
    ];

    return Column(
      children: tips.map((tip) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 8, right: 8),
              decoration: BoxDecoration(
                color: AppTheme.talowaGreen,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                tip,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildNoResults(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            'No $type found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            'Try different keywords or remove filters',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          ElevatedButton(
            onPressed: _clearFilters,
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  // Search functionality
  void _onSearchChanged(String query) {
    // Implement real-time search suggestions if needed
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _currentQuery = query.trim();
    });

    _searchController.text = query;
    _searchFocusNode.unfocus();
    _addToRecentSearches(query);

    try {
      List<PostModel> results;
      List<String> hashtagResults = [];
      
      if (query.startsWith('#')) {
        // Hashtag search
        final hashtag = query.substring(1);
        results = await FeedService.searchPostsByHashtag(hashtag: hashtag);
        hashtagResults = [hashtag];
      } else {
        // General text search
        results = await FeedService.searchPosts(
          query: query,
          category: _selectedCategory?.name,
        );
        
        // Extract hashtags from query
        final hashtagMatches = RegExp(r'#\w+').allMatches(query);
        hashtagResults = hashtagMatches.map((match) => 
          match.group(0)!.substring(1)
        ).toList();
      }

      setState(() {
        _searchResults = results;
        _hashtagResults = hashtagResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _performHashtagSearch(String hashtag) async {
    _performSearch('#$hashtag');
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = '';
      _searchResults = [];
      _hashtagResults = [];
    });
  }

  // Filter functionality
  void _showSearchFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildFiltersSheet(),
    );
  }

  Widget _buildFiltersSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Search Filters',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear All'),
              ),
            ],
          ),
          
          const Divider(),
          
          // Filter options
          Expanded(
            child: ListView(
              children: [
                // Category filter
                _buildFilterSection(
                  'Category',
                  Icons.category,
                  _buildCategoryFilter(),
                ),
                
                // Location filter
                _buildFilterSection(
                  'Location',
                  Icons.location_on,
                  _buildLocationFilter(),
                ),
              ],
            ),
          ),
          
          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (_currentQuery.isNotEmpty) {
                  _performSearch(_currentQuery);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.talowaGreen),
            const SizedBox(width: AppTheme.spacingSmall),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        content,
        const SizedBox(height: AppTheme.spacingLarge),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return Wrap(
      spacing: AppTheme.spacingSmall,
      runSpacing: AppTheme.spacingSmall,
      children: PostCategory.values.map((category) {
        final isSelected = _selectedCategory == category;
        return FilterChip(
          label: Text(category.displayName),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedCategory = selected ? category : null;
            });
          },
          selectedColor: AppTheme.talowaGreen.withOpacity(0.2),
          checkmarkColor: AppTheme.talowaGreen,
        );
      }).toList(),
    );
  }

  Widget _buildLocationFilter() {
    // TODO: Implement location filter
    return const Text('Location filter coming soon...');
  }

  bool _hasActiveFilters() {
    return _selectedCategory != null || _selectedLocation != null;
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedLocation = null;
    });
  }

  // Data management
  Future<void> _loadInitialData() async {
    try {
      final hashtags = await FeedService.getTrendingHashtags(limit: 10);
      setState(() {
        _trendingHashtags = hashtags;
        _recentSearches = ['land rights', 'patta application', '#LegalHelp'];
      });
    } catch (e) {
      debugPrint('Error loading initial search data: $e');
    }
  }

  void _addToRecentSearches(String query) {
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.take(10).toList();
      }
    });
    // TODO: Save to local storage
  }

  void _removeRecentSearch(String search) {
    setState(() {
      _recentSearches.remove(search);
    });
    // TODO: Update local storage
  }

  int _getMockPostCount(String hashtag) {
    // Mock post counts for demonstration
    return (hashtag.length * 7) % 100 + 10;
  }

  // Post actions
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

  void _openPostDetail(PostModel post) {
    // TODO: Navigate to post detail screen
    debugPrint('Opening post detail: ${post.id}');
  }
}