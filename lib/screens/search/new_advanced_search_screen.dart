// New Advanced Search Screen - Complete search interface
// Simplified and working implementation for TALOWA platform

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/search/search_result_model.dart';
import '../../models/search/search_filter_model.dart';
import '../../services/search/search_service.dart';
import '../../widgets/search/search_bar_widget.dart';
import '../../widgets/search/simple_search_filters_widget.dart';
import '../../widgets/search/search_results_widget.dart';
import '../../widgets/common/loading_widget.dart';

class NewAdvancedSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const NewAdvancedSearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
  });

  @override
  State<NewAdvancedSearchScreen> createState() => _NewAdvancedSearchScreenState();
}

class _NewAdvancedSearchScreenState extends State<NewAdvancedSearchScreen>
    with TickerProviderStateMixin {
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  late TabController _tabController;
  
  UniversalSearchResultModel? _searchResults;
  List<String> _suggestions = [];
  SearchFilterModel _filters = const SearchFilterModel();
  
  bool _isLoading = false;
  bool _showSuggestions = false;
  bool _showFilters = false;
  String? _errorMessage;
  
  // Search tabs
  final List<String> _searchTabs = [
    'All',
    'Posts',
    'People',
    'News',
    'Legal',
    'Organizations',
  ];

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: _searchTabs.length, vsync: this);
    
    // Initialize with provided query
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
    
    // Setup search listeners
    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    
    // Initialize search service
    _initializeSearchService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeSearchService() async {
    try {
      await SearchService.instance.initialize();
    } catch (e) {
      debugPrint('Failed to initialize search service: $e');
    }
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    if (query.length >= 2) {
      _getSuggestions(query);
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty) {
      setState(() => _showSuggestions = true);
    } else {
      setState(() => _showSuggestions = false);
    }
  }

  Future<void> _getSuggestions(String query) async {
    try {
      final suggestions = await SearchService.instance.getSuggestions(query);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty && _searchFocusNode.hasFocus;
        });
      }
    } catch (e) {
      debugPrint('Failed to get suggestions: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showSuggestions = false;
    });

    // Add haptic feedback
    HapticFeedback.lightImpact();

    try {
      final results = await SearchService.instance.universalSearch(
        query,
        filters: _filters,
        hitsPerPage: 20,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Search failed: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _onSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    _searchFocusNode.unfocus();
    _performSearch(suggestion);
  }

  void _onFiltersChanged(SearchFilterModel newFilters) {
    setState(() {
      _filters = newFilters;
    });
    
    // Re-search with new filters if we have a query
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch(_searchController.text.trim());
    }
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = null;
      _suggestions.clear();
      _showSuggestions = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchHeader(),
          if (_showFilters) _buildFiltersSection(),
          Expanded(child: _buildSearchContent()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Search'),
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _toggleFilters,
          icon: Icon(
            _showFilters ? Icons.filter_list_off : Icons.filter_list,
            color: _showFilters ? AppTheme.primaryColor : Colors.grey[600],
          ),
          tooltip: 'Filters',
        ),
        if (_searchController.text.isNotEmpty)
          IconButton(
            onPressed: _clearSearch,
            icon: const Icon(Icons.clear),
            tooltip: 'Clear search',
          ),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SearchBarWidget(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onSubmitted: _performSearch,
            onChanged: (query) {
              // Handle real-time search if needed
            },
            hintText: 'Search for land rights, legal cases, people...',
          ),
          if (_showSuggestions && _suggestions.isNotEmpty)
            SearchSuggestionsWidget(
              suggestions: _suggestions,
              onSuggestionTap: _onSuggestionTap,
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      color: Colors.white,
      child: SimpleSearchFiltersWidget(
        filters: _filters,
        onFiltersChanged: _onFiltersChanged,
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Searching...');
    }

    if (_errorMessage != null) {
      return CustomErrorWidget(
        message: _errorMessage!,
        onRetry: () => _performSearch(_searchController.text.trim()),
      );
    }

    if (_searchResults == null) {
      return _buildEmptyState();
    }

    return _buildSearchResults();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Search for land rights information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find posts, people, legal cases, news, and more',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildQuickSearchButtons(),
        ],
      ),
    );
  }

  Widget _buildQuickSearchButtons() {
    final quickSearches = [
      'Land rights',
      'Legal cases',
      'Lawyers',
      'Government policies',
      'Success stories',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickSearches.map((search) {
        return ActionChip(
          label: Text(search),
          onPressed: () {
            _searchController.text = search;
            _performSearch(search);
          },
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          labelStyle: const TextStyle(color: AppTheme.primaryColor),
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        _buildResultsTabs(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SearchResultsWidget(
                results: _searchResults!,
                showAllTypes: true,
              ),
              SearchResultsWidget(
                results: _searchResults!,
                filterByIndex: 'posts',
              ),
              SearchResultsWidget(
                results: _searchResults!,
                filterByIndex: 'users',
              ),
              SearchResultsWidget(
                results: _searchResults!,
                filterByIndex: 'news',
              ),
              SearchResultsWidget(
                results: _searchResults!,
                filterByIndex: 'legal_cases',
              ),
              SearchResultsWidget(
                results: _searchResults!,
                filterByIndex: 'organizations',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: AppTheme.primaryColor,
        tabs: _searchTabs.map((tab) {
          final count = _getResultCountForTab(tab);
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  int _getResultCountForTab(String tab) {
    if (_searchResults == null) return 0;

    switch (tab) {
      case 'All':
        return _searchResults!.totalHits;
      case 'Posts':
        return _searchResults!.results['posts']?.totalHits ?? 0;
      case 'People':
        return _searchResults!.results['users']?.totalHits ?? 0;
      case 'News':
        return _searchResults!.results['news']?.totalHits ?? 0;
      case 'Legal':
        return _searchResults!.results['legal_cases']?.totalHits ?? 0;
      case 'Organizations':
        return _searchResults!.results['organizations']?.totalHits ?? 0;
      default:
        return 0;
    }
  }
}


