// Advanced Search Screen for TALOWA
// Implements Task 24: Add advanced search and discovery - Search UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/search/advanced_search_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/search/search_result_widget.dart';
import '../../widgets/search/search_filters_widget.dart';
import '../../widgets/search/trending_topics_widget.dart';

class AdvancedSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const AdvancedSearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen>
    with SingleTickerProviderStateMixin {
  final AdvancedSearchService _searchService = AdvancedSearchService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late TabController _tabController;
  SearchResults? _searchResults;
  List<ContentRecommendation> _recommendations = [];
  List<TrendingTopic> _trendingTopics = [];
  List<SearchSuggestion> _suggestions = [];
  
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  SearchFilters _currentFilters = SearchFilters();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performSearch();
    } else {
      _loadInitialData();
    }
    
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = context.read<AuthProvider>().currentUser?.uid;
      if (userId == null) return;

      final results = await Future.wait([
        _searchService.getContentRecommendations(userId: userId, limit: 10),
        _searchService.getTrendingTopics(limit: 10),
      ]);

      setState(() {
        _recommendations = results[0] as List<ContentRecommendation>;
        _trendingTopics = results[1] as List<TrendingTopic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await _searchService.performFullTextSearch(
        query: _searchController.text.trim(),
        filters: _currentFilters,
        limit: 20,
      );

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || _searchResults == null || !_searchResults!.hasMore) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final lastResult = _searchResults!.results.isNotEmpty 
          ? _searchResults!.results.last 
          : null;

      final moreResults = await _searchService.performFullTextSearch(
        query: _searchResults!.query,
        filters: _currentFilters,
        limit: 20,
        lastDocumentId: lastResult?.id,
      );

      setState(() {
        _searchResults = SearchResults(
          query: _searchResults!.query,
          results: [..._searchResults!.results, ...moreResults.results],
          totalResults: _searchResults!.totalResults + moreResults.results.length,
          hasMore: moreResults.hasMore,
          searchTime: moreResults.searchTime,
          suggestions: moreResults.suggestions,
          facets: moreResults.facets,
        );
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreResults();
    }
  }

  void _onSearchTextChanged() {
    if (_searchController.text.length >= 2) {
      _getSuggestions();
    } else {
      setState(() {
        _suggestions = [];
      });
    }
  }

  Future<void> _getSuggestions() async {
    try {
      final suggestions = await _searchService.getSearchSuggestions(
        partialQuery: _searchController.text,
        limit: 5,
      );

      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      // Ignore suggestion errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildSearchBar(),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_outlined),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
        bottom: _showFilters ? PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SearchFiltersWidget(
            filters: _currentFilters,
            onFiltersChanged: (filters) {
              setState(() {
                _currentFilters = filters;
              });
              if (_searchController.text.isNotEmpty) {
                _performSearch();
              }
            },
          ),
        ) : null,
      ),
      body: Column(
        children: [
          if (_suggestions.isNotEmpty) _buildSuggestions(),
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildDiscoveryContent()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search posts, users, topics...',
        hintStyle: const TextStyle(color: Colors.white70),
        border: InputBorder.none,
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white70),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = null;
                    _suggestions = [];
                  });
                },
              )
            : const Icon(Icons.search, color: Colors.white70),
      ),
      style: const TextStyle(color: Colors.white),
      onSubmitted: (_) => _performSearch(),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      color: Colors.white,
      child: Column(
        children: _suggestions.map((suggestion) {
          return ListTile(
            leading: Icon(_getSuggestionIcon(suggestion.type)),
            title: Text(suggestion.text),
            subtitle: Text(_getSuggestionSubtitle(suggestion)),
            onTap: () {
              _searchController.text = suggestion.text;
              setState(() {
                _suggestions = [];
              });
              _performSearch();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDiscoveryContent() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'For You', icon: Icon(Icons.recommend, size: 20)),
              Tab(text: 'Trending', icon: Icon(Icons.trending_up, size: 20)),
              Tab(text: 'Recent', icon: Icon(Icons.access_time, size: 20)),
              Tab(text: 'Popular', icon: Icon(Icons.star, size: 20)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecommendationsTab(),
                _buildTrendingTab(),
                _buildRecentTab(),
                _buildPopularTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (_isLoading) return const LoadingWidget();
    if (_error != null) return ErrorDisplayWidget(error: _error!, onRetry: _loadInitialData);

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final recommendation = _recommendations[index];
          return _buildRecommendationCard(recommendation);
        },
      ),
    );
  }

  Widget _buildTrendingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trending Topics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TrendingTopicsWidget(
            topics: _trendingTopics,
            onTopicTap: (topic) {
              _searchController.text = topic.topic;
              _performSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTab() {
    return const Center(
      child: Text('Recent searches will appear here'),
    );
  }

  Widget _buildPopularTab() {
    return const Center(
      child: Text('Popular content will appear here'),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) return const LoadingWidget();
    if (_error != null) return ErrorDisplayWidget(error: _error!, onRetry: _performSearch);
    if (_searchResults == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildSearchHeader(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _searchResults!.results.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _searchResults!.results.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final result = _searchResults!.results[index];
              return SearchResultWidget(
                result: result,
                query: _searchResults!.query,
                onTap: () => _navigateToResult(result),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_searchResults!.totalResults} results for "${_searchResults!.query}"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            '${(_searchResults!.searchTime.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch).abs()}ms',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(ContentRecommendation recommendation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRecommendationColor(recommendation.type),
          child: Icon(
            _getRecommendationIcon(recommendation.type),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          recommendation.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recommendation.reason,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  '${(recommendation.score * 100).round()}% match',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _navigateToRecommendation(recommendation),
      ),
    );
  }

  // Helper methods

  IconData _getSuggestionIcon(SearchResultType type) {
    switch (type) {
      case SearchResultType.post:
        return Icons.article;
      case SearchResultType.user:
        return Icons.person;
      case SearchResultType.hashtag:
        return Icons.tag;
      case SearchResultType.topic:
        return Icons.topic;
    }
  }

  String _getSuggestionSubtitle(SearchSuggestion suggestion) {
    switch (suggestion.type) {
      case SearchResultType.post:
        return 'Post';
      case SearchResultType.user:
        return 'User';
      case SearchResultType.hashtag:
        return 'Hashtag';
      case SearchResultType.topic:
        return 'Topic';
    }
  }

  Color _getRecommendationColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.personalized:
        return Colors.blue;
      case RecommendationType.trending:
        return Colors.red;
      case RecommendationType.similar:
        return Colors.green;
      case RecommendationType.collaborative:
        return Colors.purple;
    }
  }

  IconData _getRecommendationIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.personalized:
        return Icons.person;
      case RecommendationType.trending:
        return Icons.trending_up;
      case RecommendationType.similar:
        return Icons.similar;
      case RecommendationType.collaborative:
        return Icons.group;
    }
  }

  void _navigateToResult(SearchResult result) {
    switch (result.type) {
      case SearchResultType.post:
        Navigator.pushNamed(context, '/post-detail', arguments: result.id);
        break;
      case SearchResultType.user:
        Navigator.pushNamed(context, '/user-profile', arguments: result.id);
        break;
      case SearchResultType.hashtag:
        _searchController.text = result.title;
        _performSearch();
        break;
      case SearchResultType.topic:
        _searchController.text = result.title;
        _performSearch();
        break;
    }
  }

  void _navigateToRecommendation(ContentRecommendation recommendation) {
    Navigator.pushNamed(context, '/post-detail', arguments: recommendation.postId);
  }
}